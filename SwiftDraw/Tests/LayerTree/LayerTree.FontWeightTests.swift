//
//  LayerTree.FontWeightTests.swift
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

struct LayerTreeFontWeightTests {

    private func textAttributes(_ body: String, styles: String = "") throws -> [LayerTree.TextAttributes] {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100"><style>\(styles)</style>\(body)</svg>
        """)
        func collect(_ layer: LayerTree.Layer) -> [LayerTree.TextAttributes] {
            layer.contents.flatMap { contents -> [LayerTree.TextAttributes] in
                switch contents {
                case let .text(_, _, attributes): return [attributes]
                case .layer(let child): return collect(child)
                default: return []
                }
            }
        }
        return collect(LayerTree.Builder(svg: svg).makeLayer())
    }

    @Test
    func weightAndStyleAreInheritedAndResolved() throws {
        let attributes = try textAttributes(#"""
        <text>a</text>
        <g font-weight="bold" font-style="italic">
          <text>b</text>
          <text font-weight="bolder">c</text>
          <text font-weight="lighter" font-style="normal">d</text>
          <g font-weight="300"><text font-weight="bolder">e</text></g>
        </g>
        """#)
        #expect(attributes.map(\.weight) == [400, 700, 900, 400, 400])  // lighter of 700 is 400
        #expect(attributes.map(\.isItalic) == [false, true, true, false, true])
    }

    private func face(_ name: String, _ weight: ClosedRange<Int>, _ style: DOM.FontStyle = .normal) -> DOM.FontFace {
        DOM.FontFace(family: "F", src: .local(name), weight: weight, style: style)
    }

    private func match(_ faces: [DOM.FontFace], weight: Int, style: DOM.FontStyle = .normal) -> [String] {
        LayerTree.Builder.matchFontFaces(faces, weight: weight, style: style).map {
            if case .local(let name) = $0.src { return name }
            return "?"
        }
    }

    // CSS Fonts 4 §5.2 step 4
    @Test
    func matchesWeightLikeCSS() {
        let faces = [face("300", 300...300), face("400", 400...400), face("500", 500...500), face("700", 700...700)]
        #expect(match(faces, weight: 400) == ["400"])
        #expect(match(faces, weight: 450) == ["500"])  // 400–500: heavier up to 500 first
        #expect(match(faces, weight: 600) == ["700"])  // above 500: heavier first
        #expect(match(faces, weight: 200) == ["300"])  // below 400: nothing lighter, so heavier
        #expect(match(faces, weight: 900) == ["700"])  // above 500: nothing heavier, so lighter
        #expect(match([face("300", 300...300), face("700", 700...700)], weight: 450) == ["300"])  // then lighter
        #expect(match([face("700", 700...700), face("900", 900...900)], weight: 450) == ["700"])  // then heavier past 500
    }

    @Test
    func variableFaceRangeContainsWeight() {
        #expect(match([face("var", 100...900), face("700", 700...700)], weight: 650) == ["var"])
    }

    @Test
    func matchesStyleBeforeWeight() {
        let faces = [face("regular", 400...400), face("bold", 700...700), face("italic", 400...400, .italic)]
        #expect(match(faces, weight: 700, style: .italic) == ["italic"])
        #expect(match(faces, weight: 400, style: .oblique) == ["italic"])
        #expect(match([face("regular", 400...400)], weight: 400, style: .italic) == ["regular"])
    }

    @Test
    func keepsEveryFaceOfTheBestWeight() {
        // faces split by unicode-range share a weight and all cascade
        let faces = [face("latin", 500...500), face("cyrillic", 500...500), face("regular", 400...400)]
        #expect(match(faces, weight: 500) == ["latin", "cyrillic"])
    }

    @Test
    func fontFaceIsChosenByWeight() throws {
        let styles = """
        @font-face { font-family: 'F'; font-weight: 400; src: url(data:font/truetype;base64,AAAA) format('truetype'); }
        @font-face { font-family: 'F'; font-weight: 700; src: url(data:font/truetype;base64,AAAAAA==) format('truetype'); }
        """
        let attributes = try textAttributes(#"<text font-family="F">a</text><text font-family="F" font-weight="bold">b</text>"#, styles: styles)
        #expect(attributes.map(\.font) == [[.truetype(Data(base64Encoded: "AAAA")!)], [.truetype(Data(base64Encoded: "AAAAAA==")!)]])
    }
}

#if canImport(CoreText)
import CoreText

struct CGProviderFontWeightTests {

    private func postScriptName(_ family: String, weight: Int, italic: Bool = false) -> String {
        let font = CGProvider.createCTFont(for: [.name(family)], size: 12, weight: weight, isItalic: italic)
        return CTFontCopyPostScriptName(font) as String
    }

    @Test
    func systemFamilyFaceFollowsWeightAndStyle() {
        #expect(postScriptName("Helvetica", weight: 400) == "Helvetica")
        #expect(postScriptName("Helvetica", weight: 700) == "Helvetica-Bold")
        #expect(postScriptName("Helvetica", weight: 300) == "Helvetica-Light")
        #expect(postScriptName("Helvetica", weight: 400, italic: true) == "Helvetica-Oblique")
        #expect(postScriptName("Helvetica", weight: 700, italic: true) == "Helvetica-BoldOblique")
    }

    @Test
    func postScriptNameIsUsedAsNamed() {
        #expect(postScriptName("Helvetica-Light", weight: 700) == "Helvetica-Light")
    }

    @Test
    func unknownFamilyFallsBackToTimesWithWeight() {
        #expect(postScriptName("NoSuchFamily", weight: 700) == "Times-Bold")
    }

    @Test
    func coreTextWeightScale() {
        #expect(CGProvider.coreTextWeight(for: 400) == 0)
        #expect(CGProvider.coreTextWeight(for: 700) == 0.4)
        #expect(abs(CGProvider.coreTextWeight(for: 450) - 0.115) < 0.0001)
        #expect(CGProvider.coreTextWeight(for: 1) == -1)
        #expect(CGProvider.coreTextWeight(for: 1000) == 1)
    }
}
#endif
