//
//  LayerTree.TextRunTests.swift
//  SwiftDraw
//
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

import SwiftDrawDOM
@testable import SwiftDraw
import Testing

/// Every run of a `<text>` is drawn with its own style, one after another on the line.
/// Advances are measured with `Builder.makeAdvance`, which is 0 where CoreText is unavailable.
struct LayerTreeTextRunTests {

    struct Run: Equatable {
        var string: String
        var point: LayerTree.Point
        var attributes: LayerTree.TextAttributes
    }

    private func runs(_ text: String) throws -> [Run] {
        let svg = try DOM.SVG.parse(
            xml: """
                <svg xmlns="http://www.w3.org/2000/svg" width="200" height="200" font-family="Helvetica" font-size="20">\(text)</svg>
                """
        )
        return runs(in: LayerTree.Builder(svg: svg).makeLayer())
    }

    private func runs(in layer: LayerTree.Layer) -> [Run] {
        layer.contents.flatMap { contents -> [Run] in
            switch contents {
            case .layer(let child): runs(in: child)
            case let .text(string, point, attributes): [Run(string: string, point: point, attributes: attributes)]
            default: []
            }
        }
    }

    private func advance(_ run: Run) -> LayerTree.Float {
        LayerTree.Builder.makeAdvance(for: run.string, with: run.attributes)
    }

    @Test
    func everyRunIsDrawnWithItsOwnStyle() throws {
        let drawn = try runs(#"<text x="10" y="50">Te<tspan fill="green" font-size="30">xt</tspan>!</text>"#)
        #expect(drawn.map(\.string) == ["Te", "xt", "!"])
        let green: LayerTree.Color = .rgba(r: 0, g: LayerTree.Float(128) / 255, b: 0, a: 1, space: .srgb)
        #expect(drawn.map(\.attributes.color) == [.black, green, .black])
        #expect(drawn.map(\.attributes.size) == [20, 30, 20])
    }

    @Test
    func runsFollowOneAnother() throws {
        let drawn = try runs(#"<text x="10" y="50">Te<tspan font-weight="bold">xt</tspan>!</text>"#)
        try #require(drawn.count == 3)
        #expect(drawn[0].point == LayerTree.Point(10, 50))
        #expect(drawn[1].point == LayerTree.Point(10 + advance(drawn[0]), 50))
        #expect(drawn[2].point == LayerTree.Point(10 + advance(drawn[0]) + advance(drawn[1]), 50))
    }

    @Test
    func runsInOneFontAreMeasuredTogether() throws {
        // kerning applies across a change of colour: the second run ends where "Text" would
        let drawn = try runs(#"<text x="10" y="50">Te<tspan fill="green">xt</tspan>!</text>"#)
        try #require(drawn.count == 3)
        let joined = Run(string: "Text", point: .zero, attributes: drawn[0].attributes)
        let all = Run(string: "Text!", point: .zero, attributes: drawn[0].attributes)
        #expect(abs(drawn[1].point.x - (10 + advance(joined) - advance(drawn[1]))) < 0.001)
        #expect(abs(drawn[2].point.x - (10 + advance(all) - advance(drawn[2]))) < 0.001)
    }

    @Test
    func anAbsolutePositionStartsANewChunk() throws {
        let drawn = try runs(#"<text x="10" y="20">A<tspan x="50" y="60">B</tspan>C<tspan y="90">D</tspan></text>"#)
        try #require(drawn.count == 4)
        #expect(drawn[0].point == LayerTree.Point(10, 20))
        #expect(drawn[1].point == LayerTree.Point(50, 60))
        #expect(drawn[2].point == LayerTree.Point(50 + advance(drawn[1]), 60))
        #expect(drawn[3].point == LayerTree.Point(50 + advance(drawn[1]) + advance(drawn[2]), 90))
    }

    @Test
    func relativeOffsetsMoveThePen() throws {
        let drawn = try runs(#"<text x="10" y="20" dx="5" dy="1">A<tspan dx="3" dy="2">B</tspan>C</text>"#)
        try #require(drawn.count == 3)
        #expect(drawn[0].point == LayerTree.Point(15, 21))
        #expect(drawn[1].point == LayerTree.Point(18 + advance(drawn[0]), 23))
        #expect(drawn[2].point == LayerTree.Point(18 + advance(drawn[0]) + advance(drawn[1]), 23))
    }

    @Test
    func aSpanWithoutDisplayTakesNoSpace() throws {
        let drawn = try runs(#"<text x="10" y="20">A<tspan display="none" x="90">B</tspan>C</text>"#)
        #expect(drawn.map(\.string) == ["A", "C"])
        try #require(drawn.count == 2)
        #expect(drawn[1].point == LayerTree.Point(10 + advance(drawn[0]), 20))
    }

    @Test
    func aHiddenSpanKeepsItsAdvance() throws {
        let drawn = try runs(#"<text x="10" y="20">A<tspan visibility="hidden">B</tspan>C</text>"#)
        #expect(drawn.map(\.string) == ["A", "C"])
        try #require(drawn.count == 2)
        let hidden = Run(string: "B", point: .zero, attributes: drawn[0].attributes)
        #expect(drawn[1].point == LayerTree.Point(10 + advance(drawn[0]) + advance(hidden), 20))
    }

    @Test(
        arguments: [
            (DOM.TextAnchor.start, LayerTree.Float(0)),
            (DOM.TextAnchor.middle, LayerTree.Float(0.5)),
            (DOM.TextAnchor.end, LayerTree.Float(1)),
        ] as [(DOM.TextAnchor, LayerTree.Float)]
    )
    func anchorAppliesToTheWholeChunk(anchor: DOM.TextAnchor, fraction: LayerTree.Float) throws {
        let drawn = try runs(
            #"<text x="100" y="20" text-anchor="\#(anchor.rawValue)">Te<tspan fill="green">xt</tspan></text>"#
        )
        try #require(drawn.count == 2)
        let width = advance(Run(string: "Text", point: .zero, attributes: drawn[0].attributes))
        let start = 100 - width * fraction
        #expect(abs(drawn[0].point.x - start) < 0.001)
        #expect(abs(drawn[1].point.x - (start + width - advance(drawn[1]))) < 0.001)
    }

    @Test
    func eachChunkIsAnchoredOnItsOwn() throws {
        let drawn = try runs(
            #"<text y="20" text-anchor="end"><tspan x="100">Text</tspan><tspan x="150" y="40">T</tspan></text>"#
        )
        try #require(drawn.count == 2)
        #expect(abs(drawn[0].point.x - (100 - advance(drawn[0]))) < 0.001)
        #expect(abs(drawn[1].point.x - (150 - advance(drawn[1]))) < 0.001)
        #expect(drawn[1].point.y == 40)
    }

    @Test
    func aRunWithoutFontSizeIsNotDrawn() throws {
        let drawn = try runs(#"<text x="10" y="20">A<tspan font-size="0">B</tspan>C</text>"#)
        #expect(drawn.map(\.string) == ["A", "C"])
    }

    @Test
    func aSingleRunIsNotWrappedInALayer() throws {
        let svg = try DOM.SVG.parse(
            xml:
                #"<svg xmlns="http://www.w3.org/2000/svg" width="200" height="200"><text><tspan x="10" y="20">Text</tspan></text></svg>"#
        )
        let text = try #require(svg.childElements.first as? DOM.Text)
        let contents = LayerTree.Builder(svg: svg).makeTextContents(from: text, with: .init())
        guard case .text("Text", LayerTree.Point(10, 20), _)? = contents else {
            Issue.record("expected text contents, got \(String(describing: contents))")
            return
        }
    }

    @Test
    func clipTextIsWhiteWhateverTheSpanFill() throws {
        let svg = try DOM.SVG.parse(
            xml:
                #"<svg xmlns="http://www.w3.org/2000/svg" width="200" height="200"><text>A<tspan fill="red" fill-opacity="0.5">B</tspan></text></svg>"#
        )
        let text = try #require(svg.childElements.first as? DOM.Text)
        let contents = try #require(
            LayerTree.Builder(svg: svg).makeTextContents(from: text, with: .init(), isClip: true)
        )
        let layer = LayerTree.Layer()
        layer.appendContents(contents)
        #expect(runs(in: layer).map(\.attributes.color) == [.white, .white])
    }
}
