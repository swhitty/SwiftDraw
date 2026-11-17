//
//  LayerTree.StrokeLengthTests.swift
//  SwiftDraw
//
//  Copyright 2026 WhileLoop Pty Ltd. All rights reserved.
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
import Testing
@testable import SwiftDraw

/// `stroke-width`, `stroke-dasharray` and `stroke-dashoffset` in `em` and `%`
/// (resvg suite: stroke-dasharray/em-units, stroke-dashoffset/em-units, stroke-width/percentage).
struct LayerTreeStrokeLengthTests {

    private func commands(_ body: String) throws -> [RendererCommand<LayerTreeProvider.Types>] {
        let svg = try DOM.SVG.parse(
            xml: """
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200" width="200" height="200">\(body)</svg>
                """
        )
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(), size: .zero, options: .default)
        return generator.renderCommands(for: layer, colorConverter: .default)
    }

    private func lineWidths(_ body: String) throws -> [Float] {
        try commands(body).compactMap {
            if case .setLine(width: let w) = $0 { return w }
            return nil
        }
    }

    private func dashes(_ body: String) throws -> [(phase: Float, lengths: [Float])] {
        try commands(body).compactMap {
            if case let .setLineDash(phase: p, lengths: l) = $0, !l.isEmpty { return (p, l) }
            return nil
        }
    }

    @Test(
        arguments: [
            ("10", 10),
            ("10px", 10),
            // percentages of the viewport diagonal / √2, which is 200 for a square viewBox
            ("10%", 20),
            ("2em", 40),
            ("2ex", 20),
            ("1mm", 96 / 25.4),
        ] as [(String, Float)]
    )
    func strokeWidth(_ value: String, _ expected: Float) throws {
        let widths = try lineWidths(
            #"<g font-size="20"><rect width="10" height="10" fill="none" stroke="black" stroke-width="\#(value)"/></g>"#
        )
        let width = try #require(widths.first)
        #expect(abs(width - expected) < 0.001)
    }

    @Test(arguments: ["-1", "abc", "2px junk", "1em1"])
    func invalidStrokeWidthKeepsTheDefault(_ value: String) throws {
        let widths = try lineWidths(
            #"<rect width="10" height="10" fill="none" stroke="black" stroke-width="\#(value)"/>"#
        )
        #expect(widths.first == 1)
    }

    @Test
    func dashArrayInEm() throws {
        let d = try dashes(
            #"<g font-size="20"><circle r="70" fill="none" stroke="green" stroke-dasharray="2em 1em"/></g>"#
        )
        #expect(d.first?.lengths == [40, 20])
    }

    @Test
    func dashOffsetInEm() throws {
        let d = try dashes(
            #"<circle r="70" fill="none" font-size="20" stroke="green" stroke-dasharray="10 20" stroke-dashoffset="1.5em"/>"#
        )
        #expect(d.first?.phase == 30)
    }

    @Test
    func emIsResolvedWhereItIsDeclared() throws {
        // the inherited value is the computed length, not the `em`
        let d = try dashes(
            #"<g font-size="10" stroke-dasharray="1em" stroke-width="1em"><circle r="70" fill="none" font-size="40" stroke="green"/></g>"#
        )
        #expect(d.first?.lengths == [10, 10])
        #expect(
            try lineWidths(
                #"<g font-size="10" stroke-width="1em"><circle r="70" fill="none" font-size="40" stroke="green"/></g>"#
            ).first == 10
        )
    }

    @Test
    func emInStyleSheet() throws {
        let widths = try lineWidths(
            #"<style>rect { stroke-width: 0.5em }</style><rect width="10" height="10" font-size="30" fill="none" stroke="black"/>"#
        )
        #expect(widths.first == 15)
    }
}
