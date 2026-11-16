import Foundation

/// Parsed command line.
///
///     webkit-render in.svg out.png --size WxH [--scale 2] [--font-smoothing]
///     webkit-render --jobs jobs.json --out <dir> [--scale 2] [--font-smoothing]
///     webkit-render --version
public struct Arguments: Equatable, Sendable {

    public enum Mode: Equatable, Sendable {
        /// Render one SVG to one PNG. `size` is in points.
        case single(input: URL, output: URL, size: Size)
        /// Render every job in `jobs` into `out`, writing `out/manifest.json`.
        case batch(jobs: URL, out: URL)
        case version
        case help
    }

    public var mode: Mode
    /// Pixels per point.
    public var scale: Double = 2
    /// Keep WebKit's default font smoothing. Off by default (see `ReferenceSVG`).
    public var fontSmoothing: Bool = false

    public init(mode: Mode, scale: Double = 2, fontSmoothing: Bool = false) {
        self.mode = mode
        self.scale = scale
        self.fontSmoothing = fontSmoothing
    }

    public struct Error: Swift.Error, Equatable, CustomStringConvertible {
        public var description: String
        public init(_ description: String) { self.description = description }
    }

    /// Parses arguments, excluding the executable name.
    public static func parse(_ args: [String]) throws(Error) -> Arguments {
        var positional: [String] = []
        var size: Size?
        var scale = 2.0
        var fontSmoothing = false
        var jobs: String?
        var out: String?
        var version = false
        var help = false

        var iterator = args.makeIterator()
        func value(for flag: String) throws(Error) -> String {
            guard let value = iterator.next() else { throw Error("\(flag) needs a value") }
            return value
        }

        while let arg = iterator.next() {
            switch arg {
            case "--size":
                let text = try value(for: arg)
                guard let parsed = Size(text) else { throw Error("--size must be WxH with positive numbers, got '\(text)'") }
                size = parsed
            case "--scale":
                let text = try value(for: arg)
                guard let parsed = Double(text), parsed > 0, parsed.isFinite else {
                    throw Error("--scale must be a positive number, got '\(text)'")
                }
                scale = parsed
            case "--font-smoothing":
                fontSmoothing = true
            case "--jobs":
                jobs = try value(for: arg)
            case "--out":
                out = try value(for: arg)
            case "--version":
                version = true
            case "-h", "--help":
                help = true
            default:
                if arg.hasPrefix("--") { throw Error("unknown option \(arg)") }
                positional.append(arg)
            }
        }

        if help { return Arguments(mode: .help) }
        if version { return Arguments(mode: .version) }

        if let jobs {
            guard positional.isEmpty else { throw Error("--jobs does not take input files") }
            guard size == nil else { throw Error("--size is for single files; jobs.json gives each size") }
            guard let out else { throw Error("--jobs needs --out <dir>") }
            return Arguments(mode: .batch(jobs: URL(fileURLWithPath: jobs), out: URL(fileURLWithPath: out)),
                             scale: scale, fontSmoothing: fontSmoothing)
        }

        guard out == nil else { throw Error("--out is for --jobs; give a single file as: in.svg out.png") }
        guard positional.count == 2 else {
            throw Error(positional.isEmpty ? "missing input and output" : "expected in.svg out.png, got \(positional.count) path(s)")
        }
        guard let size else { throw Error("--size WxH is required for a single file") }
        return Arguments(
            mode: .single(input: URL(fileURLWithPath: positional[0]), output: URL(fileURLWithPath: positional[1]), size: size),
            scale: scale,
            fontSmoothing: fontSmoothing
        )
    }

    public static let usage = """
    usage: webkit-render in.svg out.png --size WxH [--scale 2] [--font-smoothing]
           webkit-render --jobs jobs.json --out <dir> [--scale 2] [--font-smoothing]
           webkit-render --version

    Renders SVGs to opaque sRGB PNGs with WebKit: each SVG is drawn as an <img> at WxH points
    onto a white canvas of round(W×scale) × round(H×scale) pixels.

      --size WxH        size in points (single file)
      --scale N         pixels per point (default 2)
      --jobs FILE       JSON array of { "name", "svg", "width", "height" } (points); relative
                        svg paths resolve against the jobs file's directory
      --out DIR         writes DIR/<name>.png and DIR/manifest.json
      --font-smoothing  keep WebKit's font smoothing (off by default: text is drawn antialiased,
                        closer to filled glyph outlines)
      --version         print the WebKit bundle version
    """
}

/// A size in points.
public struct Size: Equatable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    /// Parses `WxH`, e.g. `64x48` or `10.5x20`.
    public init?(_ text: String) {
        let parts = text.lowercased().split(separator: "x", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let w = Double(parts[0]), let h = Double(parts[1]),
              w > 0, h > 0, w.isFinite, h.isFinite else { return nil }
        self.init(width: w, height: h)
    }

    /// The pixel size at `scale`: `round(W×scale) × round(H×scale)`, at least 1×1.
    public func pixels(scale: Double) -> (width: Int, height: Int) {
        (max(1, Int((width * scale).rounded())), max(1, Int((height * scale).rounded())))
    }
}
