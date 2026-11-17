//
//  Parser.XML.TextRunTests.swift
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

@testable import SwiftDrawDOM
import Testing

/// The character data and `<tspan>` children of `<text>`, in order, with SVG / CSS white space handling
struct ParserXMLTextRunTests {

    private func parseText(_ text: String) throws -> DOM.Text {
        let svg = try DOM.SVG.parse(
            xml: """
                <svg xmlns="http://www.w3.org/2000/svg" width="200" height="200">\(text)</svg>
                """
        )
        return try #require(svg.childElements.first as? DOM.Text)
    }

    @Test
    func runsKeepDocumentOrderAndTheirOwnAttributes() throws {
        let text = try parseText(
            #"<text>Te<tspan fill="green" font-size="20">xt<tspan font-weight="bold">!</tspan></tspan>?</text>"#
        )
        #expect(text.value == "Text!?")
        #expect(text.runs.count == 3)

        guard case .text("Te") = text.runs[0],
            case .span(let span) = text.runs[1],
            case .text("?") = text.runs[2]
        else {
            Issue.record("unexpected runs \(text.runs)")
            return
        }
        #expect(span.attributes.fill == .color(.keyword(.green)))
        #expect(span.attributes.fontSize == 20)
        #expect(span.runs.count == 2)
        guard case .span(let inner) = span.runs[1] else {
            Issue.record("expected a nested tspan")
            return
        }
        #expect(inner.attributes.fontWeight == .bold)
        #expect(DOM.TextRun.plainText(of: inner.runs) == "!")
    }

    @Test(
        arguments: [
            // collapsed: leading and trailing space of the whole text removed, single spaces between runs
            (#"<text>  Text  <tspan>  Text  </tspan>  Text  </text>"#, "Text Text Text"),
            ("<text>\n  <tspan>\n    <tspan>\n      Text\n    </tspan>\n  </tspan>\n</text>", "Text"),
            ("<text>A\tlot\n of   spaces</text>", "A lot of spaces"),
            // preserved: each newline and tab is a space
            (#"<text xml:space="preserve">Text    Text</text>"#, "Text    Text"),
            ("<text xml:space=\"preserve\"> A\n\tB </text>", " A  B "),
            (#"<text><tspan xml:space="preserve">Text    Text</tspan></text>"#, "Text    Text"),
            (#"<text style="white-space: pre"> Text  Text </text>"#, " Text  Text "),
            (#"<text xml:space="preserve" white-space="normal"> Text  Text </text>"#, "Text Text"),
            // mixed: collapsible space following a preserved space is removed
            ("<text>\n  Text  <tspan xml:space=\"preserve\">  Text  </tspan>  Text\n</text>", "Text   Text  Text"),
            (
                #"<text xml:space="preserve">  Text  <tspan xml:space="default">  Text  </tspan>  Text  </text>"#,
                "  Text  Text   Text  "
            ),
            // a no-break space is not white space
            ("<text>a\u{00A0}\u{00A0}b </text>", "a\u{00A0}\u{00A0}b"),
        ] as [(String, String)]
    )
    func whiteSpaceIsCollapsedOrPreserved(xml: String, expected: String) throws {
        #expect(try parseText(xml).value == expected)
    }

    @Test
    func spanPositionsAreKept() throws {
        let text = try parseText(
            #"<text font-size="10"><tspan x="1 2" y="3" dx="2em" dy="4,5">Te</tspan><tspan font-size="20" dx="1em">xt</tspan></text>"#
        )
        guard case .span(let first) = text.runs[0], case .span(let second) = text.runs[1] else {
            Issue.record("expected two tspans")
            return
        }
        #expect(first.xList == [1, 2])
        #expect(first.yList == [3])
        #expect(first.dxList == [20])
        #expect(first.dyList == [4, 5])
        // `em` is the span's own font-size
        #expect(second.dxList == [20])
        #expect(second.xList.isEmpty)
    }

    @Test
    func textPositionsAreKept() throws {
        let text = try parseText(#"<text x="1" y="2" dx="3 4" dy="5" rotate="10, -20 1.5">Text</text>"#)
        #expect(text.x == 1)
        #expect(text.y == 2)
        #expect(text.dxList == [3, 4])
        #expect(text.dyList == [5])
        #expect(text.rotateList == [10, -20, 1.5])
    }

    @Test(arguments: ["5mm", "10 abc", ",", ""])
    func anInvalidRotateListIsIgnored(rotate: String) throws {
        #expect(try parseText(#"<text rotate="\#(rotate)">Text</text>"#).rotateList.isEmpty)
    }

    @Test
    func spanRotateIsKept() throws {
        let text = try parseText(#"<text>A<tspan rotate="45">B</tspan></text>"#)
        guard case .span(let span) = text.runs[1] else {
            Issue.record("expected a tspan")
            return
        }
        #expect(span.rotateList == [45])
    }

    @Test
    func hiddenSpansAreKept() throws {
        let text = try parseText(#"<text>A<tspan display="none">B</tspan>C</text>"#)
        #expect(text.value == "ABC")
        guard case .span(let span) = text.runs[1] else {
            Issue.record("expected a tspan")
            return
        }
        #expect(span.attributes.display == DOM.DisplayMode.none)
    }

    @Test(arguments: ["<text>  </text>", "<text><tspan> </tspan></text>", "<text><title>T</title></text>"])
    func textWithoutCharactersIsNotDrawn(xml: String) throws {
        let svg = try DOM.SVG.parse(
            xml: """
                <svg xmlns="http://www.w3.org/2000/svg" width="200" height="200">\(xml)</svg>
                """
        )
        #expect(svg.childElements.isEmpty)
    }
}
