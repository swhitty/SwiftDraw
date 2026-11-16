import Foundation
import SwiftDrawDiffCore

/// Everything rendered for one file.
struct RenderedFile: Sendable {
    var file: InputFile
    /// The size every renderer was asked for: WebKit's, or SwiftDraw's own when WebKit failed.
    var size: PointSize?
    var webkit: WebKitManifestEntry?
    var head: RenderResult
    var base: RenderResult?
    var resvg: RenderResult?

    var webkitResult: RenderResult {
        guard let webkit else { return .failed("not rendered") }
        return webkit.rendered ? .ok : .failed(webkit.error ?? webkit.status)
    }
}

/// Output folders under `--out`.
struct OutputDirs {
    var root: URL
    /// SwiftDraw's renders: `swiftdraw/` in report mode, `head/` in compare.
    var head: URL
    var base: URL { root.appendingPathComponent("base") }
    var webkit: URL { root.appendingPathComponent("webkit") }
    var resvg: URL { root.appendingPathComponent("resvg") }
    var svg: URL { root.appendingPathComponent("svg") }
    var diff: URL { root.appendingPathComponent("diff") }
    var scratch: URL { root.appendingPathComponent(".scratch") }

    init(root: URL, headName: String) {
        self.root = root
        self.head = root.appendingPathComponent(headName)
    }

    func create(base: Bool, resvg: Bool) throws {
        let fm = FileManager.default
        try? fm.removeItem(at: root)
        var dirs = [head, webkit, svg, diff, scratch]
        if base { dirs.append(self.base) }
        if resvg { dirs.append(self.resvg) }
        for dir in dirs { try fm.createDirectory(at: dir, withIntermediateDirectories: true) }
    }

    func png(_ dir: URL, _ name: String) -> URL { dir.appendingPathComponent("\(name).png") }
}

enum Pipeline {

    /// Reads the input SVGs. Names must be unique: outputs are named after them.
    static func inputs(_ options: Options, copyTo svgDir: URL) throws -> [InputFile] {
        let urls = options.svgFiles()
        guard !urls.isEmpty else { throw ToolError("no SVG files found") }
        var seen: [String: URL] = [:]
        return try urls.map { url in
            let name = url.deletingPathExtension().lastPathComponent
            if let other = seen[name] { throw ToolError("two inputs are named \(name): \(other.path) and \(url.path)") }
            seen[name] = url
            let data = (try? Data(contentsOf: url)) ?? Data()
            try? data.write(to: svgDir.appendingPathComponent("\(name).svg"))
            return InputFile(name: name, svg: url, data: data, hash: RenderCache.hash(data))
        }
    }

    /// Renders every file with WebKit, then SwiftDraw (head, then base) and resvg at WebKit's size.
    static func render(
        _ files: [InputFile], options: Options, cache: RenderCache, dirs: OutputDirs,
        webkit: WebKitRenderer, head: SwiftDrawRenderer, base: SwiftDrawRenderer?, resvg: ResvgRenderer?
    ) async throws -> [RenderedFile] {
        let webkitResults = try await webkit.render(files, options: options, cache: cache, into: dirs.webkit, scratch: dirs.scratch)
        let scale = options.scale

        // Head first: where WebKit could not size a file, SwiftDraw's own size is used for the rest.
        let progress = Progress("Rendering SwiftDraw", total: files.count * (base == nil ? 1 : 2))
        step("Rendering with SwiftDraw \(head.label)")
        var rendered = await concurrentMap(files) { file -> RenderedFile in
            let entry = webkitResults[file.name]
            var size: PointSize?
            if let entry, entry.rendered, let w = entry.layoutWidth, let h = entry.layoutHeight {
                size = PointSize(width: Int(w), height: Int(h))
            }
            let (result, used) = await head.render(file, size: size, scale: scale, cache: cache, to: dirs.png(dirs.head, file.name))
            progress.tick()
            return RenderedFile(file: file, size: size ?? (result.rendered ? used : nil), webkit: entry, head: result)
        }

        if let base {
            step("Rendering with SwiftDraw \(base.label)")
            let results = await concurrentMap(rendered) { r -> RenderResult in
                defer { progress.tick() }
                guard let size = r.size else { return .failed("no size: neither WebKit nor head rendered it") }
                return await base.render(r.file, size: size, scale: scale, cache: cache, to: dirs.png(dirs.base, r.file.name)).0
            }
            for i in rendered.indices { rendered[i].base = results[i] }
        }

        if let resvg {
            step(resvg.isPNG ? "Reading \(resvg.label)" : "Rendering with \(resvg.label)")
            let results = await concurrentMap(rendered) { r -> RenderResult in
                guard let size = r.size else { return .failed("no size") }
                return await resvg.render(r.file, pixels: size.pixels(scale: scale), cache: cache, to: dirs.png(dirs.resvg, r.file.name))
            }
            for i in rendered.indices { rendered[i].resvg = results[i] }
        }
        try? FileManager.default.removeItem(at: dirs.scratch)
        return rendered
    }

    /// The pixel size every image of `r` is compared at.
    static func pixels(_ r: RenderedFile, scale: Int) -> (width: Int, height: Int)? {
        r.size?.pixels(scale: scale)
    }

    /// Loads a rendered image at the compare size. SwiftDraw's and WebKit's must already be that size;
    /// resvg's CLI output is padded or cropped (it keeps the aspect ratio when fitting -w × -h);
    /// pre-rendered PNGs must match.
    static func load(_ url: URL, size: (width: Int, height: Int), fit: Bool) -> Result<Bitmap, ToolError> {
        do {
            let bitmap = try Bitmap(contentsOf: url)
            if bitmap.width == size.width && bitmap.height == size.height { return .success(bitmap) }
            if fit { return .success(bitmap.fitted(width: size.width, height: size.height)) }
            return .failure(ToolError("image is \(bitmap.width)×\(bitmap.height), expected \(size.width)×\(size.height)"))
        } catch {
            return .failure(ToolError("\(error)"))
        }
    }
}
