import AppKit
import Foundation

/// `swiftdraw-diff compare --base <ref>`
///
/// 1. Checks out <ref> into a reusable git worktree and builds this tool against
///    that SwiftDraw, then runs its `render` subcommand → base PNGs.
/// 2. Renders the working copy (uncommitted changes included) in-process → head PNGs.
/// 3. Writes a self-contained compare page and scores both against WebKit in a
///    hidden WKWebView, using the same JS diff as the eyeball report.
/// 4. Prints regressions / improvements / changes, writes compare.json and
///    returns exit code 1 if anything regressed beyond the tolerance.
@MainActor
struct Comparer {
    var options: Options

    struct Entry: Codable {
        var name: String
        var category: String
        /// Difference from WebKit, in percent (0...100). nil when that side failed.
        var base: Double?
        var head: Double?
        var delta: Double?
        /// Pixels that differ between base and head (exact, unblurred).
        var pixelsChanged: Int?
        var baseStatus: String
        var headStatus: String
        /// Images that first drew blank in the scoring page and were redrawn, e.g. "head png: 1 retry".
        var redrawn: [String]?
    }

    struct Output: Codable {
        var base: String
        var head: String
        var engine: String
        var os: String
        var tolerance: Double
        var generated: Date
        var results: [Entry]
    }

    func run() async throws -> Int32 {
        let fm = FileManager.default
        let repo = try git(["rev-parse", "--show-toplevel"], in: URL(fileURLWithPath: fm.currentDirectoryPath))
        let repoURL = URL(fileURLWithPath: repo)
        let toolDir = repoURL.appendingPathComponent("Tools/swiftdraw-diff")
        guard fm.fileExists(atPath: toolDir.appendingPathComponent("Package.swift").path) else {
            throw Failure("expected the tool at \(toolDir.path)")
        }
        let work = toolDir.appendingPathComponent(".build/compare")
        let out = options.outIsDefault ? work.appendingPathComponent("report") : options.out
        try? fm.removeItem(at: out)
        try fm.createDirectory(at: out, withIntermediateDirectories: true)

        let files = options.svgFiles.map { $0.standardizedFileURL }
        guard !files.isEmpty else { throw Failure("no SVG files found") }

        // Revisions
        let label = { (ref: String, sha: String) in sha.hasPrefix(ref) ? String(sha.prefix(7)) : "\(ref) (\(sha.prefix(7)))" }
        let baseSHA = try git(["rev-parse", "--verify", "\(options.base)^{commit}"], in: repoURL)
        let baseLabel = label(options.base, baseSHA)
        let headLabel: String
        let headSHA: String
        var dirty = false
        if let head = options.head {
            headSHA = try git(["rev-parse", "--verify", "\(head)^{commit}"], in: repoURL)
            headLabel = label(head, headSHA)
        } else {
            headSHA = try git(["rev-parse", "HEAD"], in: repoURL)
            dirty = !(try git(["status", "--porcelain", "--", "SwiftDraw", "DOM"], in: repoURL)).isEmpty
            headLabel = "working copy (\(headSHA.prefix(7))\(dirty ? " + uncommitted changes" : ""))"
        }
        print("Comparing SwiftDraw: \(baseLabel) → \(headLabel)")
        if baseSHA == headSHA && !dirty {
            print("note: base and head are the same commit with no SwiftDraw changes; expect no differences")
        }

        let sources = toolDir.appendingPathComponent("Sources")
        let baseDir = out.appendingPathComponent("base")
        let baseManifest = try renderRevision(sha: baseSHA, slot: "base", repo: repoURL, work: work, sources: sources, files: files, to: baseDir)

        let headDir = out.appendingPathComponent("head")
        let headManifest: [RenderedFile]
        if options.head != nil {
            headManifest = try renderRevision(sha: headSHA, slot: "head", repo: repoURL, work: work, sources: sources, files: files, to: headDir)
        } else {
            step("Rendering working copy")
            headManifest = try renderAll(files, scale: options.scale, maxDimension: options.maxDimension, to: headDir)
        }

        let svgDir = out.appendingPathComponent("svg")
        try fm.createDirectory(at: svgDir, withIntermediateDirectories: true)
        for url in files {
            guard let data = try? Data(contentsOf: url) else { continue }
            try? ReferenceSVG.prepare(data, fontSmoothing: options.fontSmoothing)
                .write(to: svgDir.appendingPathComponent(url.lastPathComponent))
        }

        // The page is also the scoring engine; without --html it's temporary.
        let page = out.appendingPathComponent(options.html ? "index.html" : ".scoring.html")
        try writeComparePage(base: baseManifest, head: headManifest, baseLabel: baseLabel, headLabel: headLabel, dir: out, to: page)

        let result = try await Scorer.evaluate(
            page: page,
            rowsExpression: "ROWS.map(r => ({ name: r.name, category: r.category, base: r.baseScore, head: r.headScore, pixelsChanged: r.changed, baseStatus: r.baseStatus, headStatus: r.headStatus, redrawn: r.redrawn ?? null }))",
            progress: progressPrinter("Scoring against WebKit")
        )
        let entries = result.rows.map { row -> Entry in
            let base = (row["base"] as? Double).map { $0 * 100 }
            let head = (row["head"] as? Double).map { $0 * 100 }
            return Entry(
                name: row["name"] as? String ?? "?",
                category: row["category"] as? String ?? "error",
                base: base,
                head: head,
                delta: base.flatMap { b in head.map { $0 - b } },
                pixelsChanged: row["pixelsChanged"] as? Int,
                baseStatus: row["baseStatus"] as? String ?? "",
                headStatus: row["headStatus"] as? String ?? "",
                redrawn: row["redrawn"] as? [String]
            )
        }

        let output = Output(base: baseLabel, head: headLabel, engine: result.engine, os: result.os,
                            tolerance: options.tolerance, generated: Date(), results: entries)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(output).write(to: out.appendingPathComponent("compare.json"))

        printSummary(output)
        if options.html {
            print("\nReport: \(page.standardizedFileURL.path)")
        } else {
            try? FileManager.default.removeItem(at: page)
        }
        print("\nJSON:   \(out.appendingPathComponent("compare.json").standardizedFileURL.path)")
        return entries.contains { $0.category == "regressed" } ? 1 : 0
    }

    // MARK: - Summary

    func printSummary(_ output: Output) {
        print("\nReference: \(output.engine) · \(output.os) · font smoothing \(options.fontSmoothing ? "on" : "off") · tolerance \(fmt(output.tolerance)) pts\n")
        let width = max(10, output.results.map(\.name.count).max() ?? 10)

        func line(_ e: Entry) -> String {
            let name = e.name.padding(toLength: width, withPad: " ", startingAt: 0)
            let base = e.base.map { String(format: "%11.2f%%", $0) } ?? label(e.baseStatus).leftPadded(12)
            let head = e.head.map { String(format: "%6.2f%%", $0) } ?? label(e.headStatus)
            let delta = e.delta.map { String(format: "%+7.2f", $0) } ?? ""
            let px = (e.pixelsChanged ?? 0) > 0 ? "   \(e.pixelsChanged!) px changed" : ""
            return "  \(name)  \(base) → \(head)  \(delta)\(px)"
        }

        let groups: [(String, String, String)] = [
            ("regressed", "Regressed", "further from WebKit"),
            ("improved", "Improved", "closer to WebKit"),
            ("changed", "Changed", "pixels differ, score within tolerance"),
            ("error", "Errors", "could not compare"),
        ]
        for (key, title, detail) in groups {
            let items = output.results.filter { $0.category == key }
                .sorted { abs($0.delta ?? 100) > abs($1.delta ?? 100) }
            guard !items.isEmpty else { continue }
            print("\(title) (\(items.count)) — \(detail)")
            items.forEach { print(line($0)) }
            print("")
        }
        printRedrawn(output.results.compactMap { e in e.redrawn.map { (e.name, $0) } })
        if output.results.contains(where: { $0.redrawn != nil }) { print("") }
        let unchanged = output.results.filter { $0.category == "unchanged" }.count
        let regressed = output.results.filter { $0.category == "regressed" }.count
        print("Unchanged: \(unchanged) of \(output.results.count)")
        print(regressed == 0 ? "Result: no regressions" : "Result: \(regressed) regression\(regressed == 1 ? "" : "s")")
    }

    private func fmt(_ v: Double) -> String { String(format: "%g", v) }

    private func label(_ status: String) -> String {
        switch status {
        case "swiftdraw-nil": return "parse failed"
        case "missing": return "missing"
        default: return status
        }
    }

    // MARK: - Base build

    /// Builds this tool against SwiftDraw at `sha` (in a reusable worktree named
    /// after `slot`) and runs its `render` subcommand into `dir`.
    func renderRevision(sha: String, slot: String, repo: URL, work: URL, sources: URL, files: [URL], to dir: URL) throws -> [RenderedFile] {
        let worktree = work.appendingPathComponent("\(slot)-src")
        try prepareWorktree(worktree, sha: sha, repo: repo)
        let tool = work.appendingPathComponent("\(slot)-tool")
        try prepareBaseTool(tool, swiftDraw: worktree, sources: sources)
        step("Building SwiftDraw @ \(sha.prefix(7))")
        try shell(["swift", "build", "-c", "release", "--package-path", tool.path], in: tool, label: "\(slot) build")
        step("Rendering \(slot)")
        try shell([tool.appendingPathComponent(".build/release/swiftdraw-diff").path, "render"]
                  + files.map(\.path)
                  + ["--out", dir.path, "--scale", "\(options.scale)", "--max", "\(options.maxDimension)"],
                  in: work, label: "\(slot) render")
        return try JSONDecoder().decode([RenderedFile].self, from: Data(contentsOf: dir.appendingPathComponent("manifest.json")))
    }

    /// Reuses one worktree across runs so the base build stays incremental.
    func prepareWorktree(_ dir: URL, sha: String, repo: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: dir.appendingPathComponent(".git").path) {
            _ = try git(["checkout", "--quiet", "--detach", "--force", sha], in: dir)
        } else {
            _ = try? git(["worktree", "prune"], in: repo)
            try fm.createDirectory(at: dir.deletingLastPathComponent(), withIntermediateDirectories: true)
            _ = try git(["worktree", "add", "--quiet", "--detach", "--force", dir.path, sha], in: repo)
        }
    }

    /// A copy of this tool's package whose SwiftDraw dependency points at the worktree.
    func prepareBaseTool(_ dir: URL, swiftDraw: URL, sources: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let manifest = """
        // swift-tools-version:6.0
        // Generated by swiftdraw-diff compare: this tool built against SwiftDraw at the base revision.
        import PackageDescription

        let package = Package(
            name: "swiftdraw-diff",
            platforms: [.macOS(.v13)],
            dependencies: [.package(name: "SwiftDraw", path: "\(swiftDraw.path)")],
            targets: [
                .executableTarget(
                    name: "swiftdraw-diff",
                    dependencies: [.product(name: "SwiftDraw", package: "SwiftDraw")]
                )
            ],
            swiftLanguageModes: [.v5]
        )

        """
        let manifestURL = dir.appendingPathComponent("Package.swift")
        if (try? String(contentsOf: manifestURL, encoding: .utf8)) != manifest {
            try manifest.write(to: manifestURL, atomically: true, encoding: .utf8)
        }
        // Copy (not symlink) the sources so SwiftPM sees changes normally.
        let dest = dir.appendingPathComponent("Sources")
        try? fm.removeItem(at: dest)
        try fm.copyItem(at: sources, to: dest)
    }

    // MARK: - Processes

    struct Failure: Error, CustomStringConvertible {
        var description: String
        init(_ description: String) { self.description = description }
    }

    func step(_ text: String) {
        FileHandle.standardError.write(Data("→ \(text)…\n".utf8))
    }

    @discardableResult
    func git(_ args: [String], in dir: URL) throws -> String {
        try shell(["git"] + args, in: dir, label: "git \(args.first ?? "")")
    }

    /// Runs a command, returning trimmed stdout. On failure prints its output and throws.
    @discardableResult
    func shell(_ args: [String], in dir: URL, label: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args
        process.currentDirectoryURL = dir
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(decoding: data, as: UTF8.self)
        guard process.terminationStatus == 0 else {
            FileHandle.standardError.write(Data(output.utf8))
            throw Failure("\(label) failed (exit \(process.terminationStatus))")
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension String {
    func leftPadded(_ width: Int) -> String {
        count >= width ? self : String(repeating: " ", count: width - count) + self
    }
}
