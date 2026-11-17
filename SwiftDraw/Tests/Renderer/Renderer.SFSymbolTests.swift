//
//  Renderer.SFSymbolTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 20/8/22.
//  Copyright 2022 Simon Whitty
//
//  Distributed under the permissive zlib license
//  Get the latest version from here:
//
//  https://github.com/swhitty/SwiftDraw
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

import Foundation
import SwiftDrawDOM
import Testing
@testable import SwiftDraw

struct RendererSFSymbolTests {

    @Test func templateLoads() throws {
        _ = try SFSymbolTemplate.make()
    }

    @Test func fillSymbolHasPathsInEveryWeight() throws {
        let url = try Bundle.test.url(forResource: "chart.svg")
        let template = try SFSymbolTemplate.parse(
            SFSymbolRenderer.render(fileURL: url)
        )

        #expect(!template.ultralight.contents.paths.isEmpty)
        #expect(!template.regular.contents.paths.isEmpty)
        #expect(!template.black.contents.paths.isEmpty)
    }

    @Test func widthGreaterThanHeightScalesByWidth() throws {
        // This svg has a width of 24, but a height of 4. When scaling in SFSymbolRenderer makeTransformation
        // the height was being used to create scale causing the width to be 440 instead of 108.
        let url = try Bundle.test.url(forResource: "dash.svg")
        let template = try SFSymbolTemplate.parse(
            SFSymbolRenderer.render(fileURL: url)
        )

        #expect(template.regular.bounds.size.width == 108.0)
        #expect(template.regular.bounds.size.height == 70.0)

    }

    @Test func transparentLayersAreRemoved() throws {
        let source = try DOM.SVG.parse(
            #"""
            <?xml version="1.0" encoding="UTF-8"?>
            <svg width="64" height="64" version="1.1" xmlns="http://www.w3.org/2000/svg">
                <rect width="100" height="100" fill="currentColor" />
                <rect width="100" height="100" fill="transparent" />
                <rect width="100" height="100" fill="currentColor" opacity="0" />
            </svg>
            """#
        )

        let template = try SFSymbolTemplate.parse(
            SFSymbolRenderer.render(svg: source)
        )

        #expect(template.ultralight.contents.paths.count == 1)
        #expect(template.regular.contents.paths.count == 1)
        #expect(template.black.contents.paths.count == 1)
    }

    @Test func transparentSFSymbolLayersAreNotRemoved() throws {
        let source = try DOM.SVG.parse(
            #"""
            <?xml version="1.0" encoding="UTF-8"?>
            <svg width="64" height="64" version="1.1" xmlns="http://www.w3.org/2000/svg">
                <rect width="100" height="100" fill="currentColor" />
                <rect width="100" height="100" fill="transparent" class="multicolor-0:custom" />
                <rect width="100" height="100" fill="currentColor" opacity="0" class="SFSymbolsPreview" />
            </svg>
            """#
        )

        let template = try SFSymbolTemplate.parse(
            SFSymbolRenderer.render(svg: source)
        )

        #expect(template.ultralight.contents.paths.count == 3)
        #expect(template.regular.contents.paths.count == 3)
        #expect(template.black.contents.paths.count == 3)
    }

    #if canImport(CoreGraphics)
    @Test func strokeSymbolHasPathsInEveryWeight() throws {
        let url = try Bundle.test.url(forResource: "key.svg")
        let template = try SFSymbolTemplate.parse(
            SFSymbolRenderer.render(fileURL: url)
        )

        #expect(!template.ultralight.contents.paths.isEmpty)
        #expect(!template.regular.contents.paths.isEmpty)
        #expect(!template.black.contents.paths.isEmpty)
    }

    @Test func strokeAndTextAreConvertedToPaths() throws {
        let source = try DOM.SVG.parse(
            #"""
            <?xml version="1.0" encoding="UTF-8"?>
            <svg width="64" height="64" version="1.1" xmlns="http://www.w3.org/2000/svg">
                <circle cx="32" cy="32" r="28" fill="none" stroke="black" stroke-width="4" />
                <text font-size="35" x="14" y="45">W</text>
            </svg>
            """#
        )

        let template = try SFSymbolTemplate.parse(
            SFSymbolRenderer.render(svg: source)
        )

        #expect(template.ultralight.contents.paths.count == 2)
        #expect(template.regular.contents.paths.count == 2)
        #expect(template.black.contents.paths.count == 2)
    }
    #endif

    // MARK: - Segment Normalization Tests

    @Test func normalizeSegmentsPromotesLineToCubic() {
        // When one variant has a cubic and another has a line at the same position,
        // the line should be promoted to a degenerate cubic
        var a: [DOM.Path.Segment] = [
            .move(x: 0, y: 0, space: .absolute),
            .cubic(x1: 1, y1: 0, x2: 2, y2: 1, x: 3, y: 1, space: .absolute),
            .close,
        ]
        var b: [DOM.Path.Segment] = [
            .move(x: 0, y: 0, space: .absolute),
            .line(x: 3, y: 1, space: .absolute),
            .close,
        ]
        var c: [DOM.Path.Segment] = [
            .move(x: 0, y: 0, space: .absolute),
            .line(x: 3, y: 1, space: .absolute),
            .close,
        ]

        SFSymbolTemplate.normalizeSegments(&a, &b, &c)

        // b and c should now have cubics instead of lines
        #expect(b[1].isCubic)
        #expect(c[1].isCubic)
        // All should have same count
        #expect(a.count == b.count)
        #expect(b.count == c.count)
    }

    @Test func normalizeSegmentsInsertsDegenerateCubic() {
        // When one variant has an extra segment, a degenerate cubic should be
        // inserted in the other variants to align them
        var a: [DOM.Path.Segment] = [
            .move(x: 0, y: 0, space: .absolute),
            .line(x: 5, y: 0, space: .absolute),
            .cubic(x1: 5, y1: 0, x2: 7, y2: 2, x: 10, y: 5, space: .absolute),
            .line(x: 10, y: 10, space: .absolute),
            .close,
        ]
        var b: [DOM.Path.Segment] = [
            .move(x: 0, y: 0, space: .absolute),
            .line(x: 5, y: 0, space: .absolute),
            .line(x: 10, y: 10, space: .absolute),
            .close,
        ]
        var c: [DOM.Path.Segment] = [
            .move(x: 0, y: 0, space: .absolute),
            .line(x: 5, y: 0, space: .absolute),
            .line(x: 10, y: 10, space: .absolute),
            .close,
        ]

        SFSymbolTemplate.normalizeSegments(&a, &b, &c)

        // All should now have the same number of segments
        #expect(a.count == b.count, "Segment counts should match after normalization")
        #expect(b.count == c.count, "Segment counts should match after normalization")
        // All should have same command types at each position
        for i in 0..<a.count {
            #expect(a[i].commandType == b[i].commandType, "Command types should match at index \(i)")
            #expect(b[i].commandType == c[i].commandType, "Command types should match at index \(i)")
        }
    }

    @Test func normalizeSegmentsLeavesMatchingVariantsUnchanged() {
        // When all three variants already match, no changes should be made
        var a: [DOM.Path.Segment] = [
            .move(x: 0, y: 0, space: .absolute),
            .line(x: 10, y: 10, space: .absolute),
            .close,
        ]
        var b = a
        var c = a

        SFSymbolTemplate.normalizeSegments(&a, &b, &c)

        #expect(a.count == 3)
        #expect(b.count == 3)
        #expect(c.count == 3)
    }

    @Test func commandType() {
        #expect(DOM.Path.Segment.move(x: 0, y: 0, space: .absolute).commandType == .move)
        #expect(DOM.Path.Segment.line(x: 0, y: 0, space: .absolute).commandType == .line)
        #expect(
            DOM.Path.Segment.cubic(x1: 0, y1: 0, x2: 0, y2: 0, x: 0, y: 0, space: .absolute).commandType == .cubic
        )
        #expect(DOM.Path.Segment.close.commandType == .close)
        #expect(DOM.Path.Segment.horizontal(x: 0, space: .absolute).commandType == .line)
        #expect(DOM.Path.Segment.vertical(y: 0, space: .absolute).commandType == .line)
    }

    @Test func promoteLineToCubic() {
        let line = DOM.Path.Segment.line(x: 10, y: 20, space: .absolute)
        let promoted = line.promoteToCubic(from: (x: 0, y: 0))

        if case .cubic(let x1, let y1, let x2, let y2, let x, let y, _) = promoted {
            #expect(x1 == 0)  // control1 at start
            #expect(y1 == 0)
            #expect(x2 == 10)  // control2 at end
            #expect(y2 == 20)
            #expect(x == 10)  // endpoint
            #expect(y == 20)
        } else {
            Issue.record("Expected cubic segment")
        }
    }

    // MARK: - Variant Validation Tests

    @Test func validateVariantsAcceptsMatchingStructure() throws {
        var template = try SFSymbolTemplate.make()
        template.setVariantSegments(ultralight: [.squareSegments], regular: [.squareSegments], black: [.squareSegments])

        try template.validateVariants()
    }

    @Test func validateVariantsThrowsForPathCountMismatch() throws {
        var template = try SFSymbolTemplate.make()
        template.setVariantSegments(
            ultralight: [.squareSegments, .squareSegments],
            regular: [.squareSegments, .squareSegments],
            black: [.squareSegments]
        )

        let error = #expect(throws: (any Error).self) {
            try template.validateVariants()
        }
        let message = error?.localizedDescription ?? ""
        #expect(
            message.contains("path count is 2/2/1"),
            "Expected the path counts in the message, got: \(message)"
        )
    }

    @Test func validateVariantsThrowsForSegmentCountMismatch() throws {
        var template = try SFSymbolTemplate.make()
        template.setVariantSegments(
            ultralight: [.squareSegments],
            regular: [.squareSegments],
            black: [.triangleSegments]
        )

        let error = #expect(throws: (any Error).self) {
            try template.validateVariants()
        }
        let message = error?.localizedDescription ?? ""
        #expect(
            message.contains("path 0 has 4/4/3 segments"),
            "Expected the segment counts in the message, got: \(message)"
        )
    }

    @Test func validateVariantsThrowsForSegmentTypeMismatch() throws {
        var template = try SFSymbolTemplate.make()
        template.setVariantSegments(
            ultralight: [.squareSegments],
            regular: [.squareSegments],
            black: [.curvedSquareSegments]
        )

        let error = #expect(throws: (any Error).self) {
            try template.validateVariants()
        }
        let message = error?.localizedDescription ?? ""
        #expect(
            message.contains("path 0 has mismatched segment types"),
            "Expected a segment type mismatch, got: \(message)"
        )
    }

    @Test func renderThrowsForNonInterpolatableVariants() throws {
        // The regular variant draws its outline with a cubic where black uses a line;
        // normalization cannot align them, so rendering must fail instead of emitting
        // a symbol that crashes CoreUI at draw time.
        let regular = try DOM.SVG.parse(
            #"<svg width="24" height="24"><path d="M0 0 L10 0 C10 5 15 5 15 10 L0 10 Z" /></svg>"#
        )
        let black = try DOM.SVG.parse(
            #"<svg width="24" height="24"><path d="M0 0 L10 0 L15 10 Z" /></svg>"#
        )
        let renderer = SFSymbolRenderer(
            size: .small,
            options: [],
            insets: .init(),
            insetsUltralight: .init(),
            insetsBlack: .init(),
            precision: 3,
            isLegacyInsets: false
        )

        let error = #expect(throws: (any Error).self) {
            try renderer.render(default: regular, ultralight: nil, black: black)
        }
        let message = error?.localizedDescription ?? ""
        #expect(
            message.contains("not interpolatable"),
            "Expected an interpolation error, got: \(message)"
        )
    }
}

private extension SFSymbolTemplate {

    /// Replaces the contents of all three weight variants with paths built from `segments`.
    mutating func setVariantSegments(
        ultralight: [[DOM.Path.Segment]],
        regular: [[DOM.Path.Segment]],
        black: [[DOM.Path.Segment]]
    ) {
        self.ultralight.contents.paths = ultralight.map { .make($0) }
        self.regular.contents.paths = regular.map { .make($0) }
        self.black.contents.paths = black.map { .make($0) }
    }
}

private extension DOM.Path {

    static func make(_ segments: [Segment]) -> DOM.Path {
        let path = DOM.Path(x: 0, y: 0)
        path.segments = segments
        return path
    }
}

private extension [DOM.Path.Segment] {

    static var squareSegments: Self {
        [
            .move(x: 0, y: 0, space: .absolute),
            .line(x: 10, y: 0, space: .absolute),
            .line(x: 10, y: 10, space: .absolute),
            .close,
        ]
    }

    static var triangleSegments: Self {
        [
            .move(x: 0, y: 0, space: .absolute),
            .line(x: 10, y: 0, space: .absolute),
            .close,
        ]
    }

    static var curvedSquareSegments: Self {
        [
            .move(x: 0, y: 0, space: .absolute),
            .cubic(x1: 0, y1: 0, x2: 10, y2: 0, x: 10, y: 0, space: .absolute),
            .line(x: 10, y: 10, space: .absolute),
            .close,
        ]
    }
}

private extension DOM.SVG {
    static func parse(_ text: String, filename: String = #file) throws -> DOM.SVG {
        let element = try XML.SAXParser.parse(data: text.data(using: .utf8)!)
        let parser = XMLParser(options: [], filename: filename)
        return try parser.parseSVG(element)
    }
}

private extension SFSymbolRenderer {

    static func render(fileURL: URL) throws -> String {
        let renderer = SFSymbolRenderer(
            size: .small,
            options: [],
            insets: .init(),
            insetsUltralight: .init(),
            insetsBlack: .init(),
            precision: 3,
            isLegacyInsets: false
        )
        return try renderer.render(regular: fileURL, ultralight: nil, black: nil)
    }

    static func render(svg: DOM.SVG) throws -> String {
        let renderer = SFSymbolRenderer(
            size: .small,
            options: [],
            insets: .init(),
            insetsUltralight: .init(),
            insetsBlack: .init(),
            precision: 3,
            isLegacyInsets: false
        )
        return try renderer.render(default: svg, ultralight: nil, black: nil)
    }
}
