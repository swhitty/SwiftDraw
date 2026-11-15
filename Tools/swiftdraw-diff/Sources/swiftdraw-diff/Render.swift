import CoreGraphics
import Foundation
import SwiftDraw

/// One SVG rendered by SwiftDraw. Width/height are in points (the size the
/// browser lays the SVG out at); the PNG itself is `scale`x that.
struct RenderedFile: Codable {
    var name: String
    var width: Int
    var height: Int
    /// "rendered", "swiftdraw-nil" (parse failed), "read-failed" or "bitmap-failed".
    var status: String
}

/// Renders an SVG with SwiftDraw onto white, sRGB, at `scale`x its point size
/// (clamped so the longest side is at most `maxDimension` points).
func renderSwiftDraw(_ url: URL, scale: CGFloat, maxDimension: CGFloat) -> (RenderedFile, Bitmap?) {
    let name = url.deletingPathExtension().lastPathComponent
    guard let data = try? Data(contentsOf: url) else {
        return (RenderedFile(name: name, width: 0, height: 0, status: "read-failed"), nil)
    }
    guard let svg = SVG(data: data) else {
        return (RenderedFile(name: name, width: 0, height: 0, status: "swiftdraw-nil"), nil)
    }
    var size = svg.size
    let longest = max(size.width, size.height)
    if longest > maxDimension {
        size = CGSize(width: size.width * maxDimension / longest, height: size.height * maxDimension / longest)
    }
    let w = max(1, Int(size.width.rounded())), h = max(1, Int(size.height.rounded()))
    let pw = Int(CGFloat(w) * scale), ph = Int(CGFloat(h) * scale)

    // Draw unflipped, then flip the rows for a top-left origin. Flipping the CTM before
    // ctx.draw(svg) would leave CGPattern tiles in the unflipped default space, so patterns
    // would render upside down here although they render correctly in views and image APIs.
    let bitmap = Bitmap.render(width: pw, height: ph) { ctx in
        ctx.draw(svg, in: CGRect(x: 0, y: 0, width: pw, height: ph))
    }?.flippedVertically()
    return (RenderedFile(name: name, width: w, height: h, status: bitmap == nil ? "bitmap-failed" : "rendered"), bitmap)
}

/// Renders every file to `<dir>/<name>.png` and writes `<dir>/manifest.json`.
/// This is what `swiftdraw-diff render` does, so a build of the tool against
/// another SwiftDraw revision can produce comparable output.
@discardableResult
func renderAll(_ files: [URL], scale: CGFloat, maxDimension: CGFloat, to dir: URL) throws -> [RenderedFile] {
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    var manifest: [RenderedFile] = []
    for url in files {
        let (file, bitmap) = renderSwiftDraw(url, scale: scale, maxDimension: maxDimension)
        if let bitmap {
            try bitmap.writePNG(to: dir.appendingPathComponent("\(file.name).png"))
        }
        manifest.append(file)
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(manifest).write(to: dir.appendingPathComponent("manifest.json"))
    return manifest
}
