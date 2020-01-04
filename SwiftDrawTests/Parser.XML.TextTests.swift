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

import XCTest
@testable import SwiftDraw

final class ParserXMLTextTests: XCTestCase {
    
    func testParseText() {
        XCTAssertEqual(try XMLParser().parseText([:], value: "Simon").value, "Simon")
        
        var node = ["x": "10", "y": "25"]
        XCTAssertNotNil(try? XMLParser().parseText(node, value: "Simon"))
        
        node["font-family"] = "Futura"
        node["font-size"] = "12.5"
        
        let expected = DOM.Text(x: 10, y: 25, value: "Simon")
        expected.fontFamily = "Futura"
        expected.fontSize = 12.5
        
        let parsed = try? XMLParser().parseText(node, value: "Simon")
        XCTAssertEqual(parsed, expected)
    }

    func testTextNodeParses() throws {
        let el = XML.Element(name: "text", attributes: [:])
        el.innerText = "Simon"

        let node = try XMLParser().parseText(["x": "1", "y": "1"], element: el)
        XCTAssertEqual(node?.value, "Simon")
    }

    func testEmptyTextNodeReturnsNil() {
        let el = XML.Element(name: "text", attributes: [:])
        XCTAssertNil(try XMLParser().parseText(["x": "1", "y": "1"], element: el))
        el.innerText = "    "
        XCTAssertNil(try XMLParser().parseText(["x": "1", "y": "1"], element: el))
    }
}


