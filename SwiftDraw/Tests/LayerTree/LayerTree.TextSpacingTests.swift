//
//  LayerTree.TextSpacingTests.swift
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

import Foundation
import SwiftDrawDOM
@testable import SwiftDraw
import Testing

/// CSS Text 3 §8 `letter-spacing` and `word-spacing`, and the shaping they are applied to.
/// Advances come from `Builder.makeShapedText`, which shapes nothing where CoreText is unavailable,
/// so there only the spacing moves the characters.
struct LayerTreeTextSpacingTests {

    private func parse(_ text: String) throws -> DOM.SVG {
        try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="200" height="200" font-family="Helvetica" font-size="20">\(text)</svg>
        """)
    }

    private func placements(_ text: String) throws -> [LayerTree.Builder.TextRunPlacement] {
        let svg = try parse(text)
        let element = try #require(svg.childElements.first as? DOM.Text)
        let builder = LayerTree.Builder(svg: svg)
        let state = builder.createState(for: element, inheriting: builder.createState(for: svg, inheriting: .init()))
        return builder.makeTextChunks(for: element, with: state).flatMap { chunk in
            chunk.runs.map { run in
                var run = run
                let extent = run.horizontalExtent
                run.extent = extent.lowerBound + chunk.shift...extent.upperBound + chunk.shift
                return run
            }
        }
    }

    private func width(_ text: String) throws -> LayerTree.Float {
        let extents = try placements(text).map(\.horizontalExtent)
        return (extents.map(\.upperBound).max() ?? 0) - (extents.map(\.lowerBound).min() ?? 0)
    }

    // MARK: - parsing

    @Test(arguments: [
        ("5", DOM.DashLength.absolute(5)),
        ("-3", .absolute(-3)),
        ("normal", .absolute(0)),
        ("0.5em", .em(0.5)),
        ("1in", .absolute(96)),
        // a percentage is of the viewport width
        ("5%", .absolute(10)),
    ] as [(String, DOM.DashLength)])
    func spacingIsParsed(value: String, expected: DOM.DashLength) throws {
        let text = try #require(try parse(#"<text letter-spacing="\#(value)" word-spacing="\#(value)">A</text>"#).childElements.first)
        #expect(text.attributes.letterSpacing == expected)
        #expect(text.attributes.wordSpacing == expected)
    }

    @Test(arguments: ["abc", "5 5", ""])
    func invalidSpacingIsIgnored(value: String) throws {
        let text = try #require(try parse(#"<text letter-spacing="\#(value)">A</text>"#).childElements.first)
        #expect(text.attributes.letterSpacing == nil)
    }

    // MARK: - layout

    @Test
    func letterSpacingGoesBetweenEachCharacter() throws {
        let natural = try width(#"<text x="10">ABC</text>"#)
        // two gaps: no spacing after the last character
        #expect(abs(try width(#"<text x="10" letter-spacing="5">ABC</text>"#) - (natural + 10)) < 0.01)
        // negative spacing draws the characters closer, or (where nothing is shaped) back to front
        #expect(abs(try width(#"<text x="10" letter-spacing="-2">ABC</text>"#) - abs(natural - 4)) < 0.01)
        // em is of the font-size
        #expect(abs(try width(#"<text x="10" letter-spacing="0.25em">ABC</text>"#) - (natural + 10)) < 0.01)
    }

    @Test
    func wordSpacingGoesAfterEachSpace() throws {
        let natural = try width(#"<text x="10">A B C</text>"#)
        #expect(abs(try width(#"<text x="10" word-spacing="7">A B C</text>"#) - (natural + 14)) < 0.01)
        #expect(abs(try width(#"<text x="10" word-spacing="7" letter-spacing="1">A B C</text>"#) - (natural + 14 + 4)) < 0.01)
    }

    @Test
    func spacingIsInheritedAndOverridden() throws {
        let natural = try width(#"<text x="10">ABC<tspan>DE</tspan></text>"#)
        #expect(abs(try width(#"<text x="10" letter-spacing="1">ABC<tspan>DE</tspan></text>"#) - (natural + 4)) < 0.01)
        // the tspan's own spacing follows each of its characters
        #expect(abs(try width(#"<text x="10" letter-spacing="1">ABC<tspan letter-spacing="10">DE</tspan></text>"#) - (natural + 3 + 10)) < 0.01)
    }

    @Test
    func trailingSpacingIsNotAnchored() throws {
        let placed = try placements(#"<text x="100" text-anchor="end" letter-spacing="10">AB</text>"#)
        let extent = try #require(placed.first?.horizontalExtent)
        #expect(abs(extent.upperBound - 100) < 0.01)
    }

    @Test
    func textWithoutSpacingStaysText() throws {
        for text in [#"<text x="10">ABC</text>"#, #"<text x="10" letter-spacing="normal" word-spacing="0">A B</text>"#] {
            #expect(try placements(text).allSatisfy { $0.glyphs == nil })
        }
        // spacing after the only character of a run changes nothing within it
        #expect(try placements(#"<text x="10" letter-spacing="5">A<tspan fill="red">B</tspan></text>"#).allSatisfy { $0.glyphs == nil })
    }

    @Test
    func spacedTextIsPlacedGlyphByGlyph() throws {
        let placed = try placements(#"<text x="10" letter-spacing="5">ABC</text>"#)
        #expect(placed.count == 1)
        #expect(placed.first?.glyphs != nil)
    }

    @Test
    func cursiveScriptsAreNotLetterSpaced() throws {
        // Arabic letters join: neither they nor the spaces between them are spaced
        let placed = try placements("<text x=\"10\" letter-spacing=\"10\">\u{0628}\u{0639}\u{0636} \u{0627}\u{0644}\u{0646}\u{0635}</text>")
        #expect(placed.allSatisfy { $0.glyphs == nil })
        #expect(LayerTree.Builder.isCursive("\u{0628}"))
        #expect(!LayerTree.Builder.isCursive("A"))
    }

    // MARK: - shaping

    @Test
    func glyphsAreAssignedToTheirCharacters() {
        typealias Glyph = LayerTree.Builder.ShapedGlyph
        // "fié" with an "fi" ligature, and é as e and a combining acute (two UTF-16 units, one character)
        let runs = [
            LayerTree.Builder.ShapedRun(fontName: "Main", glyphs: [
                Glyph(glyph: 1, x: 0, advance: 10, index: 0),
                Glyph(glyph: 2, x: 10, advance: 6, index: 2),
            ]),
            LayerTree.Builder.ShapedRun(fontName: "Fallback", glyphs: [
                Glyph(glyph: 3, x: 11, y: 4, advance: 0, index: 3),
            ]),
        ]
        let characters = LayerTree.Builder.makeShapedCharacters(runs, for: "fie\u{0301}")
        #expect(characters.count == 3)
        // the ligature is the first character's; the second has no glyph and no advance
        #expect(characters[0] == .init(advance: 10, glyphs: [.init(fontName: "Main", glyph: 1, offset: .zero)]))
        #expect(characters[1] == .init(advance: 0, glyphs: []))
        // the mark sits above, about its character's origin (y down)
        #expect(characters[2] == .init(advance: 6, glyphs: [
            .init(fontName: "Main", glyph: 2, offset: .zero),
            .init(fontName: "Fallback", glyph: 3, offset: LayerTree.Point(1, -4)),
        ]))
    }

    @Test
    func charactersMergedByJoiningKeepTheirOwnGlyphs() {
        // и and a combining breve from separate text nodes: joined they are one grapheme
        let characters: [Character] = ["\u{0438}", "\u{0306}"]
        #expect(String(characters).count == 1)
        let runs = [LayerTree.Builder.ShapedRun(fontName: "Main", glyphs: [
            .init(glyph: 1, x: 0, advance: 10, index: 0),
            .init(glyph: 2, x: 2, y: 5, advance: 0, index: 1),
        ])]
        let shaped = LayerTree.Builder.makeShapedCharacters(runs, for: characters)
        #expect(shaped.count == 2)
        #expect(shaped.map(\.advance) == [10, 0])
        #expect(shaped.map(\.glyphs.count) == [1, 1])
        // the breve stays over the и: back from where the и ends, and raised
        #expect(shaped[1].glyphs.first?.offset == LayerTree.Point(-8, -5))
    }

    @Test
    func wordSeparators() {
        #expect(LayerTree.Builder.isWordSeparator(" "))
        #expect(LayerTree.Builder.isWordSeparator("\u{00A0}"))
        #expect(!LayerTree.Builder.isWordSeparator("\t"))
        #expect(!LayerTree.Builder.isWordSeparator("A"))
    }

#if canImport(CoreText)
    @Test
    func shapingFollowsTheFontsAdvances() throws {
        let attributes = LayerTree.TextAttributes(color: .black, font: [.name("Times")], size: 40, anchor: .start, baseline: .auto)
        let runs = LayerTree.Builder.makeShapedText("AVA", with: attributes)
        let glyphs = runs.flatMap(\.glyphs)
        #expect(glyphs.count == 3)
        #expect(glyphs.map(\.index) == [0, 1, 2])
        let total = glyphs.reduce(0) { $0 + $1.advance }
        #expect(abs(total - LayerTree.Builder.makeAdvance(for: "AVA", with: attributes)) < 0.01)
    }

    @Test
    func letterSpacingTurnsOptionalLigaturesOff() throws {
        let attributes = LayerTree.TextAttributes(color: .black, font: [.name("Times")], size: 40, anchor: .start, baseline: .auto)
        let ligated = LayerTree.Builder.makeShapedText("ffi", with: attributes).flatMap(\.glyphs)
        let separate = LayerTree.Builder.makeShapedText("ffi", with: attributes, ligatures: false).flatMap(\.glyphs)
        #expect(separate.count == 3)
        #expect(ligated.count < separate.count)
    }

    @Test
    func spacedGlyphsAreDrawnAsAGlyphRun() throws {
        let layer = LayerTree.Builder(svg: try parse(#"<text x="10" y="50" letter-spacing="5" fill="green">ABC</text>"#)).makeLayer()
        func runs(_ layer: LayerTree.Layer) -> [LayerTree.GlyphRun] {
            layer.contents.flatMap { contents -> [LayerTree.GlyphRun] in
                switch contents {
                case .glyphs(let run): [run]
                case .layer(let child): runs(child)
                default: []
                }
            }
        }
        let run = try #require(runs(layer).first)
        #expect(run.glyphs.count == 3)
        #expect(run.positions.first == LayerTree.Point(10, 50))
        let a = LayerTree.Builder.makeAdvance(for: "A", with: run.attributes)
        #expect(abs(run.positions[1].x - (10 + a + 5)) < 0.5)
        #expect(run.attributes.color == .rgba(r: 0, g: LayerTree.Float(128) / 255, b: 0, a: 1, space: .srgb))
    }
#endif
}
