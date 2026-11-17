//
//  Parser.FontWeightTests.swift
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

@testable import SwiftDrawDOM
import Foundation
import Testing

struct ParserFontWeightTests {

    @Test(arguments: [
        ("normal", DOM.FontWeight.normal), ("bold", .bold), ("BOLD", .bold), ("bolder", .bolder),
        ("lighter", .lighter), ("100", .number(100)), (" 650 ", .number(650)), ("1", .number(1)),
        ("1000", .number(1000)),
    ])
    func parsesFontWeight(text: String, weight: DOM.FontWeight) {
        #expect(DOM.FontWeight(text) == weight)
    }

    @Test(arguments: ["", "heavy", "0", "1001", "-100", "bold italic"])
    func rejectsInvalidFontWeight(text: String) {
        #expect(DOM.FontWeight(text) == nil)
    }

    // CSS Fonts 4 §2.2: bolder and lighter relative to the inherited weight
    @Test(arguments: [
        (50, 400, 50), (100, 400, 100), (300, 400, 100), (400, 700, 100), (500, 700, 100),
        (600, 900, 400), (700, 900, 400), (800, 900, 700), (900, 900, 700), (950, 950, 700),
    ])
    func resolvesRelativeWeights(parent: Int, bolder: Int, lighter: Int) {
        #expect(DOM.FontWeight.bolder.resolved(inheriting: parent) == bolder)
        #expect(DOM.FontWeight.lighter.resolved(inheriting: parent) == lighter)
    }

    @Test
    func resolvesAbsoluteWeights() {
        #expect(DOM.FontWeight.normal.resolved(inheriting: 900) == 400)
        #expect(DOM.FontWeight.bold.resolved(inheriting: 100) == 700)
        #expect(DOM.FontWeight.number(350).resolved(inheriting: 700) == 350)
    }

    @Test(arguments: [
        ("normal", DOM.FontStyle.normal), ("italic", .italic), ("Oblique", .oblique), ("oblique 10deg", .oblique),
    ])
    func parsesFontStyle(text: String, style: DOM.FontStyle) {
        #expect(DOM.FontStyle(text) == style)
    }

    @Test
    func rejectsInvalidFontStyle() {
        #expect(DOM.FontStyle("slanted") == nil)
        #expect(DOM.FontStyle("") == nil)
    }

    @Test
    func presentationAttributesFromAttributeAndStyle() throws {
        let svg = try DOM.SVG.parse(
            xml: #"""
                <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">
                  <text font-weight="bold" font-style="italic">a</text>
                  <text style="font-weight: 300; font-style: oblique">b</text>
                  <text font-weight="heavy" font-style="slanted">c</text>
                </svg>
                """#
        )
        let attributes = svg.childElements.map { DOM.presentationAttributes(for: $0, styles: svg.styles) }
        #expect(attributes.map(\.fontWeight) == [.bold, .number(300), nil])
        #expect(attributes.map(\.fontStyle) == [.italic, .oblique, nil])
    }

    @Test(arguments: [
        ("400", 400...400), ("bold", 700...700), ("normal", 400...400), ("100 900", 100...900), ("700 300", 300...700),
    ])
    func parsesFontFaceWeight(text: String, range: ClosedRange<Int>) {
        #expect(XMLParser.parseFontFaceWeight(text) == range)
    }

    @Test(arguments: ["bolder", "lighter", "heavy", "100 200 300", ""])
    func rejectsInvalidFontFaceWeight(text: String) {
        #expect(XMLParser.parseFontFaceWeight(text) == nil)
    }

    @Test
    func fontFaceDescriptors() throws {
        let svg = try DOM.SVG.parse(
            xml: #"""
                <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><style>
                  @font-face { font-family: 'A'; src: url(a-regular.woff2) format('woff2'); }
                  @font-face { font-family: 'A'; font-weight: bold; font-style: italic; src: url(a-bolditalic.woff2) format('woff2'); }
                  @font-face { font-family: 'A'; font-weight: 100 900; src: url(a-variable.woff2) format('woff2'); }
                </style></svg>
                """#
        )
        let faces = svg.styles.flatMap(\.fonts)
        #expect(faces.map(\.weight) == [400...400, 700...700, 100...900])
        #expect(faces.map(\.style) == [.normal, .italic, .normal])
    }
}
