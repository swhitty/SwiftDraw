//
//  LayerTree.FontSynthesisTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 15/11/26.
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



@testable import SwiftDraw
@testable import SwiftDrawDOM
import Foundation
import Testing

struct LayerTreeFontSynthesisTests {

    private let regular = Data(base64Encoded: "AAAA")!

    private func fonts(faceWeight: String = "400", faceStyle: String = "normal", _ attributes: String) throws -> [LayerTree.TextAttributes.Font] {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <style>
            @font-face { font-family: 'F'; font-weight: \(faceWeight); font-style: \(faceStyle); src: url(data:font/truetype;base64,AAAA) format('truetype'); }
          </style>
          <text font-family="F" \(attributes)>a</text>
        </svg>
        """)
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        func find(_ layer: LayerTree.Layer) -> [LayerTree.TextAttributes.Font]? {
            for contents in layer.contents {
                switch contents {
                case let .text(_, _, attributes): return attributes.font
                case .layer(let child): if let fonts = find(child) { return fonts }
                default: break
                }
            }
            return nil
        }
        return try #require(find(layer))
    }

    @Test(arguments: [
        ("", []),
        (#"font-weight="500""#, []),
        (#"font-weight="599""#, []),
        (#"font-weight="600""#, .bold),
        (#"font-weight="bold""#, .bold),
        (#"font-style="italic""#, .oblique),
        (#"font-style="oblique""#, .oblique),
        (#"font-weight="900" font-style="italic""#, [.bold, .oblique])
    ] as [(String, LayerTree.FontSynthesis)])
    func regularFaceIsSynthesized(attributes: String, synthesis: LayerTree.FontSynthesis) throws {
        let expected: LayerTree.TextAttributes.Font = synthesis.isEmpty ? .truetype(regular) : .synthesized(.truetype(regular), synthesis)
        #expect(try fonts(attributes) == [expected])
    }

    @Test(arguments: [
        // the face's declared descriptors decide, not the font file
        ("700", "normal", #"font-weight="bold""#),
        ("600", "normal", #"font-weight="700""#),
        ("700", "normal", #"font-weight="900""#),
        ("100 900", "normal", #"font-weight="bold""#),
        ("400", "italic", #"font-style="italic""#),
        ("400", "oblique", #"font-style="italic""#),
        ("400", "italic", #"font-style="oblique""#)
    ])
    func faceWithTheWeightOrSlantIsNotSynthesized(faceWeight: String, faceStyle: String, attributes: String) throws {
        #expect(try fonts(faceWeight: faceWeight, faceStyle: faceStyle, attributes) == [.truetype(regular)])
    }

    @Test
    func lighterDeclaredFaceIsSynthesized() throws {
        #expect(try fonts(faceWeight: "500", #"font-weight="700""#) == [.synthesized(.truetype(regular), .bold)])
        #expect(try fonts(faceWeight: "100 500", #"font-weight="700""#) == [.synthesized(.truetype(regular), .bold)])
    }

    @Test
    func systemFamilyIsLeftToTheRenderer() throws {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100"><text font-family="Chalkduster">a</text></svg>
        """)
        let builder = LayerTree.Builder(svg: svg)
        #expect(builder.makeFonts(faceName: "Chalkduster", weight: 700, style: .italic) == [.name("Chalkduster")])
    }

    @Test(arguments: [
        (400, false, 400, false, []),
        (599, false, 400, false, []),
        (600, false, 599, false, .bold),
        (700, false, 600, false, []),
        (700, true, 700, false, .oblique),
        (400, true, 400, true, []),
        (400, false, 700, true, [])
    ] as [(Int, Bool, Int, Bool, LayerTree.FontSynthesis)])
    func synthesisThresholds(weight: Int, isItalic: Bool, faceWeight: Int, faceIsItalic: Bool, synthesis: LayerTree.FontSynthesis) {
        #expect(LayerTree.FontSynthesis(weight: weight, isItalic: isItalic, faceWeight: faceWeight, faceIsItalic: faceIsItalic) == synthesis)
    }
}

#if canImport(CoreText)
import CoreText
import CoreGraphics

struct CGProviderFontSynthesisTests {

    private func synthesis(_ family: String, weight: Int, italic: Bool = false) -> LayerTree.FontSynthesis {
        let font = CGProvider.createFont(for: [.name(family)], size: 12, weight: weight, isItalic: italic)
        return font.synthesis(for: font.font)
    }

    @Test
    func systemFamilyWithOneFaceIsSynthesized() {
        #expect(synthesis("Chalkduster", weight: 400) == [])
        #expect(synthesis("Chalkduster", weight: 700) == .bold)
        #expect(synthesis("Chalkduster", weight: 400, italic: true) == .oblique)
        #expect(synthesis("Chalkduster", weight: 700, italic: true) == [.bold, .oblique])
    }

    @Test
    func heavySystemFaceIsNotEmboldened() {
        // Impact has one face, already heavy
        #expect(synthesis("Impact", weight: 700) == [])
        #expect(synthesis("Impact", weight: 700, italic: true) == .oblique)
    }

    @Test
    func realBoldAndItalicFacesAreNotSynthesized() {
        #expect(synthesis("Helvetica", weight: 700) == [])
        #expect(synthesis("Helvetica", weight: 400, italic: true) == [])
        #expect(synthesis("Helvetica", weight: 700, italic: true) == [])
        #expect(synthesis("Helvetica-Bold", weight: 700) == [])
    }

    @Test
    func fontFaceUsesItsDeclaredSynthesis() throws {
        let data = try Data(contentsOf: Bundle.test.url(forResource: "Roboto-Regular.ttf"))
        let plain = CGProvider.createFont(for: [.truetype(data)], size: 12, weight: 700, isItalic: true)
        #expect(plain.synthesis(for: plain.font) == [])
        let synthesized = CGProvider.createFont(for: [.synthesized(.truetype(data), .bold)], size: 12, weight: 700, isItalic: true)
        #expect(synthesized.synthesis(for: synthesized.font) == .bold)
    }

    // MARK: - outlines

    private func attributes(_ font: LayerTree.TextAttributes.Font, size: Float = 100, anchor: DOM.TextAnchor = .start) throws -> LayerTree.TextAttributes {
        LayerTree.TextAttributes(color: .black, font: [font], size: size, anchor: anchor, baseline: .alphabetic)
    }

    private func roboto() throws -> LayerTree.TextAttributes.Font {
        .truetype(try Data(contentsOf: Bundle.test.url(forResource: "Roboto-Regular.ttf")))
    }

    private func bounds(_ text: String, _ font: LayerTree.TextAttributes.Font, size: Float = 100) throws -> CGRect {
        try #require(CGProvider().createPath(from: text, at: .zero, with: attributes(font, size: size))).boundingBoxOfPath
    }

    @Test(arguments: [24 as Float, 100])
    func boldOutlinesAreWiderByAThirtySixthOfTheSize(size: Float) throws {
        let regular = try bounds("I", roboto(), size: size)
        let bold = try bounds("I", .synthesized(roboto(), .bold), size: size)
        #expect(abs(bold.minX - regular.minX) < 0.001)
        #expect(abs(bold.width - (regular.width + CGFloat(size) / 36)) < 0.001)
        #expect(abs(bold.height - regular.height) < 0.001)
    }

    @Test
    func boldWidensEachAdvance() throws {
        let regular = try bounds("IIII", roboto())
        let bold = try bounds("IIII", .synthesized(roboto(), .bold))
        // each glyph moves by the offset of the glyphs before it, and is itself as much wider
        #expect(abs(bold.width - (regular.width + 4 * 100 / 36)) < 0.001)

        let font = CGProvider.createFont(for: [.synthesized(try roboto(), .bold)], size: 100)
        let width = "IIII".toWidth(font: font.font, synthesis: font.synthesis(for:))
        let regularWidth = "IIII".toWidth(font: font.font)
        #expect(abs(width - (regularWidth + 4 * 100 / 36)) < 0.001)
    }

    @Test
    func boldWidensAnchoredText() throws {
        let regular = LayerTree.Builder.makeOffset(for: "IIII", with: try attributes(roboto(), anchor: .end))
        let bold = LayerTree.Builder.makeOffset(for: "IIII", with: try attributes(.synthesized(roboto(), .bold), anchor: .end))
        #expect(abs((regular.width - bold.width) - 4 * 100 / 36) < 0.001)
    }

    @Test
    func obliqueOutlinesAreSkewedFourteenDegreesAboutTheBaseline() throws {
        let regular = try bounds("I", roboto())
        let oblique = try bounds("I", .synthesized(roboto(), .oblique))
        let tan14 = tan(14 * CGFloat.pi / 180)
        // "I" sits on the baseline: its foot stays, its top leans right by the cap height
        #expect(abs(oblique.minX - regular.minX) < 0.001)
        #expect(abs(oblique.width - (regular.width + tan14 * regular.height)) < 0.001)
        #expect(abs(oblique.height - regular.height) < 0.001)
    }

    @Test
    func unsynthesizedOutlinesAreUnchanged() throws {
        let font = CGProvider.createFont(for: [try roboto()], size: 100)
        let plain = try #require("Ig".toPath(font: font.font))
        let viaProvider = try #require(CGProvider().createPath(from: "Ig", at: .zero, with: attributes(roboto())))
        #expect(plain.boundingBoxOfPath == viaProvider.boundingBoxOfPath)
    }
}
#endif
