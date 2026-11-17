public import Foundation

/// The parsed command line.
public struct Options: Equatable, Sendable {

    public enum Command: String, Sendable {
        /// Score one SwiftDraw revision (default: the working copy).
        case report
        /// Score base and head and report what changed.
        case compare
    }

    /// Where pre-rendered resvg PNGs come from.
    public enum ResvgPNGSource: Equatable, Sendable {
        /// `foo.png` next to `foo.svg`.
        case sibling
        /// `<dir>/<name>.png`, where name is the SVG's report name (its path relative to the input directory).
        case directory(URL)
    }

    /// One SVG to score, and the name its outputs are written under.
    public struct SVGInput: Equatable, Sendable {
        public var url: URL
        /// The path relative to the input directory without `.svg`, e.g. `text/text-anchor/simple-case`;
        /// the file name for a file given directly.
        public var name: String
    }

    public var command = Command.report
    public var inputs: [URL] = []
    public var base = "main"
    /// The SwiftDraw revision to score (report) or compare against base; nil for the working copy.
    public var head: String?
    /// Percentage points a score may move before compare counts it.
    public var tolerance = 0.5
    /// Percent below which two images count as the same in a verdict.
    public var match = 1.0
    /// Pixels per point: 1, 2 or 3 (what `swiftdrawcli --scale` accepts).
    public var scale = 2
    /// Longest side in points.
    public var maxDimension = 1024.0
    public var fontSmoothing = false
    public var html = false
    public var out: URL?
    /// Run the resvg CLI (`--resvg`): the reference, or, with `--resvg-png`, the reference for text and
    /// for files without a usable PNG.
    public var resvgCLI = false
    /// Pre-rendered resvg PNGs (`--resvg-png`).
    public var resvgPNG: ResvgPNGSource?
    /// Whether a file should be scored against its pre-rendered resvg PNG (when the PNG is usable) rather
    /// than the CLI. Text goes to the CLI whenever it can: pre-rendered PNGs, like resvg's test suite with
    /// its Noto fonts, use other fonts than SwiftDraw's fallbacks, which the CLI is given.
    public static func prefersResvgPNG(hasPNGs: Bool, hasCLI: Bool, text: Bool) -> Bool {
        hasPNGs && !(text && hasCLI)
    }

    /// Whether resvg is a reference at all; WebKit only when false.
    public var usesResvg: Bool { resvgCLI || resvgPNG != nil }
    public var swiftdrawPath: URL?
    public var webkitRenderPath: URL?
    public var resvgPath: URL?
    public var cache: URL?
    public var useCache = true

    public init() {}

    public struct Error: Swift.Error, Equatable, CustomStringConvertible {
        public var description: String
        public init(_ description: String) { self.description = description }
    }

    /// Parses arguments, excluding the executable name. Input paths must exist.
    public static func parse(_ args: [String], fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }) throws(Error) -> Options {
        var o = Options()
        var rest = args[...]
        if let first = rest.first, let command = Command(rawValue: first) {
            o.command = command
            rest = rest.dropFirst()
        }
        var iterator = rest.makeIterator()
        func value(_ flag: String) throws(Error) -> String {
            guard let v = iterator.next() else { throw Error("\(flag) needs a value") }
            return v
        }
        func number(_ flag: String, _ valid: (Double) -> Bool) throws(Error) -> Double {
            let text = try value(flag)
            guard let v = Double(text), v.isFinite, valid(v) else { throw Error("invalid value for \(flag): '\(text)'") }
            return v
        }
        func path(_ flag: String) throws(Error) -> URL { URL(fileURLWithPath: try value(flag)) }

        while let a = iterator.next() {
            switch a {
            case "--base": o.base = try value(a)
            case "--head": o.head = try value(a)
            case "--tolerance": o.tolerance = try number(a) { $0 >= 0 }
            case "--match": o.match = try number(a) { $0 > 0 && $0 <= 100 }
            case "--scale":
                let text = try value(a)
                guard let s = Int(text), (1...3).contains(s) else { throw Error("--scale must be 1, 2 or 3 (swiftdrawcli's 1x, 2x, 3x), got '\(text)'") }
                o.scale = s
            case "--max": o.maxDimension = try number(a) { $0 >= 1 }
            case "--font-smoothing": o.fontSmoothing = true
            case "--html": o.html = true
            case "--out": o.out = try path(a)
            case "--resvg": o.resvgCLI = true
            case "--resvg-png":
                let v = try value(a)
                o.resvgPNG = v == "sibling" ? .sibling : .directory(URL(fileURLWithPath: v))
            case "--swiftdraw-path": o.swiftdrawPath = try path(a)
            case "--webkit-render-path": o.webkitRenderPath = try path(a)
            case "--resvg-path": o.resvgPath = try path(a); o.resvgCLI = true
            case "--cache": o.cache = try path(a)
            case "--no-cache": o.useCache = false
            case _ where a.hasPrefix("-"): throw Error("unknown option \(a)")
            default:
                guard fileExists(a) else { throw Error("no such file or directory: \(a)") }
                o.inputs.append(URL(fileURLWithPath: a))
            }
        }
        guard !o.inputs.isEmpty else { throw Error("no SVG files or directories given") }
        if o.command == .report && args.contains("--base") { throw Error("--base is for compare") }
        if o.swiftdrawPath != nil && o.head != nil { throw Error("--swiftdraw-path replaces --head; give one") }
        return o
    }

    /// The SVG files named by `inputs`. Directories contribute every `.svg` file below them (recursively,
    /// skipping hidden files), named by their path relative to the directory and sorted by that name.
    public func svgFiles(fileManager fm: FileManager = .default) -> [SVGInput] {
        inputs.flatMap { url -> [SVGInput] in
            var isDir: ObjCBool = false
            fm.fileExists(atPath: url.path, isDirectory: &isDir)
            let url = url.standardizedFileURL.resolvingSymlinksInPath()
            guard isDir.boolValue else { return [SVGInput(url: url, name: url.deletingPathExtension().lastPathComponent)] }
            let root = url.path.hasSuffix("/") ? url.path : url.path + "/"
            let items = fm.enumerator(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])?
                .compactMap { $0 as? URL } ?? []
            return items.filter { $0.pathExtension.lowercased() == "svg" }
                .compactMap { item -> SVGInput? in
                    let item = item.standardizedFileURL.resolvingSymlinksInPath()
                    guard item.path.hasPrefix(root) else { return nil }
                    let relative = String(item.path.dropFirst(root.count))
                    return SVGInput(url: item, name: String(relative.dropLast(item.pathExtension.count + 1)))
                }
                .sorted { $0.name < $1.name }
        }
    }

    public static let usage = """
    usage:
      swiftdraw-diff [report] <file.svg | dir>... [--head <ref>] [--resvg] [--html]
          Render with SwiftDraw (the working copy, or --head) and score each file against WebKit,
          and against resvg with --resvg.

      swiftdraw-diff compare [--base main] [--head <ref>] <file.svg | dir>... [--tolerance 0.5] [--resvg] [--html]
          Render with SwiftDraw at --base and at --head (default: the working copy), score both and
          report what changed. Exits 1 if any file regressed: moved further from a reference by more
          than --tolerance percentage points without moving closer to the other.

    references:
      WebKit always (Tools/webkit-render, built on first use). It also decides each SVG's size.
      --resvg                 also score against resvg (on PATH; brew install resvg)
      --resvg-png sibling|DIR also score against pre-rendered PNGs: foo.png beside foo.svg, or in DIR.
                              A PNG must be the compare size. With --resvg too, the resvg CLI renders
                              files whose PNG is missing or another size, and every file with <text>:
                              pre-rendered PNGs use their own fonts (resvg's suite uses Noto), while the
                              CLI uses SwiftDraw's fallback fonts. Without --resvg, text is compared
                              against the PNGs, and the summary says so.
                              resvg's bundled test PNGs are 300×300 and WebKit sizes its 200×200
                              viewBox-only tests at 150×150 pt, so they need --scale 2
      --match 1               percent below which two images count as the same in verdicts

    text:
      With resvg, files containing <text> are judged by resvg alone: their verdict and compare
      category ignore WebKit, which offsets middle- and end-anchored text. Their WebKit score is
      still shown, for information.

    renderers (built or found automatically; override with a path):
      --swiftdraw-path BIN    a swiftdrawcli binary to score instead of building one
      --webkit-render-path BIN
      --resvg-path BIN        (implies --resvg)

    common:
      --scale 2               pixels per point: 1, 2 or 3
      --max 1024              longest side in points
      --font-smoothing        keep WebKit's font smoothing (off by default: text is compared with
                              its glyph outlines, as SwiftDraw draws it)
      --out DIR               output folder (default .build/report or .build/compare/report)
      --html                  also write index.html, a visual report for people (large: every image
                              is embedded; agents should not read it)
      --cache DIR             cache for swiftdrawcli builds and renders (default
                              ~/Library/Caches/swiftdraw-diff); --no-cache to render everything

    exit status: 0 ok, 1 regressions (compare), 2 error
    """
}
