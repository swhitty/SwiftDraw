//
//  Renderer.SFSymbolStrokeScaleTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 22/4/26.
//  Copyright 2026 Simon Whitty
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

import SwiftDrawDOM
import XCTest
@testable import SwiftDraw

final class RendererSFSymbolStrokeScaleTests: XCTestCase {

    // MARK: - StrokeWidthScale parser

    func testParsesDecimal() throws {
        let scale = try XCTUnwrap(SFSymbolRenderer.StrokeWidthScale(rawValue: "0.5"))
        XCTAssertEqual(scale.multiplier, 0.5)
    }

    func testParsesInteger() throws {
        let scale = try XCTUnwrap(SFSymbolRenderer.StrokeWidthScale(rawValue: "2"))
        XCTAssertEqual(scale.multiplier, 2.0)
    }

    func testParsesPercent() throws {
        let scale = try XCTUnwrap(SFSymbolRenderer.StrokeWidthScale(rawValue: "50%"))
        XCTAssertEqual(scale.multiplier, 0.5)
    }

    func testParsesPercentAboveOneHundred() throws {
        let scale = try XCTUnwrap(SFSymbolRenderer.StrokeWidthScale(rawValue: "200%"))
        XCTAssertEqual(scale.multiplier, 2.0)
    }

    func testParsesWithSurroundingWhitespace() throws {
        let scale = try XCTUnwrap(SFSymbolRenderer.StrokeWidthScale(rawValue: "  75%  "))
        XCTAssertEqual(scale.multiplier, 0.75)
    }

    func testRejectsZero() {
        XCTAssertNil(SFSymbolRenderer.StrokeWidthScale(rawValue: "0"))
        XCTAssertNil(SFSymbolRenderer.StrokeWidthScale(rawValue: "0%"))
    }

    func testRejectsNegative() {
        XCTAssertNil(SFSymbolRenderer.StrokeWidthScale(rawValue: "-1"))
        XCTAssertNil(SFSymbolRenderer.StrokeWidthScale(rawValue: "-50%"))
    }

    func testRejectsEmpty() {
        XCTAssertNil(SFSymbolRenderer.StrokeWidthScale(rawValue: ""))
        XCTAssertNil(SFSymbolRenderer.StrokeWidthScale(rawValue: "   "))
    }

    func testRejectsMalformed() {
        XCTAssertNil(SFSymbolRenderer.StrokeWidthScale(rawValue: "abc"))
        XCTAssertNil(SFSymbolRenderer.StrokeWidthScale(rawValue: "1.5x"))
        XCTAssertNil(SFSymbolRenderer.StrokeWidthScale(rawValue: "%50"))
    }

    // MARK: - Walker on element attributes

    func testScalesElementStrokeWidthAttribute() throws {
        let url = try Bundle.test.url(forResource: "stroke-attribute.svg")
        let svg = try DOM.SVG.parse(fileURL: url)
        let count = StrokeWidthScaler.scale(svg, by: .init(multiplier: 0.5))

        XCTAssertEqual(count, 1)
        let line = try XCTUnwrap(svg.childElements.first as? DOM.Line)
        XCTAssertEqual(line.attributes.strokeWidth, 2)
    }

    // MARK: - Walker on inline style

    func testScalesInlineStyleStrokeWidth() throws {
        let url = try Bundle.test.url(forResource: "stroke-inline-style.svg")
        let svg = try DOM.SVG.parse(fileURL: url)
        let count = StrokeWidthScaler.scale(svg, by: .init(multiplier: 2.0))

        XCTAssertEqual(count, 1)
        let line = try XCTUnwrap(svg.childElements.first as? DOM.Line)
        XCTAssertEqual(line.style.strokeWidth, 12)
    }

    // MARK: - Walker on stylesheet

    func testScalesStylesheetStrokeWidth() throws {
        let url = try Bundle.test.url(forResource: "stroke-stylesheet.svg")
        let svg = try DOM.SVG.parse(fileURL: url)
        let count = StrokeWidthScaler.scale(svg, by: .init(multiplier: 0.25))

        XCTAssertEqual(count, 1)
        let sheet = try XCTUnwrap(svg.styles.first)
        let attrs = try XCTUnwrap(sheet.attributes[.class("bar")])
        XCTAssertEqual(attrs.strokeWidth, 2)
    }

    // MARK: - Walker across all sources

    func testScalesAcrossAllSources() throws {
        let url = try Bundle.test.url(forResource: "stroke-mixed.svg")
        let svg = try DOM.SVG.parse(fileURL: url)
        let count = StrokeWidthScaler.scale(svg, by: .init(multiplier: 2.0))

        // 4 stroke-width values: group attribute (3 -> 6),
        // line attribute (4 -> 8), inline style (5 -> 10), stylesheet (2 -> 4)
        XCTAssertEqual(count, 4)
    }

    // MARK: - Walker reports zero when nothing to scale

    func testReportsZeroWhenNoStrokes() throws {
        let url = try Bundle.test.url(forResource: "stroke-none.svg")
        let svg = try DOM.SVG.parse(fileURL: url)
        let count = StrokeWidthScaler.scale(svg, by: .init(multiplier: 0.5))

        XCTAssertEqual(count, 0)
    }

    // MARK: - Walker recurses through groups

    func testScalesNestedGroups() throws {
        let svg = try DOM.SVG.parse(xml: #"""
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <g stroke="black" stroke-width="10">
                <g stroke-width="20">
                    <line x1="0" y1="0" x2="100" y2="100" stroke-width="30"/>
                </g>
            </g>
        </svg>
        """#)

        let count = StrokeWidthScaler.scale(svg, by: .init(multiplier: 0.5))
        XCTAssertEqual(count, 3)
    }

    // MARK: - Walker visits clipPath defs

    func testScalesInsideClipPath() throws {
        let svg = try DOM.SVG.parse(xml: #"""
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <defs>
                <clipPath id="cp">
                    <rect x="0" y="0" width="50" height="50" stroke-width="6"/>
                </clipPath>
            </defs>
            <rect x="0" y="0" width="100" height="100" stroke="black" stroke-width="4" clip-path="url(#cp)"/>
        </svg>
        """#)

        let count = StrokeWidthScaler.scale(svg, by: .init(multiplier: 0.5))
        XCTAssertEqual(count, 2)
    }

    // MARK: - Integration through SFSymbolRenderer

    func testRendersUltralightVariantFromScale() throws {
        let url = try Bundle.test.url(forResource: "chart.svg")
        let renderer = SFSymbolRenderer.makeStrokeScaling(
            ultralight: .init(multiplier: 0.5),
            black: .init(multiplier: 2.0)
        )
        let template = try SFSymbolTemplate.parse(
            try renderer.render(regular: url, ultralight: nil, black: nil)
        )

        XCTAssertFalse(template.ultralight.contents.paths.isEmpty)
        XCTAssertFalse(template.regular.contents.paths.isEmpty)
        XCTAssertFalse(template.black.contents.paths.isEmpty)
    }

    func testStrokeScaledVariantsDifferFromRegular() throws {
        // Heavier strokes expand outlines into wider paths, so the ultralight
        // and black variants should not be byte-identical to regular
        let url = try Bundle.test.url(forResource: "chart.svg")
        let renderer = SFSymbolRenderer.makeStrokeScaling(
            ultralight: .init(multiplier: 0.25),
            black: .init(multiplier: 4.0)
        )
        let template = try SFSymbolTemplate.parse(
            try renderer.render(regular: url, ultralight: nil, black: nil)
        )

        let ultralightPaths = template.ultralight.contents.paths
        let regularPaths = template.regular.contents.paths
        let blackPaths = template.black.contents.paths

        XCTAssertEqual(ultralightPaths.count, regularPaths.count)
        XCTAssertEqual(blackPaths.count, regularPaths.count)

        let ultralightSegments = ultralightPaths.flatMap(\.segments)
        let regularSegments = regularPaths.flatMap(\.segments)
        let blackSegments = blackPaths.flatMap(\.segments)
        XCTAssertNotEqual(ultralightSegments, regularSegments)
        XCTAssertNotEqual(blackSegments, regularSegments)
    }
}

private extension SFSymbolRenderer {

    static func makeStrokeScaling(ultralight: StrokeWidthScale?, black: StrokeWidthScale?) -> SFSymbolRenderer {
        SFSymbolRenderer(
            size: .small,
            options: [],
            insets: .init(),
            insetsUltralight: .init(),
            insetsBlack: .init(),
            precision: 3,
            isLegacyInsets: false,
            ultralightStrokeScale: ultralight,
            blackStrokeScale: black
        )
    }
}
