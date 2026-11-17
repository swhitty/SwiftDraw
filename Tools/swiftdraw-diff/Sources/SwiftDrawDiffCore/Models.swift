public import Foundation

/// One entry of webkit-render's `manifest.json`.
public struct WebKitManifestEntry: Codable, Equatable, Sendable {
    public var name: String
    public var status: String
    public var error: String?
    public var redrawn: Int?
    /// PNG size in pixels; 0 when it failed before a size was known.
    public var width: Int
    public var height: Int
    public var layoutWidth: Double?
    public var layoutHeight: Double?
    public var naturalWidth: Double?
    public var naturalHeight: Double?

    public var rendered: Bool { status == "rendered" }

    public init(name: String, status: String, error: String? = nil, redrawn: Int? = nil, width: Int, height: Int,
                layoutWidth: Double? = nil, layoutHeight: Double? = nil, naturalWidth: Double? = nil, naturalHeight: Double? = nil) {
        self.name = name
        self.status = status
        self.error = error
        self.redrawn = redrawn
        self.width = width
        self.height = height
        self.layoutWidth = layoutWidth
        self.layoutHeight = layoutHeight
        self.naturalWidth = naturalWidth
        self.naturalHeight = naturalHeight
    }
}

/// A size in whole points, as every renderer is asked for it.
public struct PointSize: Codable, Equatable, Hashable, Sendable {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    public func pixels(scale: Int) -> (width: Int, height: Int) { (width * scale, height * scale) }
}

/// One rendering of one file by one renderer.
public struct RenderResult: Codable, Equatable, Sendable {
    public var rendered: Bool
    /// Why it did not render.
    public var error: String?
    /// For resvg: where the image came from, "png" (pre-rendered) or "cli".
    public var source: String?

    public static let ok = RenderResult(rendered: true, error: nil)
    public static func failed(_ error: String) -> RenderResult { RenderResult(rendered: false, error: error) }

    public func from(_ source: String) -> RenderResult {
        var r = self
        r.source = source
        return r
    }
}

/// `scores.json`, written by report mode.
public struct ScoresReport: Codable, Sendable {
    public var swiftdraw: String
    public var engine: String
    public var resvg: String?
    public var os: String
    public var scale: Int
    /// Percent; the verdict threshold.
    public var match: Double
    public var fontSmoothing: Bool
    /// The reference files containing text are judged by: "resvg", or "webkit" without resvg.
    public var textReference: String
    public var generated: Date
    public var results: [Score]

    public init(swiftdraw: String, engine: String, resvg: String?, os: String, scale: Int, match: Double,
                fontSmoothing: Bool, textReference: String, generated: Date, results: [Score]) {
        self.swiftdraw = swiftdraw
        self.engine = engine
        self.resvg = resvg
        self.os = os
        self.scale = scale
        self.match = match
        self.fontSmoothing = fontSmoothing
        self.textReference = textReference
        self.generated = generated
        self.results = results
    }

    public struct Score: Codable, Sendable {
        public var name: String
        /// "scored", or why not: "swiftdraw-failed", "no-reference".
        public var status: String
        /// Fraction of ink pixels that differ from WebKit, 0...1.
        public var score: Double?
        /// Fraction of ink pixels that differ from resvg, 0...1.
        public var resvg: Double?
        /// WebKit against resvg, 0...1.
        public var webkitResvg: Double?
        public var verdict: Verdict?
        /// True when the file contains text, which is judged by resvg.
        public var text: Bool?
        /// Where the resvg image came from: "png" (pre-rendered) or "cli".
        public var resvgSource: String?
        /// Points, as rendered.
        public var size: PointSize?
        public var errors: [String: String]?
        public var redrawn: Int?

        public init(name: String, status: String, score: Double? = nil, resvg: Double? = nil, webkitResvg: Double? = nil,
                    verdict: Verdict? = nil, size: PointSize? = nil, errors: [String: String]? = nil, redrawn: Int? = nil) {
            self.name = name
            self.status = status
            self.score = score
            self.resvg = resvg
            self.webkitResvg = webkitResvg
            self.verdict = verdict
            self.size = size
            self.errors = errors
            self.redrawn = redrawn
        }
    }
}

/// `compare.json`, written by compare mode. Scores are percentages (0...100).
public struct CompareReport: Codable, Sendable {
    public var base: String
    public var head: String
    public var engine: String
    public var resvg: String?
    public var os: String
    public var scale: Int
    public var tolerance: Double
    public var match: Double
    public var fontSmoothing: Bool
    /// The reference files containing text are judged by: "resvg", or "webkit" without resvg.
    public var textReference: String
    public var generated: Date
    public var results: [Entry]

    public init(base: String, head: String, engine: String, resvg: String?, os: String, scale: Int, tolerance: Double,
                match: Double, fontSmoothing: Bool, textReference: String, generated: Date, results: [Entry]) {
        self.base = base
        self.head = head
        self.engine = engine
        self.resvg = resvg
        self.os = os
        self.scale = scale
        self.tolerance = tolerance
        self.match = match
        self.fontSmoothing = fontSmoothing
        self.textReference = textReference
        self.generated = generated
        self.results = results
    }

    public struct Entry: Codable, Sendable {
        public var name: String
        public var category: CompareCategory
        /// Difference from WebKit, percent.
        public var base: Double?
        public var head: Double?
        public var delta: Double?
        /// Difference from resvg, percent.
        public var baseResvg: Double?
        public var headResvg: Double?
        public var deltaResvg: Double?
        /// WebKit against resvg, percent.
        public var webkitResvg: Double?
        public var baseVerdict: Verdict?
        public var headVerdict: Verdict?
        /// True when the file contains text, which is judged by resvg.
        public var text: Bool?
        /// The references the category was decided by ("webkit", "resvg"); the others are for information.
        public var judgedBy: [String]?
        /// Where the resvg image came from: "png" (pre-rendered) or "cli".
        public var resvgSource: String?
        /// Pixels that differ between base and head (exact, unblurred).
        public var pixelsChanged: Int?
        /// "rendered" or "failed".
        public var baseStatus: String
        public var headStatus: String
        public var size: PointSize?
        public var errors: [String: String]?
        public var redrawn: Int?

        public init(name: String, category: CompareCategory, baseStatus: String, headStatus: String,
                    size: PointSize? = nil, redrawn: Int? = nil) {
            self.name = name
            self.category = category
            self.baseStatus = baseStatus
            self.headStatus = headStatus
            self.size = size
            self.redrawn = redrawn
        }
    }
}

public extension JSONEncoder {
    static var report: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
