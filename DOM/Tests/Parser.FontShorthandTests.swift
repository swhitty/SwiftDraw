//
//  Parser.FontShorthandTests.swift
//  SwiftDraw
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
@testable import SwiftDrawDOM
import Foundation
import Testing

/// The CSS `font` shorthand (CSS Fonts 4 §2.8)
struct ParserFontShorthandTests {

    private typealias Longhands = [String]

    private func longhands(_ value: String) -> Longhands? {
        XMLParser.parseFontShorthand(value)?.map { "\($0.name): \($0.value)" }
    }

    @Test(
        arguments: [
            // matplotlib's SVG output with svg.fonttype='none'
            ("12px 'DejaVu Sans'", ["normal", "normal", "12px", "'DejaVu Sans'"]),
            ("italic bold 20px/1.5 Helvetica, sans-serif", ["italic", "bold", "20px", "Helvetica, sans-serif"]),
            ("bold italic 20px serif", ["italic", "bold", "20px", "serif"]),
            ("small-caps 650 condensed 2em monospace", ["normal", "650", "2em", "monospace"]),
            ("oblique 10deg 12px serif", ["oblique", "normal", "12px", "serif"]),
            ("normal normal 12px serif", ["normal", "normal", "12px", "serif"]),
            ("12px / 2 serif", ["normal", "normal", "12px", "serif"]),
            ("12px/ 2 serif", ["normal", "normal", "12px", "serif"]),
            ("12px /2 serif", ["normal", "normal", "12px", "serif"]),
            ("x-large \"Times New Roman\"", ["normal", "normal", "x-large", "\"Times New Roman\""]),
            ("0 serif", ["normal", "normal", "0", "serif"]),
            // system fonts
            ("menu", ["normal", "normal", "13px", "sans-serif"]),
            ("Caption", ["normal", "normal", "13px", "sans-serif"]),
        ] as [(String, [String])]
    )
    func expandsToLonghands(value: String, expected: [String]) {
        let names = ["font-style", "font-weight", "font-size", "font-family"]
        #expect(longhands(value) == zip(names, expected).map { "\($0): \($1)" })
    }

    @Test(arguments: [
        "", "serif", "12px", "bold serif", "-12px serif", "12px/ serif", "big serif",
        "italic italic 12px serif", "normal normal normal normal normal 12px serif", "inherit",
    ])
    func rejectsInvalidValues(value: String) {
        #expect(longhands(value) == nil)
    }

    private func element(_ body: String) throws -> DOM.GraphicsElement {
        let svg = try DOM.SVG.parse(
            xml: """
                <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">\(body)</svg>
                """
        )
        return try #require(svg.childElements.last)
    }

    @Test
    func styleAttributeSetsTheLonghands() throws {
        let text = try element(#"<text style="font: italic bold 12px 'DejaVu Sans'">a</text>"#)
        #expect(text.style.fontStyle == .italic)
        #expect(text.style.fontWeight == .bold)
        #expect(text.style.fontSize == .length(12))
        #expect(text.style.fontFamily == [.name("DejaVu Sans")])
    }

    // parts left out are reset to their initial values, overriding inherited and earlier ones
    @Test
    func resetsTheOmittedParts() throws {
        let text = try element(#"<text style="font-weight: bold; font: 12px serif">a</text>"#)
        #expect(text.style.fontWeight == .normal)
        #expect(text.style.fontStyle == .normal)
    }

    @Test
    func laterLonghandOverridesTheShorthand() throws {
        let text = try element(#"<text style="font: 12px serif; font-weight: bold">a</text>"#)
        #expect(text.style.fontWeight == .bold)
        #expect(text.style.fontSize == .length(12))
    }

    @Test
    func invalidShorthandIsIgnored() throws {
        let text = try element(#"<text style="font-size: 10px; font: bold serif">a</text>"#)
        #expect(text.style.fontSize == .length(10))
        #expect(text.style.fontWeight == nil)
    }

    @Test
    func stylesheetRuleSetsTheLonghands() throws {
        let text = try element(#"<style>text { font: bold 30px monospace }</style><text>a</text>"#)
        let matched = try #require(text.matchedStyle)
        #expect(matched.attributes.fontWeight == .bold)
        #expect(matched.attributes.fontSize == .length(30))
        #expect(matched.attributes.fontFamily == [.keyword(.monospace)])
    }

    // SVG 2 §6.6: shorthands are not presentation attributes
    @Test
    func isNotAPresentationAttribute() throws {
        let text = try element(#"<text font="bold 30px monospace">a</text>"#)
        #expect(text.attributes.fontSize == nil)
        #expect(text.attributes.fontWeight == nil)
    }

    // em lengths of the element resolve against the shorthand's size
    @Test
    func sizeSetsTheFontSizeOfEmLengths() throws {
        let text = try #require(try element(#"<text style="font: 20px serif" x="2em">a</text>"#) as? DOM.Text)
        #expect(text.x == 40)
    }
}
