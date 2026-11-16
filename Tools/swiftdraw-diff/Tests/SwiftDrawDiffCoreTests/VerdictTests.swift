import Testing
@testable import SwiftDrawDiffCore

struct VerdictTests {

    @Test(arguments: [
        // webkit, resvg, webkit↔resvg (fractions), expected; match is 1%
        (0.0, 0.0, 0.0, Verdict.pass),
        (0.009, 0.009, 0.5, .pass),                 // both close enough, even if the references disagree
        (0.20, 0.0, 0.20, .webkitDiffers),          // e.g. WebKit's text-anchor offset
        (0.0, 0.30, 0.30, .resvgDiffers),           // e.g. a CSS filter neither WebKit's <img> nor SwiftDraw supports
        (0.30, 0.30, 0.0, .swiftdrawBug),
        (0.30, 0.30, 0.20, .unclear),
        (0.01, 0.0, 0.01, .webkitDiffers),          // the threshold is exclusive
    ])
    func verdict(webkit: Double, resvg: Double, webkitResvg: Double, expected: Verdict) {
        #expect(Verdict(webkit: webkit, resvg: resvg, webkitResvg: webkitResvg, match: 0.01) == expected)
    }

    @Test
    func encodesAsKebabCase() {
        #expect(Verdict.allCases.map(\.rawValue) == ["pass", "webkit-differs", "resvg-differs", "swiftdraw-bug", "unclear"])
    }
}

struct CompareCategoryTests {

    @Test(arguments: [
        // deltas in percentage points (WebKit[, resvg]), pixels changed, expected; tolerance 0.5
        ([0.0], 0, CompareCategory.unchanged),
        ([0.2], 10, .changed),
        ([0.6], 10, .regressed),
        ([-0.6], 10, .improved),
        ([0.0, 0.0], 0, .unchanged),
        ([0.6, 0.0], 10, .regressed),               // further from WebKit, no closer to resvg
        ([0.0, 0.6], 10, .regressed),               // further from resvg, no closer to WebKit
        ([0.6, 0.4], 10, .regressed),               // a little closer to resvg is within tolerance
        ([0.6, -0.6], 10, .mixed),                  // e.g. fixing WebKit's text-anchor offset
        ([-0.6, 0.6], 10, .mixed),
        ([-0.6, 0.0], 10, .improved),
        ([0.3, -0.3], 10, .changed),
        ([], 10, .error),                           // no reference rendered
    ])
    func category(deltas: [Double], pixelsChanged: Int, expected: CompareCategory) {
        #expect(CompareCategory.of(baseRendered: true, headRendered: true,
                                   deltas: deltas, pixelsChanged: pixelsChanged, tolerance: 0.5) == expected)
    }

    @Test
    func renderFailures() {
        func of(_ base: Bool, _ head: Bool) -> CompareCategory {
            .of(baseRendered: base, headRendered: head, deltas: [0], pixelsChanged: 0, tolerance: 0.5)
        }
        #expect(of(true, false) == .regressed)
        #expect(of(false, true) == .improved)
        #expect(of(false, false) == .unchanged)
    }
}
