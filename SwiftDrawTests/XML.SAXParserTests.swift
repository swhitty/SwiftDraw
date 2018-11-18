//
//  XML.SAXParserTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 16/11/18.
//  Copyright 2018 Simon Whitty
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

final class SAXParserTests: XCTestCase {

    func testMissingFileThrows() {
        let missingFile = URL(fileURLWithPath: "/user/tmp/SWIFTDraw/SwiftDraw/missing")
        //let missingFile = URL(string: "http://www.test.com")!
        XCTAssertThrowsError(try XML.SAXParser.parse(contentsOf: missingFile))
    }

    func testInvalidXMLThrows() {
        let xml = "hi"
        XCTAssertThrowsError(try XML.SAXParser.parse(data: xml.data(using: .utf8)!))
    }

    func testValidSVGParses() throws {
        let xml = """
<svg xmlns="http://www.w3.org/2000/svg">
</svg>
"""

        let root = try XML.SAXParser.parse(data: xml.data(using: .utf8)!)
        XCTAssertEqual(root.name, "svg")
        XCTAssertTrue(root.children.isEmpty)
    }

    func testUnexpectedElementsThrows() throws {
        let xml = """
<svg xmlns="http://www.w3.org/2000/svg">
    </b>
</svg>
"""
        XCTAssertThrowsError(try XML.SAXParser.parse(data: xml.data(using: .utf8)!))
    }

    func testUnexpectedNamespaceElementsSkipped() throws {
        let xml = """
<svg xmlns="http://www.w3.org/2000/svg">
<a xmlns="http://another.com" />
<b />
</svg>
"""
        let root = try XML.SAXParser.parse(data: xml.data(using: .utf8)!)
        XCTAssertEqual(root.name, "svg")
        XCTAssertEqual(root.children.count, 1)
        XCTAssertEqual(root.children[0].name, "b")
    }
}
