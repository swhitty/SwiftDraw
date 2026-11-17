//
//  LayerTree.TextCharacterTests.swift
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

/// SVG 2 §11.5.2: `x`, `y`, `dx`, `dy` and `rotate` lists position each addressable character.
/// Advances are measured with `Builder.makeAdvance`, which is 0 where CoreText is unavailable.
struct LayerTreeTextCharacterTests {

    struct Run: Equatable {
        var string: String
        var point: LayerTree.Point
        var attributes: LayerTree.TextAttributes
        var transform: [LayerTree.Transform] = []
    }

    private func parse(_ text: String) throws -> DOM.SVG {
        try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="200" height="200" font-family="Helvetica" font-size="20">\(text)</svg>
        """)
    }

    private func characters(_ text: String) throws -> [LayerTree.Builder.TextCharacter] {
        let svg = try parse(text)
        let element = try #require(svg.childElements.first as? DOM.Text)
        let builder = LayerTree.Builder(svg: svg)
        return builder.makeTextCharacters(for: element, with: builder.createState(for: element, inheriting: .init()))
    }

    private func runs(_ text: String) throws -> [Run] {
        runs(in: LayerTree.Builder(svg: try parse(text)).makeLayer())
    }

    private func runs(in layer: LayerTree.Layer, transform: [LayerTree.Transform] = []) -> [Run] {
        layer.contents.flatMap { contents -> [Run] in
            switch contents {
            case .layer(let child):
                return runs(in: child, transform: transform + child.transform)
            case let .text(string, point, attributes):
                return [Run(string: string, point: point, attributes: attributes, transform: transform)]
            default:
                return []
            }
        }
    }

    private func advance(_ string: String, _ run: Run) -> LayerTree.Float {
        LayerTree.Builder.makeAdvance(for: string, with: run.attributes)
    }

    // MARK: - resolving the lists

    @Test
    func valuesIndexTheCharactersOfTheWholeText() throws {
        let chars = try characters(#"<text x="1 2 3" dx="4">A<tspan>BC</tspan>D</text>"#)
        #expect(String(chars.map(\.character)) == "ABCD")
        #expect(chars.map(\.x) == [1, 2, 3, nil])
        #expect(chars.map(\.dx) == [4, 0, 0, 0])
    }

    @Test
    func aDescendantOverridesItsAncestorForItsOwnCharacters() throws {
        let chars = try characters(#"<text dx="0 5 5 5" y="1 2 3 4">A<tspan dx="20" y="9">BC</tspan>D</text>"#)
        #expect(chars.map(\.dx) == [0, 20, 5, 5])
        #expect(chars.map(\.y) == [1, 9, 3, 4])
    }

    @Test
    func rotateRepeatsItsLastValue() throws {
        #expect(try characters(#"<text rotate="10 20">ABCD</text>"#).map(\.rotate) == [10, 20, 20, 20])
        #expect(try characters(#"<text rotate="1 2 3 4 5">A<tspan rotate="9">BC</tspan>DE</text>"#).map(\.rotate) == [1, 9, 9, 4, 5])
        // a span without its own list takes its ancestor's values for its characters
        #expect(try characters(#"<text rotate="1 2 3">A<tspan fill="red">BC</tspan></text>"#).map(\.rotate) == [1, 2, 3])
    }

    @Test
    func anInvalidRotateIsIgnored() throws {
        #expect(try characters(#"<text rotate="5mm">AB</text>"#).map(\.rotate) == [0, 0])
    }

    @Test
    func aHiddenSpanHasNoAddressableCharacters() throws {
        let chars = try characters(#"<text rotate="10 30 50">T<tspan display="none">ex</tspan>t</text>"#)
        #expect(String(chars.map(\.character)) == "Tt")
        #expect(chars.map(\.rotate) == [10, 30])
    }

    @Test
    func aGraphemeClusterIsOneCharacter() throws {
        // и and a combining breve: the second value has no character to position
        let chars = try characters("<text x=\"87\" y=\"100 120\">\u{0438}\u{0306}</text>")
        #expect(chars.count == 1)
        #expect(chars.map(\.y) == [100])
    }

    @Test
    func percentagesResolveAgainstTheViewport() throws {
        #expect(try characters(#"<text x="10% 50%" dy="5%">AB</text>"#).map(\.x) == [20, 100])
    }

    // MARK: - layout

    @Test
    func characterWithoutValuesFlowsWithThePreviousOne() throws {
        let drawn = try runs(#"<text x="10 50 90" y="20">ABCD</text>"#)
        #expect(drawn.map(\.string) == ["A", "B", "CD"])
        try #require(drawn.count == 3)
        #expect(drawn.map(\.point) == [LayerTree.Point(10, 20), LayerTree.Point(50, 20), LayerTree.Point(90, 20)])
    }

    @Test
    func relativeValuesMoveEachCharacter() throws {
        let drawn = try runs(#"<text x="10" y="20" dx="1 2" dy="3 4">ABC</text>"#)
        #expect(drawn.map(\.string) == ["A", "BC"])
        try #require(drawn.count == 2)
        #expect(drawn[0].point == LayerTree.Point(11, 23))
        // B and C stay shaped with A: they end where "ABC" would, 2 further on
        let x = 13 + advance("ABC", drawn[1]) - advance("BC", drawn[1])
        #expect(abs(drawn[1].point.x - x) < 0.001)
        #expect(drawn[1].point.y == 27)
    }

    @Test
    func anAbsoluteYStartsANewChunkWhereThePenIs() throws {
        let drawn = try runs(#"<text x="50" y="100 134">Te<tspan fill="green">xt</tspan></text>"#)
        #expect(drawn.map(\.string) == ["T", "e", "xt"])
        try #require(drawn.count == 3)
        #expect(drawn[0].point == LayerTree.Point(50, 100))
        #expect(drawn[1].point == LayerTree.Point(50 + advance("T", drawn[0]), 134))
        #expect(drawn[2].point.y == 134)
    }

    @Test
    func eachChunkIsAnchoredOnItsOwn() throws {
        let drawn = try runs(#"<text x="100 150" y="20" text-anchor="end">AB</text>"#)
        try #require(drawn.count == 2)
        #expect(abs(drawn[0].point.x - (100 - advance("A", drawn[0]))) < 0.001)
        #expect(abs(drawn[1].point.x - (150 - advance("B", drawn[1]))) < 0.001)
    }

    @Test
    func aChunkIsAnchoredOnItsLeftmostEdge() throws {
        // dx moves B well before A: with start anchoring, B's start is the chunk's start
        let drawn = try runs(#"<text x="100" y="20" dx="0 -60">AB</text>"#)
        try #require(drawn.count == 2)
        #expect(abs(drawn[1].point.x - 100) < 0.001)
        #expect(drawn[0].point.x > drawn[1].point.x)
    }

    @Test
    func rotateTurnsEachGlyphAboutItsOrigin() throws {
        let drawn = try runs(#"<text x="10" y="20" rotate="0 90">AB</text>"#)
        #expect(drawn.map(\.string) == ["A", "B"])
        try #require(drawn.count == 2)
        #expect(drawn[0].transform.isEmpty)
        let p = drawn[1].point
        #expect(drawn[1].transform == [.translate(tx: p.x, ty: p.y),
                                       .rotate(radians: .pi / 2),
                                       .translate(tx: -p.x, ty: -p.y)])
    }

    @Test(arguments: [
        #"<text x="10" y="20">Text</text>"#,
        #"<text x="10" y="20" rotate="0" dx="0">Text</text>"#,
        #"<text x="10 " y="20" dy="0 0 0 0">Text</text>"#,
    ])
    func textWithoutPerCharacterValuesIsOneRun(text: String) throws {
        let drawn = try runs(text)
        #expect(drawn.map(\.string) == ["Text"])
        #expect(drawn.first?.point == LayerTree.Point(10, 20))
    }
}
