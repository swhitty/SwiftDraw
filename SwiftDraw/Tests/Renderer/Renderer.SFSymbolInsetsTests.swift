//
//  Renderer.SFSymbolInsetsTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 16/11/26.
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

// The template's regular small variant: cap height at y 76, baseline at y 146,
// default margins at x 421 and 509, centred on x 465.
struct RendererSFSymbolInsetsTests {

    // A 20×20 box inside a 24×24 canvas.
    static let box = """
        <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">
            <rect x="2" y="2" width="20" height="20" />
        </svg>
        """

    @Test
    func autoFillsCapHeightOnASmallCanvas() throws {
        let symbol = try Self.render(Self.box)

        #expect(symbol.content.isClose(to: .init(x: 430, y: 76, width: 70, height: 70)))
        #expect(symbol.margins.isClose(to: 420, 510))
    }

    @Test
    func autoPadsTheMarginsInTemplateUnits() throws {
        let narrow = try Self.render(
            """
            <svg xmlns="http://www.w3.org/2000/svg" width="240" height="240">
                <rect x="110" y="20" width="20" height="200" />
            </svg>
            """
        )

        #expect(narrow.content.isClose(to: .init(x: 461.5, y: 76, width: 7, height: 70)))
        #expect(narrow.margins.isClose(to: 451.5, 478.5))
    }

    @Test(arguments: [
        // top and bottom insets set the scale: the inset rect's height fills the cap height
        (CommandLine.Insets(top: 0, left: 0, bottom: 0, right: 0), LayerTree.Float(70) / 24),
        (CommandLine.Insets(top: 2, left: 0, bottom: 2, right: 0), LayerTree.Float(70) / 20),
        (CommandLine.Insets(top: 3, left: 0, bottom: 3, right: 0), LayerTree.Float(70) / 18),
        (CommandLine.Insets(top: 8, left: 0, bottom: 8, right: 0), LayerTree.Float(70) / 8),
        // side insets move the margins and leave the scale alone
        (CommandLine.Insets(top: 3, left: -5, bottom: 3, right: -5), LayerTree.Float(70) / 18),
        (CommandLine.Insets(top: 8, left: -8, bottom: 8, right: -8), LayerTree.Float(70) / 8),
        (CommandLine.Insets(top: 8, left: 8, bottom: 8, right: 8), LayerTree.Float(70) / 8),
    ])
    func insetRectMapsToCapHeightAndMargins(insets: CommandLine.Insets, scale: LayerTree.Float) throws {
        let symbol = try Self.render(Self.box, insets: insets)

        let top = LayerTree.Float(insets.top!)
        let left = LayerTree.Float(insets.left!)
        let right = LayerTree.Float(insets.right!)
        let width = (24 - left - right) * scale
        let midX = LayerTree.Float(465)

        #expect(
            symbol.content.isClose(
                to: .init(
                    x: midX - width / 2 + (2 - left) * scale,
                    y: 76 + (2 - top) * scale,
                    width: 20 * scale,
                    height: 20 * scale
                )
            )
        )
        #expect(symbol.margins.isClose(to: midX - width / 2, midX + width / 2))
    }

    @Test
    func overhangsTheCapHeightAndBaselineWithSpaceBeside() throws {
        // #141: stick out past the cap height and baseline, with space at the sides
        let symbol = try Self.render(Self.box, insets: .init(top: 3, left: -5, bottom: 3, right: -5))

        #expect(symbol.content.minY < 76)
        #expect(symbol.content.maxY > 146)
        #expect(symbol.content.minX - symbol.margins.left > 20)
        #expect(symbol.margins.right - symbol.content.maxX > 20)
    }

    @Test
    func partialInsetsPadAutoSidesAtTheInsetScale() throws {
        let symbol = try Self.render(Self.box, insets: .init(top: 3, bottom: 3))

        let scale = LayerTree.Float(70) / 18
        #expect(
            symbol.content.isClose(to: .init(x: 465 - 10 * scale, y: 76 - scale, width: 20 * scale, height: 20 * scale))
        )
        #expect(symbol.margins.isClose(to: symbol.content.minX - 10, symbol.content.maxX + 10))
    }

    @Test
    func autoInsetsRenderTheSameWhenPassedExplicitly() throws {
        // auto alignment prints --insets 2,-0.8571,2,-0.8571 for the box
        let padding = 10.0 * 20 / 70
        let auto = try Self.render(Self.box)
        let explicit = try Self.render(
            Self.box,
            insets: .init(top: 2, left: 2 - padding, bottom: 2, right: 2 - padding)
        )

        #expect(explicit.content.isClose(to: auto.content))
        #expect(explicit.margins.isClose(to: auto.margins.left, auto.margins.right))
    }

    @Test
    func invalidInsetsThrow() {
        #expect(throws: (any Error).self) {
            try Self.render(Self.box, insets: .init(top: 12, left: 0, bottom: 12, right: 0))
        }
        #expect(throws: (any Error).self) {
            try Self.render(Self.box, insets: .init(top: 0, left: 12, bottom: 0, right: 12))
        }
    }

    @Test(arguments: [
        // --legacy keeps the scale capped by the default margin width
        (CommandLine.Insets(top: 8, left: 0, bottom: 8, right: 0), LayerTree.Float(88) / 24),
        (CommandLine.Insets(top: 8, left: -8, bottom: 8, right: -8), LayerTree.Float(88) / 40),
    ])
    func legacyInsetsAreUnchanged(insets: CommandLine.Insets, scale: LayerTree.Float) throws {
        let symbol = try Self.render(Self.box, insets: insets, isLegacy: true)

        #expect(abs(symbol.content.width - 20 * scale) < 0.01)
        #expect(symbol.margins.isClose(to: 411, 519))
    }
}

private extension RendererSFSymbolInsetsTests {

    struct Symbol {
        var content: LayerTree.Rect
        var margins: Margins
    }

    struct Margins {
        var left: LayerTree.Float
        var right: LayerTree.Float

        func isClose(to left: LayerTree.Float, _ right: LayerTree.Float) -> Bool {
            abs(self.left - left) < 0.01 && abs(self.right - right) < 0.01
        }
    }

    static func render(_ source: String, insets: CommandLine.Insets = .init(), isLegacy: Bool = false) throws -> Symbol
    {
        let renderer = SFSymbolRenderer(
            size: .small,
            options: [],
            insets: insets,
            insetsUltralight: insets,
            insetsBlack: insets,
            precision: 6,
            isLegacyInsets: isLegacy
        )
        let output = try renderer.render(default: DOM.SVG.parse(data: Data(source.utf8)), ultralight: nil, black: nil)
        let regular = try SFSymbolTemplate.parse(output).regular
        #expect(regular.contents.paths.count == 1)
        let path = try #require(regular.contents.paths.first)
        return try Symbol(
            content: LayerTree.Builder.createPath(from: path).bounds,
            margins: Margins(left: regular.bounds.minX, right: regular.bounds.maxX)
        )
    }
}

private extension LayerTree.Rect {

    func isClose(to other: LayerTree.Rect, within tolerance: LayerTree.Float = 0.01) -> Bool {
        abs(minX - other.minX) < tolerance && abs(minY - other.minY) < tolerance && abs(width - other.width) < tolerance
            && abs(height - other.height) < tolerance
    }
}
