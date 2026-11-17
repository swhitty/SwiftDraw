public import Foundation

/// How SwiftDraw relates to the two references for one file, when resvg is enabled.
///
/// Neither reference is treated as the truth: WebKit's `<img>` rendering lacks some SVG 2 and
/// CSS features, and resvg has gaps of its own. Where the references disagree the verdict names
/// the one SwiftDraw differs from, and leaves the judgement to the reader.
public enum Verdict: String, Codable, Sendable, CaseIterable {
    /// SwiftDraw matches both references.
    case pass
    /// SwiftDraw matches resvg; WebKit is the odd one out.
    case webkitDiffers = "webkit-differs"
    /// SwiftDraw matches WebKit; resvg is the odd one out. Often a feature both WebKit's
    /// `<img>` path and SwiftDraw lack.
    case resvgDiffers = "resvg-differs"
    /// The references agree and SwiftDraw matches neither.
    case swiftdrawBug = "swiftdraw-bug"
    /// All three differ.
    case unclear

    /// Scores are fractions (0...1); `match` is the fraction below which two images count as the same.
    /// - Parameter text: the file contains text, which is judged by resvg: where all three differ,
    ///   SwiftDraw not matching resvg is a SwiftDraw bug rather than unclear, since WebKit's `<img>`
    ///   path offsets middle- and end-anchored text (Chrome, resvg and SwiftDraw agree on it).
    public init(webkit: Double, resvg: Double, webkitResvg: Double, match: Double, text: Bool = false) {
        let sw = webkit < match, sr = resvg < match, wr = webkitResvg < match
        switch (sw, sr) {
        case (true, true): self = .pass
        case (false, true): self = .webkitDiffers
        case (true, false): self = .resvgDiffers
        case (false, false): self = wr || text ? .swiftdrawBug : .unclear
        }
    }

    public var label: String {
        switch self {
        case .pass: return "pass"
        case .webkitDiffers: return "pass, WebKit differs"
        case .resvgDiffers: return "pass, resvg differs"
        case .swiftdrawBug: return "SwiftDraw bug"
        case .unclear: return "unclear"
        }
    }

    /// Worst first, for sorting.
    public var rank: Int {
        switch self {
        case .swiftdrawBug: return 0
        case .unclear: return 1
        case .resvgDiffers: return 2
        case .webkitDiffers: return 3
        case .pass: return 4
        }
    }
}

/// How one file changed between base and head in `compare`.
public enum CompareCategory: String, Codable, Sendable, CaseIterable {
    /// Further from a reference without getting closer to the other, or head no longer renders.
    case regressed
    /// Further from one reference and closer to the other. Reported, but not a failure.
    case mixed
    case improved
    /// Pixels differ, scores within tolerance.
    case changed
    case unchanged
    /// No reference rendered, so nothing to score against.
    case error
    /// Further from the only reference that could be used for this file while a second one was
    /// expected (e.g. resvg failed, or its PNG is the wrong size). Reported, but not a failure:
    /// without the second reference a fix for a WebKit bug looks the same as a regression.
    case noSecondReference = "no-second-reference"

    /// - Parameters:
    ///   - deltas: head score minus base score, in percentage points, for each reference that rendered.
    ///   - tolerance: percentage points a score may move before it counts.
    ///   - missingReference: a second reference was expected but `deltas` lacks it.
    public static func of(
        baseRendered: Bool, headRendered: Bool,
        deltas: [Double], pixelsChanged: Int, tolerance: Double, missingReference: Bool = false
    ) -> CompareCategory {
        switch (baseRendered, headRendered) {
        case (false, false): return .unchanged // e.g. an intentionally invalid SVG
        case (true, false): return .regressed
        case (false, true): return .improved
        case (true, true): break
        }
        guard !deltas.isEmpty else { return .error }
        let worse = deltas.contains { $0 > tolerance }
        let better = deltas.contains { $0 < -tolerance }
        switch (worse, better) {
        case (true, true): return .mixed
        case (true, false): return missingReference ? .noSecondReference : .regressed
        case (false, true): return .improved
        case (false, false): return pixelsChanged > 0 ? .changed : .unchanged
        }
    }
}

/// Text detection for the text rule: files containing text are judged by resvg.
public enum TextContent {
    /// Whether the SVG contains a `<text>` element (optionally namespace-prefixed).
    public static func contains(_ svg: Data) -> Bool {
        String(decoding: svg, as: UTF8.self).contains(/<(?:[A-Za-z_][\w.\-]*:)?text[\s\/>]/)
    }
}
