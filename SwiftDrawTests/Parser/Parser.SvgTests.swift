//
//  Parser.SvgTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 3/2/17.
//  Copyright 2017 Simon Whitty
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

class SvgTests: XCTestCase {
    
    func testSvg() throws {
        let node = XML.Element(name: "svg", attributes: ["width": "100", "height": "200"])
        let parser = XMLParser()
        
        var parsed = try parser.parseSvg(node)
        let expected = DOM.Svg(width: 100, height: 200)
        XCTAssertEqual(parsed, expected)
        
        expected.viewBox = DOM.Svg.ViewBox(x: 10, y: 20, width: 100, height: 200)
        XCTAssertNotEqual(parsed, expected)
        
        node.attributes["viewBox"] = "10 20 100 200"
        parsed = try parser.parseSvg(node)
        XCTAssertEqual(parsed, expected)
        
        expected.fill = .keyword(.red)
        XCTAssertNotEqual(parsed, expected)
    }
    
    func testViewBox() {
        let parsed = (try? XMLParser().parseViewBox(" 10\t20  300.0  5e2")!)!
        XCTAssertEqual(parsed.x, 10)
        XCTAssertEqual(parsed.y, 20)
        XCTAssertEqual(parsed.width, 300)
        XCTAssertEqual(parsed.height, 500)
        
        XCTAssertNotNil(try! XMLParser().parseViewBox("10 10 10 10"))
        XCTAssertThrowsError(try XMLParser().parseViewBox("10 10 10 10a"))
        XCTAssertThrowsError(try XMLParser().parseViewBox(" 10\t20  300"))
        XCTAssertThrowsError(try XMLParser().parseViewBox("10 10 10 10a"))
    }
    
    func testClipPath() throws {
        
        let node = XML.Element(name: "clipPath", attributes: ["id": "hello"])
        
        var parsed = try XMLParser().parseClipPath(node)
        XCTAssertEqual(parsed.id, "hello")
        
        node.children.append(XML.Element("line", style: "x1:0;y1:0;x2:50;y2:60"))
        node.children.append(XML.Element("circle", style: "cx:0;cy:10;r:20"))

        parsed = try XMLParser().parseClipPath(node)
        XCTAssertEqual(parsed.id, "hello")
        XCTAssertEqual(parsed.childElements.count, 2)
    }

}
