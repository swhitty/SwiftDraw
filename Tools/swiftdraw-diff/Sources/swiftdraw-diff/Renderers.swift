import Foundation
import Subprocess
import SwiftDrawDiffCore
import System

/// One SVG to render.
struct InputFile: Sendable {
    /// The report name: the path relative to the input directory, without `.svg`. May contain `/`.
    var name: String
    var svg: URL
    var data: Data
    /// SHA-256 of the SVG's bytes, the cache key for every renderer.
    var hash: String
    /// Contains a `<text>` element.
    var text: Bool
}

/// The repository this tool lives in.
struct Repo: Sendable {
    var root: URL
    var toolDir: URL { root.appendingPathComponent("Tools/swiftdraw-diff") }
    var work: URL { toolDir.appendingPathComponent(".build") }

    static func find() async throws -> Repo {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let root = URL(fileURLWithPath: try await git(["rev-parse", "--show-toplevel"], in: cwd))
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Tools/webkit-render/Package.swift").path) else {
            throw ToolError("expected Tools/webkit-render in \(root.path); run swiftdraw-diff from inside the SwiftDraw repo")
        }
        return Repo(root: root)
    }
}

// MARK: - WebKit

/// Tools/webkit-render. Renders every file in one batch and decides each file's size.
struct WebKitRenderer: Sendable {
    var binary: URL
    /// The WebKit bundle version.
    var version: String
    /// Identifies this binary and its options in the cache.
    var cacheID: String

    static func prepare(_ options: Options, repo: Repo) async throws -> WebKitRenderer {
        let binary: URL
        if let path = options.webkitRenderPath {
            binary = path
        } else {
            step("Building webkit-render")
            let package = repo.root.appendingPathComponent("Tools/webkit-render")
            try await check(.name("swift"), ["build", "-c", "release", "-q", "--package-path", package.path], label: "webkit-render build")
            binary = package.appendingPathComponent(".build/release/webkit-render")
        }
        let output = try await execute(binary, ["--version"])
        guard output.success else { throw ToolError("\(binary.path) --version failed: \(output.reason)") }
        let version = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let binaryHash = RenderCache.hash((try? Data(contentsOf: binary)) ?? Data())
        let id = RenderCache.hash("webkit", version, binaryHash, "\(options.scale)", "\(options.maxDimension)", "\(options.fontSmoothing)")
        return WebKitRenderer(binary: binary, version: version, cacheID: "webkit-\(id)")
    }

    /// Renders `files` into `dir/<name>.png`, reusing cached renders.
    func render(_ files: [InputFile], options: Options, cache: RenderCache, into dir: URL, scratch: URL) async throws -> [String: WebKitManifestEntry] {
        var results: [String: WebKitManifestEntry] = [:]
        var missing: [InputFile] = []
        for file in files {
            if let hit = cache.lookup(cacheID, file.hash, as: WebKitManifestEntry.self) {
                var entry = hit.meta
                entry.name = file.name
                if let png = hit.png { try FileManager.default.copyItem(at: png, to: dir.appendingPathComponent("\(file.name).png")) }
                results[file.name] = entry
            } else {
                missing.append(file)
            }
        }
        guard !missing.isEmpty else { return results }

        step("Rendering \(missing.count) file\(missing.count == 1 ? "" : "s") with WebKit")
        // webkit-render takes plain file names; report names may be relative paths
        struct Job: Encodable { var name: String; var svg: String }
        let jobs = missing.enumerated().map { i, file in
            (Job(name: "\(i)-\(file.svg.deletingPathExtension().lastPathComponent)", svg: file.svg.path), file)
        }
        let jobsURL = scratch.appendingPathComponent("webkit-jobs.json")
        let jobsOut = scratch.appendingPathComponent("webkit")
        let fm = FileManager.default
        try fm.createDirectory(at: jobsOut, withIntermediateDirectories: true)
        try JSONEncoder().encode(jobs.map(\.0)).write(to: jobsURL)
        let output = try await execute(binary, [
            "--jobs", jobsURL.path, "--out", jobsOut.path,
            "--scale", "\(options.scale)", "--max", "\(options.maxDimension)",
        ] + (options.fontSmoothing ? ["--font-smoothing"] : []))
        guard output.success else { throw ToolError("webkit-render failed: \(output.reason)") }
        let manifest = try JSONDecoder().decode([WebKitManifestEntry].self, from: Data(contentsOf: jobsOut.appendingPathComponent("manifest.json")))
        let byJob = Dictionary(uniqueKeysWithValues: jobs.map { ($0.0.name, $0.1) })
        for var entry in manifest {
            guard let file = byJob[entry.name] else { continue }
            let rendered = jobsOut.appendingPathComponent("\(entry.name).png")
            entry.name = file.name
            results[file.name] = entry
            let png = dir.appendingPathComponent("\(file.name).png")
            if entry.rendered { try? fm.moveItem(at: rendered, to: png) }
            // a redrawn image came from a WebKit timing glitch; don't keep it in the cache
            if entry.redrawn == nil {
                cache.store(cacheID, file.hash, meta: entry, png: entry.rendered ? png : nil)
            }
        }
        return results
    }
}

// MARK: - SwiftDraw

/// A SwiftDraw revision to render with.
enum Revision: Sendable {
    case workingCopy
    case commit(ref: String, sha: String)
    case binary(URL)
}

/// A swiftdrawcli binary for one SwiftDraw revision.
struct SwiftDrawRenderer: Sendable {
    var binary: URL
    var label: String
    /// nil when its renders should not be cached (the working copy, or a binary given by path).
    var cacheID: String?

    /// Builds (or finds the cached) swiftdrawcli for `revision`. `slot` names the reusable worktree.
    static func prepare(_ revision: Revision, slot: String, repo: Repo, cache: RenderCache, scale: Int) async throws -> SwiftDrawRenderer {
        switch revision {
        case let .binary(url):
            return SwiftDrawRenderer(binary: url, label: url.path, cacheID: nil)

        case .workingCopy:
            let sha = try await git(["rev-parse", "HEAD"], in: repo.root)
            let dirty = !(try await git(["status", "--porcelain", "--", "SwiftDraw", "DOM", "Package.swift"], in: repo.root)).isEmpty
            step("Building swiftdrawcli (working copy)")
            let scratch = repo.work.appendingPathComponent("swiftdrawcli-working")
            try await check(.name("swift"), ["build", "-c", "release", "-q", "--product", "swiftdrawcli",
                                             "--package-path", repo.root.path, "--scratch-path", scratch.path],
                            label: "swiftdrawcli build")
            return SwiftDrawRenderer(
                binary: scratch.appendingPathComponent("release/swiftdrawcli"),
                label: "working copy (\(sha.prefix(7))\(dirty ? " + uncommitted changes" : ""))",
                cacheID: nil
            )

        case let .commit(ref, sha):
            let label = sha.hasPrefix(ref) ? String(sha.prefix(7)) : "\(ref) (\(sha.prefix(7)))"
            let id = "swiftdraw-\(sha)-\(scale)x"
            if let cached = cache.swiftdrawBinary(sha: sha), FileManager.default.isExecutableFile(atPath: cached.path) {
                return SwiftDrawRenderer(binary: cached, label: label, cacheID: id)
            }
            let worktree = repo.work.appendingPathComponent("compare/\(slot)-src")
            try await prepareWorktree(worktree, sha: sha, repo: repo.root)
            step("Building swiftdrawcli @ \(sha.prefix(7))")
            try await check(.name("swift"), ["build", "-c", "release", "-q", "--product", "swiftdrawcli", "--package-path", worktree.path],
                            label: "swiftdrawcli build at \(sha.prefix(7))")
            let built = worktree.appendingPathComponent(".build/release/swiftdrawcli")
            guard let cached = cache.swiftdrawBinary(sha: sha) else {
                return SwiftDrawRenderer(binary: built, label: label, cacheID: nil)
            }
            let fm = FileManager.default
            try fm.createDirectory(at: cached.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? fm.removeItem(at: cached)
            try fm.copyItem(at: built, to: cached)
            return SwiftDrawRenderer(binary: cached, label: label, cacheID: id)
        }
    }

    /// Reuses one worktree per slot across runs so builds stay incremental.
    static func prepareWorktree(_ dir: URL, sha: String, repo: URL) async throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: dir.appendingPathComponent(".git").path) {
            try await git(["checkout", "--quiet", "--detach", "--force", sha], in: dir)
        } else {
            _ = try? await git(["worktree", "prune"], in: repo)
            try fm.createDirectory(at: dir.deletingLastPathComponent(), withIntermediateDirectories: true)
            try await git(["worktree", "add", "--quiet", "--detach", "--force", dir.path, sha], in: repo)
        }
    }

    struct CachedResult: Codable { var result: RenderResult; var size: PointSize? }

    /// Renders one file to `png` at `size` points, or at its own size when `size` is nil.
    /// Returns the result and the size it rendered at.
    func render(_ file: InputFile, size: PointSize?, scale: Int, cache: RenderCache, to png: URL) async -> (RenderResult, PointSize?) {
        let key = "\(file.hash)-\(size.map { "\($0.width)x\($0.height)" } ?? "natural")"
        if let cacheID, let hit = cache.lookup(cacheID, key, as: CachedResult.self) {
            if let src = hit.png { try? FileManager.default.copyItem(at: src, to: png) }
            if !hit.meta.result.rendered || hit.png != nil { return (hit.meta.result, hit.meta.size) }
        }
        var args = [file.svg.path, "--format", "png", "--scale", "\(scale)x", "--output", png.path]
        if let size { args += ["--size", "\(size.width)x\(size.height)"] }
        let result: RenderResult
        var rendered = size
        do {
            let output = try await execute(binary, args)
            if output.success && FileManager.default.fileExists(atPath: png.path) {
                result = .ok
                if size == nil, let bitmap = try? Bitmap(contentsOf: png) {
                    rendered = PointSize(width: max(1, bitmap.width / scale), height: max(1, bitmap.height / scale))
                }
            } else {
                result = .failed(output.reason)
            }
        } catch {
            result = .failed("\(error)")
        }
        if let cacheID {
            cache.store(cacheID, key, meta: CachedResult(result: result, size: rendered), png: result.rendered ? png : nil)
        }
        return (result, rendered)
    }
}

// MARK: - resvg

/// resvg, read from pre-rendered PNGs, run as a CLI, or both: PNGs where they fit, the CLI otherwise.
struct ResvgRenderer: Sendable {
    var png: Options.ResvgPNGSource?
    var cli: URL?
    /// e.g. "resvg 0.50.0", or "resvg PNGs (…)".
    var label: String
    var cacheID: String?

    /// SwiftDraw's fallback fonts, so text is drawn with the same faces, and CSS `medium` (16px) as the
    /// default font size like browsers and SwiftDraw; resvg's CLI defaults to 12.
    static let fontArguments = [
        "--font-family", "Times", "--serif-family", "Times", "--sans-serif-family", "Helvetica",
        "--monospace-family", "Courier", "--cursive-family", "Apple Chancery", "--fantasy-family", "Papyrus",
        "--font-size", "16",
    ]

    static func prepare(_ options: Options) async throws -> ResvgRenderer? {
        guard options.usesResvg else { return nil }
        var labels: [String] = []
        switch options.resvgPNG {
        case nil: break
        case .sibling: labels.append("resvg PNGs (beside each SVG)")
        case let .directory(dir): labels.append("resvg PNGs (\(dir.path))")
        }
        guard options.resvgCLI else {
            return ResvgRenderer(png: options.resvgPNG, cli: nil, label: labels.joined(), cacheID: nil)
        }
        let output: ProcessOutput
        do {
            output = try await execute(options.resvgPath.map { .path(.init($0.path)) } ?? .name("resvg"), ["--version"])
        } catch {
            throw ToolError("resvg not found\(options.resvgPath.map { " at \($0.path)" } ?? " on PATH"). Install it with `brew install resvg`, or pass --resvg-path")
        }
        guard output.success else { throw ToolError("resvg --version failed: \(output.reason)") }
        let version = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let binary: URL
        if let path = options.resvgPath { binary = path } else { binary = try await resolve("resvg") }
        let id = RenderCache.hash("resvg", version, fontArguments.joined(separator: " "))
        labels.append(labels.isEmpty ? "resvg \(version)" : "resvg \(version) for text and unusable PNGs")
        return ResvgRenderer(png: options.resvgPNG, cli: binary, label: labels.joined(separator: ", "), cacheID: "resvg-\(id)")
    }

    private static func resolve(_ name: String) async throws -> URL {
        let path = try await check(.name("which"), [name], label: "which \(name)")
        return URL(fileURLWithPath: path)
    }

    /// Renders (or copies) one file's image to `png` at `pixels`. A pre-rendered PNG is used only when it
    /// is exactly `pixels`; otherwise the CLI renders it, or, without the CLI, the file has no resvg image.
    /// With the CLI, text is always rendered by it: pre-rendered PNGs (such as resvg's test suite, drawn
    /// with its own Noto fonts) use other fonts than SwiftDraw's fallbacks.
    func render(_ file: InputFile, pixels: (width: Int, height: Int), scale: Int, cache: RenderCache, to png: URL) async -> RenderResult {
        let fm = FileManager.default
        var unusable: String?
        if let source = self.png, Options.prefersResvgPNG(hasPNGs: true, hasCLI: cli != nil, text: file.text) {
            let src: URL
            switch source {
            case let .directory(dir): src = dir.appendingPathComponent("\(file.name).png")
            case .sibling: src = file.svg.deletingPathExtension().appendingPathExtension("png")
            }
            if !fm.fileExists(atPath: src.path) {
                unusable = "no \(src.lastPathComponent)"
            } else if let size = Bitmap.size(of: src), size != (pixels.width, pixels.height) {
                unusable = "\(src.lastPathComponent) is \(size.width)×\(size.height), expected \(pixels.width)×\(pixels.height)"
                    + Self.scaleHint(png: size, pixels: pixels, scale: scale)
            } else {
                do { try fm.copyItem(at: src, to: png) } catch { return .failed("\(error)").from("png") }
                return RenderResult.ok.from("png")
            }
        }
        guard let cli else { return .failed(unusable ?? "no resvg image").from("png") }
        return await render(file, cli: cli, pixels: pixels, cache: cache, to: png).from("cli")
    }

    /// The `--scale` that would make a pre-rendered PNG fit, when there is one.
    static func scaleHint(png: (width: Int, height: Int), pixels: (width: Int, height: Int), scale: Int) -> String {
        guard pixels.width > 0, pixels.height > 0, scale > 0 else { return "" }
        let points = (pixels.width / scale, pixels.height / scale)
        for s in 1...3 where s != scale && png.width == points.0 * s && png.height == points.1 * s {
            return " (use --scale \(s))"
        }
        return ""
    }

    private func render(_ file: InputFile, cli binary: URL, pixels: (width: Int, height: Int), cache: RenderCache, to png: URL) async -> RenderResult {
        let fm = FileManager.default
        let key = "\(file.hash)-\(pixels.width)x\(pixels.height)"
        if let cacheID, let hit = cache.lookup(cacheID, key, as: RenderResult.self) {
            if let src = hit.png { try? fm.copyItem(at: src, to: png) }
            if !hit.meta.rendered || hit.png != nil { return hit.meta }
        }
        // resvg fits -w × -h keeping the aspect ratio; the result is padded or cropped to size when scored.
        let args = ["-w", "\(pixels.width)", "-h", "\(pixels.height)", "--background", "white"]
            + Self.fontArguments + [file.svg.path, png.path]
        let result: RenderResult
        do {
            let output = try await execute(binary, args)
            result = output.success && fm.fileExists(atPath: png.path) ? .ok : .failed(output.reason)
        } catch {
            result = .failed("\(error)")
        }
        if let cacheID { cache.store(cacheID, key, meta: result, png: result.rendered ? png : nil) }
        return result
    }
}
