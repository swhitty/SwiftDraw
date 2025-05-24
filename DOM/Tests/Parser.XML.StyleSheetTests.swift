//
//  Parser.XML.StyleSheetTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 18/8/22.
//  Copyright 2022 Simon Whitty
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

import XCTest
@testable import DOM

final class ParserXMLStyleSheetTests: XCTestCase {

    func testParsesStyleSheetsSelectors() throws {
        let dom = try DOM.SVG.parse(fileNamed: "stylesheet.svg", in: .test)

        XCTAssertEqual(
            Set(dom.styles.flatMap(\.attributes.keys)),
            [.class("s"),
             .class("b"),
             .element("rect"),
             .class("o"),
             .class("g"),
             .element("circle"),
             .element("g"),
             .id("a")]
        )
    }

    func testParsesSelectors() throws {
        let entries = try XMLParser.parseEntries(
            """
             .s {
                stroke: darkgray;
                stroke-width: 5 /* asd */;
                fill-opacity: 0.3
            }

            /* comment */
            /* another */

             .b {
                fill: blue;
            }

            rect {
                fill: pink;
            }
            /* comment */
            """
        )

        XCTAssertEqual(
            entries,
            [.class("s"): ["stroke": "darkgray", "stroke-width": "5", "fill-opacity": "0.3"],
             .class("b"): ["fill": "blue"],
             .element("rect"): ["fill": "pink"]]
        )
    }

    func testParsesStyleSheet() throws {
        let sheet = try XMLParser().parseStyleSheetElement(
            """
             .s {
                stroke: darkgray;
                stroke-width: 5 /* asd */;
                fill-opacity: 30%
            }

            /* comment */
            /* another */

             .b {
                fill: blue;
            }

            rect {
                fill: pink;
            }
            /* comment */
            """
        ).attributes

        XCTAssertEqual(sheet[.class("s")]?.stroke, .color(.keyword(.darkgray)))
        XCTAssertEqual(sheet[.class("s")]?.strokeWidth, 5)
        XCTAssertEqual(sheet[.class("s")]?.fillOpacity, 0.3)
        XCTAssertEqual(sheet[.class("b")]?.fill, .color(.keyword(.blue)))
        XCTAssertEqual(sheet[.element("rect")]?.fill, .color(.keyword(.pink)))
    }
}
