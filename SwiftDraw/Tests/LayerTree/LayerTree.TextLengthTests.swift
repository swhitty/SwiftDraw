//
//  LayerTree.TextLengthTests.swift
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
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// SVG 2 `textLength` and `lengthAdjust`. The fitting is plain arithmetic over the characters'
/// advances, so it is tested with given advances on every platform.
struct LayerTreeTextLengthTests {

    private func parse(_ text: String) throws -> DOM.SVG {
        try DOM.SVG.parse(
            xml: """
                <svg xmlns="http://www.w3.org/2000/svg" width="200" height="200" font-family="Helvetica" font-size="20">\(text)</svg>
                """
        )
    }

    private func characters(
        _ text: String
    ) throws -> ([LayerTree.Builder.TextCharacter], [LayerTree.Builder.TextLength]) {
        let svg = try parse(text)
        let element = try #require(svg.childElements.first as? DOM.Text)
        let builder = LayerTree.Builder(svg: svg)
        let state = builder.createState(for: element, inheriting: .init())
        return (
            builder.makeTextCharacters(for: element, with: state), builder.makeTextLengths(for: element, with: state)
        )
    }

    /// The spacing after each character and the scale of each, with every advance 10
    private func fit(
        _ text: String,
        spacing: LayerTree.Float = 0
    ) throws -> (spacings: [LayerTree.Float], scales: [LayerTree.Float]) {
        let (characters, lengths) = try characters(text)
        return LayerTree.Builder.makeFittedSpacing(
            lengths,
            characters: characters,
            isDrawn: characters.map { _ in true },
            advances: characters.map { _ in 10 },
            spacings: characters.map { _ in spacing }
        )
    }

    // MARK: - parsing

    @Test(
        arguments: [
            (#"textLength="150""#, 150 as DOM.Coordinate?, nil as DOM.LengthAdjust?),
            (#"textLength="1in" lengthAdjust="spacingAndGlyphs""#, 96, .spacingAndGlyphs),
            (#"textLength="50%" lengthAdjust="spacing""#, 100, .spacing),
            (#"textLength="0""#, 0, nil),
            // negative and invalid lengths are ignored
            (#"textLength="-50""#, nil, nil),
            (#"textLength="inherit""#, nil, nil),
            (#"lengthAdjust="squash""#, nil, nil),
        ] as [(String, DOM.Coordinate?, DOM.LengthAdjust?)]
    )
    func textLengthIsParsed(attributes: String, length: DOM.Coordinate?, adjust: DOM.LengthAdjust?) throws {
        let svg = try parse(#"<text \#(attributes)>A<tspan \#(attributes)>B</tspan></text>"#)
        let text = try #require(svg.childElements.first as? DOM.Text)
        #expect(text.textLength == length)
        #expect(text.lengthAdjust == adjust)
        guard case .span(let span) = text.runs[1] else {
            Issue.record("expected a tspan")
            return
        }
        #expect(span.textLength == length)
        #expect(span.lengthAdjust == adjust)
    }

    @Test
    func lengthsAreListedInnermostFirst() throws {
        let (_, lengths) = try characters(#"<text textLength="100">A<tspan textLength="30">BC</tspan>D</text>"#)
        #expect(
            lengths == [
                .init(range: 1..<3, length: 30, adjust: .spacing),
                .init(range: 0..<4, length: 100, adjust: .spacing),
            ]
        )
    }

    // MARK: - fitting

    @Test
    func spacingSpreadsTheDifferenceBetweenTheCharacters() throws {
        // 4 characters of 10 fitted to 70: 30 more over 3 gaps (and after the last, as resvg)
        let fitted = try fit(#"<text textLength="70">ABCD</text>"#)
        #expect(fitted.spacings == [10, 10, 10, 10])
        #expect(fitted.scales == [1, 1, 1, 1])
    }

    @Test
    func spacingCountsTheExistingSpacing() throws {
        // natural: 4 × 10 + 3 × 2 = 46; fitted to 40: 6 less over 3 gaps
        let fitted = try fit(#"<text textLength="40">ABCD</text>"#, spacing: 2)
        #expect(fitted.spacings == [0, 0, 0, 0])
    }

    @Test
    func spacingAndGlyphsScalesTheCharactersAndTheirGaps() throws {
        // natural: 4 × 10 + 3 × 2 = 46; fitted to 92: everything twice as wide
        let fitted = try fit(#"<text textLength="92" lengthAdjust="spacingAndGlyphs">ABCD</text>"#, spacing: 2)
        #expect(fitted.scales == [2, 2, 2, 2])
        // the spacing between the characters doubles; after the last it stays
        #expect(fitted.spacings == [4, 4, 4, 2])
    }

    @Test
    func aDescendantIsFittedAndItsAncestorIsNot() throws {
        let fitted = try fit(
            #"<text textLength="500"><tspan x="20" textLength="50">ABC</tspan><tspan x="20" y="40" textLength="20">DE</tspan></text>"#
        )
        // ABC: 30 fitted to 50; DE: 20 fitted to 20; the text's own length is not applied
        #expect(fitted.spacings == [10, 10, 10, 0, 0])
    }

    @Test
    func aSingleCharacterHasNoSpacingToChange() throws {
        #expect(try fit(#"<text textLength="70">A</text>"#).spacings == [0])
        #expect(try fit(#"<text textLength="20" lengthAdjust="spacingAndGlyphs">A</text>"#).scales == [2])
    }

    @Test
    func anElementSpanningChunksIsNotFitted() throws {
        #expect(try fit(#"<text textLength="100" x="0 50">AB</text>"#).spacings == [0, 0])
    }

    // MARK: - layout

    @Test
    func theTextAfterAFittedSpanMovesOn() throws {
        let svg = try parse(#"<text x="10">A<tspan textLength="80">BC</tspan>D</text>"#)
        let element = try #require(svg.childElements.first as? DOM.Text)
        let builder = LayerTree.Builder(svg: svg)
        let state = builder.createState(for: element, inheriting: builder.createState(for: svg, inheriting: .init()))
        let runs = builder.makeTextChunks(for: element, with: state).flatMap(\.runs)
        try #require(runs.count == 3)
        // the span spans 80 between the start of B and the end of C
        #expect(abs(runs[1].advance - 80) < 0.01)
        #expect(runs[1].glyphs != nil)
        #expect(runs[2].origin.x > runs[1].origin.x + 80)
    }

    #if canImport(CoreText)
    @Test
    func spacingAndGlyphsStretchesTheGlyphRun() throws {
        let layer = LayerTree.Builder(
            svg: try parse(#"<text x="10" y="50" textLength="150" lengthAdjust="spacingAndGlyphs">AB</text>"#)
        ).makeLayer()
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
        let natural = LayerTree.Builder.makeAdvance(for: "AB", with: run.attributes)
        #expect(abs(run.scaleX - 150 / natural) < 0.001)
        let path = try #require(CGProvider.createGlyphPath(from: run))
        #expect(path.boundingBoxOfPath.width > 120)
    }
    #endif
}
