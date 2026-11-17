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

import Foundation
import SwiftDrawDOM
import Testing
@testable import SwiftDraw

struct RendererSFSymbolStrokeScaleTests {

    // MARK: - StrokeWidthScale parser

    @Test(
        arguments: [
            ("0.5", 0.5),
            ("2", 2.0),
            ("50%", 0.5),
            ("200%", 2.0),
            ("  75%  ", 0.75),
        ] as [(String, Double)]
    )
    func parsesMultiplier(rawValue: String, multiplier: Double) throws {
        let scale = try #require(SFSymbolRenderer.StrokeWidthScale(rawValue: rawValue))
        #expect(scale.multiplier == multiplier)
    }

    @Test(
        arguments: [
            // zero
            "0", "0%",
            // negative
            "-1", "-50%",
            // empty
            "", "   ",
            // malformed
            "abc", "1.5x", "%50",
        ]
    )
    func rejectsInvalidValue(rawValue: String) {
        #expect(SFSymbolRenderer.StrokeWidthScale(rawValue: rawValue) == nil)
    }

    // MARK: - Walker on element attributes

    @Test func scalesElementStrokeWidthAttribute() throws {
        let url = try Bundle.test.url(forResource: "stroke-attribute.svg")
        let svg = try DOM.SVG.parse(fileURL: url)
        let count = StrokeWidthScaler.scale(svg, by: .init(multiplier: 0.5))

        #expect(count == 1)
        let line = try #require(svg.childElements.first as? DOM.Line)
        #expect(line.attributes.strokeWidth == 2)
    }

    // MARK: - Walker on inline style

    @Test func scalesInlineStyleStrokeWidth() throws {
        let url = try Bundle.test.url(forResource: "stroke-inline-style.svg")
        let svg = try DOM.SVG.parse(fileURL: url)
        let count = StrokeWidthScaler.scale(svg, by: .init(multiplier: 2.0))

        #expect(count == 1)
        let line = try #require(svg.childElements.first as? DOM.Line)
        #expect(line.style.strokeWidth == 12)
    }

    // MARK: - Walker on stylesheet

    @Test func scalesStylesheetStrokeWidth() throws {
        let url = try Bundle.test.url(forResource: "stroke-stylesheet.svg")
        let svg = try DOM.SVG.parse(fileURL: url)
        let count = StrokeWidthScaler.scale(svg, by: .init(multiplier: 0.25))

        #expect(count == 1)
        let sheet = try #require(svg.styles.first)
        let attrs = try #require(sheet.attributes[.class("bar")])
        #expect(attrs.strokeWidth == 2)
    }

    // MARK: - Walker across all sources

    @Test func scalesAcrossAllSources() throws {
        let url = try Bundle.test.url(forResource: "stroke-mixed.svg")
        let svg = try DOM.SVG.parse(fileURL: url)
        let count = StrokeWidthScaler.scale(svg, by: .init(multiplier: 2.0))

        // 4 stroke-width values: group attribute (3 -> 6),
        // line attribute (4 -> 8), inline style (5 -> 10), stylesheet (2 -> 4)
        #expect(count == 4)
    }

    // MARK: - Walker reports zero when nothing to scale

    @Test func reportsZeroWhenNoStrokes() throws {
        let url = try Bundle.test.url(forResource: "stroke-none.svg")
        let svg = try DOM.SVG.parse(fileURL: url)
        let count = StrokeWidthScaler.scale(svg, by: .init(multiplier: 0.5))

        #expect(count == 0)
    }

    // MARK: - Walker recurses through groups

    @Test func scalesNestedGroups() throws {
        let svg = try DOM.SVG.parse(
            xml: #"""
                <?xml version="1.0" encoding="UTF-8"?>
                <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
                    <g stroke="black" stroke-width="10">
                        <g stroke-width="20">
                            <line x1="0" y1="0" x2="100" y2="100" stroke-width="30"/>
                        </g>
                    </g>
                </svg>
                """#
        )

        let count = StrokeWidthScaler.scale(svg, by: .init(multiplier: 0.5))
        #expect(count == 3)
    }

    // MARK: - Walker visits clipPath defs

    @Test func scalesInsideClipPath() throws {
        let svg = try DOM.SVG.parse(
            xml: #"""
                <?xml version="1.0" encoding="UTF-8"?>
                <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
                    <defs>
                        <clipPath id="cp">
                            <rect x="0" y="0" width="50" height="50" stroke-width="6"/>
                        </clipPath>
                    </defs>
                    <rect x="0" y="0" width="100" height="100" stroke="black" stroke-width="4" clip-path="url(#cp)"/>
                </svg>
                """#
        )

        let count = StrokeWidthScaler.scale(svg, by: .init(multiplier: 0.5))
        #expect(count == 2)
    }

    // MARK: - Integration through SFSymbolRenderer

    @Test func rendersVariantsFromStrokeScale() throws {
        let url = try Bundle.test.url(forResource: "chart.svg")
        let renderer = SFSymbolRenderer.makeStrokeScaling(
            ultralight: .init(multiplier: 0.5),
            black: .init(multiplier: 2.0)
        )
        let template = try SFSymbolTemplate.parse(
            try renderer.render(regular: url, ultralight: nil, black: nil)
        )

        #expect(!template.ultralight.contents.paths.isEmpty)
        #expect(!template.regular.contents.paths.isEmpty)
        #expect(!template.black.contents.paths.isEmpty)
    }

    @Test func strokeScaledVariantsDifferFromRegular() throws {
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

        #expect(ultralightPaths.count == regularPaths.count)
        #expect(blackPaths.count == regularPaths.count)

        let ultralightSegments = ultralightPaths.flatMap(\.segments)
        let regularSegments = regularPaths.flatMap(\.segments)
        let blackSegments = blackPaths.flatMap(\.segments)
        #expect(ultralightSegments != regularSegments)
        #expect(blackSegments != regularSegments)
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
