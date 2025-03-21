//
//  Parser.SVGTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 3/2/17.
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

final class ParserSVGTests: XCTestCase {

  func testSVG() throws {
    let node = XML.Element(name: "svg", attributes: ["width": "100", "height": "200"])
    let parser = XMLParser()
    
    var parsed = try parser.parseSVG(node)
    let expected = DOM.SVG(width: 100, height: 200)
    XCTAssertEqual(parsed, expected)
    
    expected.viewBox = DOM.SVG.ViewBox(x: 10, y: 20, width: 100, height: 200)
    XCTAssertNotEqual(parsed, expected)
    
    node.attributes["viewBox"] = "10 20 100 200"
    parsed = try parser.parseSVG(node)
    XCTAssertEqual(parsed, expected)
    
    expected.attributes.fill = .color(.keyword(.red))
    XCTAssertNotEqual(parsed, expected)
  }
  
  func testParseSVGInvalidNode() {
    let node = XML.Element(name: "svg2", attributes: ["width": "100", "height": "200"])
    XCTAssertThrowsError(try XMLParser().parseSVG(node))
  }
  
  func testParseSVGMissingHeightInvalidNode() {
    let node = XML.Element(name: "svg", attributes: ["width": "100"])
    XCTAssertThrowsError(try XMLParser().parseSVG(node))
  }
  
  func testParseSVGMissingWidthInvalidNode() {
    let node = XML.Element(name: "svg", attributes: ["height": "100"])
    XCTAssertThrowsError(try XMLParser().parseSVG(node))
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
  
  func testParseDefs() throws {
    let svg = XML.Element(name: "svg")
    let defs = XML.Element(name: "defs")
    let g = XML.Element(name: "g")
    svg.children.append(defs)
    svg.children.append(g)
    
    g.children.append(XML.Element("circle", id: "c2", style: "cx:0;cy:10;r:20"))
    let defs1 = XML.Element(name: "defs")
    g.children.append(defs1)
    defs1.children.append(XML.Element("circle", id: "c3", style: "cx:0;cy:10;r:20"))
    
    defs.children.append(XML.Element("circle", id: "c1", style: "cx:0;cy:10;r:20"))
    svg.children.append(defs1)
    
    let elements = try SwiftDraw.XMLParser().parseSVGDefs(svg).elements
    XCTAssertEqual(elements.count, 2)
  }

    func testUse() throws {
        let svg = try DOM.SVG.parse(xml: #"""
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="64" height="64" version="1.1" xmlns="http://www.w3.org/2000/svg">
            <defs>
                <rect id="a" x="10" y="20" width="30" height="40" />
            </defs>
            <circle id="b" cx="50" cy="60" r="70" />
        </svg>
        """#)

        let rect = try XCTUnwrap(svg.firstGraphicsElement(with: "a") as? DOM.Rect)
        XCTAssertEqual(rect.id, "a")

        let circle = try XCTUnwrap(svg.firstGraphicsElement(with: "b") as? DOM.Circle)
        XCTAssertEqual(circle.id, "b")
    }

    func testMissingNamespce() throws {
        let svg = try DOM.SVG.parse(xml: #"""
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="64" height="64" version="1.1">
            <defs>
                <rect id="a" x="10" y="20" width="30" height="40" />
            </defs>
            <circle id="b" cx="50" cy="60" r="70" />
        </svg>
        """#)

        let rect = try XCTUnwrap(svg.firstGraphicsElement(with: "a") as? DOM.Rect)
        XCTAssertEqual(rect.id, "a")

        let circle = try XCTUnwrap(svg.firstGraphicsElement(with: "b") as? DOM.Circle)
        XCTAssertEqual(circle.id, "b")
    }
}
