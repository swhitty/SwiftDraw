//
//  Parser.XML.TextTests
//  SwiftDraw
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright 2020 Simon Whitty
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


import Foundation
import Testing
@testable import SwiftDrawDOM

struct ParserXMLTextPathTests {

    private func parseText(_ body: String) throws -> DOM.Text? {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="100" height="100">
          \(body)
        </svg>
        """)
        return svg.childElements.compactMap { $0 as? DOM.Text }.first
    }

    private func parseTextPath(_ attributes: String, _ content: String = "abc") throws -> DOM.TextPath {
        try #require(try parseText("<text><textPath \(attributes)>\(content)</textPath></text>")?.textPath)
    }

    @Test(arguments: [
        #"href='#p'"#,
        #"xlink:href='#p'"#
    ])
    func hrefParses(attributes: String) throws {
        let textPath = try parseTextPath(attributes)
        #expect(textPath.href?.fragmentID == "p")
        #expect(textPath.path == nil)
        #expect(textPath.startOffset == nil)
        #expect(textPath.side == nil)
    }

    @Test
    func pathAttributeParses() throws {
        let textPath = try parseTextPath(#"path="M 0 0 L 10 0""#)
        #expect(textPath.href == nil)
        #expect(textPath.path?.segments.count == 2)
    }

    @Test(arguments: [
        ("10", DOM.TextPath.Offset.length(10)),
        ("2.5px", .length(2.5)),
        ("-4", .length(-4)),
        ("1in", .length(96)),
        ("50%", .percentage(50)),
        ("12.5%", .percentage(12.5))
    ])
    func startOffsetParses(value: String, offset: DOM.TextPath.Offset) throws {
        let textPath = try parseTextPath(#"href='#p' startOffset="\#(value)""#)
        #expect(textPath.startOffset == offset)
    }

    @Test
    func invalidStartOffsetIsIgnored() throws {
        let textPath = try parseTextPath(#"href='#p' startOffset="abc""#)
        #expect(textPath.startOffset == nil)
    }

    @Test(arguments: [
        ("left", DOM.TextPath.Side.left),
        ("right", .right)
    ])
    func sideParses(value: String, side: DOM.TextPath.Side) throws {
        #expect(try parseTextPath(#"href='#p' side="\#(value)""#).side == side)
    }

    @Test
    func presentationAttributesParse() throws {
        let textPath = try parseTextPath(#"id="tp" href='#p' fill="red" text-anchor="middle" style="font-size: 12px""#)
        #expect(textPath.id == "tp")
        #expect(textPath.attributes.fill == .color(.keyword(.red)))
        #expect(textPath.attributes.textAnchor == .middle)
        #expect(textPath.style.fontSize == 12)
    }

    @Test
    func textValueIsTheTextOfThePath() throws {
        let text = try #require(try parseText(#"<text x="5" y="6"><textPath href='#p'>on the path</textPath></text>"#))
        #expect(text.value == "on the path")
        #expect(text.textPath != nil)
    }

    @Test
    func emptyTextPathIsNotParsed() throws {
        #expect(try parseText(#"<text><textPath href='#p'>  </textPath></text>"#) == nil)
    }

    @Test
    func tspansKeepTheirOrderAndAttributes() throws {
        let textPath = try parseTextPath(#"href='#p'"#, #"one <tspan fill="red">two <tspan font-weight="bold">three</tspan></tspan> four"#)

        #expect(DOM.TextRun.plainText(of: textPath.runs) == "one two three four")
        #expect(textPath.runs.count == 3)
        guard textPath.runs.count == 3,
              case .text(let first) = textPath.runs[0],
              case .span(let span) = textPath.runs[1],
              case .text(let last) = textPath.runs[2] else {
            Issue.record("unexpected runs")
            return
        }
        #expect(first == "one ")
        #expect(last == " four")
        #expect(span.attributes.fill == .color(.keyword(.red)))
        guard span.runs.count == 2, case .span(let inner) = span.runs[1] else {
            Issue.record("missing nested tspan")
            return
        }
        #expect(inner.attributes.fontWeight == .bold)
        #expect(DOM.TextRun.plainText(of: inner.runs) == "three")
    }

    @Test(arguments: [
        ("  hello  ", "hello"),
        ("\n    hello\n    world\n  ", "hello world"),
        ("a\t\tb", "a b"),
        ("a <tspan> b </tspan> c", "a b c"),
        ("a<tspan> </tspan>b", "a b"),
        ("a <tspan>b </tspan>", "a b")
    ])
    func whitespaceCollapses(content: String, expected: String) throws {
        let textPath = try parseTextPath(#"href='#p'"#, content)
        #expect(DOM.TextRun.plainText(of: textPath.runs) == expected)
    }

    @Test
    func saxParserKeepsTextAndElementsInOrder() throws {
        let root = try XML.SAXParser.parse(data: Data("<a>one<b>two</b>three</a>".utf8))
        let nodes = root.nodes.map { node -> String in
            switch node {
            case .text(let text): return text
            case .element(let element): return "<\(element.name)>"
            }
        }
        #expect(nodes == ["one", "<b>", "three"])
        #expect(root.innerText == "onethree")
        #expect(root.children.map(\.name) == ["b"])
    }
}
