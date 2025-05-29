//
//  Parser.XML.PatternTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 26/3/19.
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
@testable import SwiftDrawDOM

private typealias Coordinate = DOM.Coordinate

final class ParserXMLPatternTests: XCTestCase {
  
  func testPattern() throws {
    let pattern = try XMLParser().parsePattern(["id": "p1", "width": "10", "height": "20"])
    
    XCTAssertEqual(pattern.id, "p1")
    XCTAssertEqual(pattern.width, 10)
    XCTAssertEqual(pattern.height, 20)
    
    XCTAssertThrowsError(try XMLParser().parsePattern(["width": "10", "height": "20"]))
    XCTAssertThrowsError(try XMLParser().parsePattern(["id": "p1", "height": "20"]))
    XCTAssertThrowsError(try XMLParser().parsePattern(["id": "p1", "width": "10"]))
  }
  
  func testPatternUnits() throws {
    var node = ["id": "p1", "width": "10", "height": "20"]
    
    var pattern = try XMLParser().parsePattern(node)
    XCTAssertNil(pattern.patternUnits)
    
    node["patternUnits"] = "userSpaceOnUse"
    pattern = try XMLParser().parsePattern(node)
    XCTAssertEqual(pattern.patternUnits, .userSpaceOnUse)
    
    node["patternUnits"] = "objectBoundingBox"
    pattern = try XMLParser().parsePattern(node)
    XCTAssertEqual(pattern.patternUnits, .objectBoundingBox)
    
    node["patternUnits"] = "invalid"
    XCTAssertThrowsError(try XMLParser().parsePattern(node))
  }
  
  func testPatternContentUnits() throws {
    var node = ["id": "p1", "width": "10", "height": "20"]
    
    var pattern = try XMLParser().parsePattern(node)
    XCTAssertNil(pattern.patternContentUnits)
    
    node["patternContentUnits"] = "userSpaceOnUse"
    pattern = try XMLParser().parsePattern(node)
    XCTAssertEqual(pattern.patternContentUnits, .userSpaceOnUse)
    
    node["patternContentUnits"] = "objectBoundingBox"
    pattern = try XMLParser().parsePattern(node)
    XCTAssertEqual(pattern.patternContentUnits, .objectBoundingBox)
    
    node["patternContentUnits"] = "invalid"
    XCTAssertThrowsError(try XMLParser().parsePattern(node))
  }
  
  #if XCODE
  func testParseFile() throws {
    
    let dom = try DOM.SVG.parse(fileNamed: "pattern.svg")
    
    XCTAssertEqual(dom.defs.patterns.count, 3)
    XCTAssertNotNil(dom.defs.patterns.first(where: { $0.id == "checkerboard" }))
    XCTAssertNotNil(dom.defs.patterns.first(where: { $0.id == "pattern1" }))
    XCTAssertNotNil(dom.defs.patterns.first(where: { $0.id == "pattern2" }))
    
    XCTAssertEqual(dom.childElements.count, 3)
    //        XCTAssertNotNil(dom.childElements[0].fill)
    //        XCTAssertNotNil(dom.childElements[1].fill)
    //        XCTAssertNotNil(dom.childElements[2].fill)
  }
  #endif
}
