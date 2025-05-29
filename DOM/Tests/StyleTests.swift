//
//  StyleTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 27/2/17.
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

final class StyleTests: XCTestCase {
  
  func testStyle() {
    XCTAssertEqual(try XMLParser().parseStyleAttributes("selector: hi;"),
                   ["selector": "hi"])
    XCTAssertEqual(try XMLParser().parseStyleAttributes("selector: hi"),
                   ["selector": "hi"])
    XCTAssertEqual(try XMLParser().parseStyleAttributes("selector: hi "),
                   ["selector": "hi"])
    XCTAssertEqual(try XMLParser().parseStyleAttributes(" trans-form : rotate(4)"),
                   ["trans-form": "rotate(4)"])
    
    XCTAssertThrowsError(try XMLParser().parseStyleAttributes("selector"))
    XCTAssertThrowsError(try XMLParser().parseStyleAttributes(": hmm"))
  }
  
  func testStyles() throws {
    let e = XML.Element(name: "line")
    e.attributes["x"] = "5"
    e.attributes["y"] = "5"
    e.attributes["stroke-color"] = "black"
    e.attributes["style"] = "fill: red; x: 20"
    
    //Style attributes should override any XML.Element attribute
    let att = try XMLParser().parseAttributes(e)
    
    XCTAssertEqual(try att.parseCoordinate("x"), 20.0)
    XCTAssertEqual(try att.parseCoordinate("y"), 5.0)
    XCTAssertEqual(try att.parseColor("stroke-color"), .keyword(.black))
    XCTAssertEqual(try att.parseColor("fill"), .keyword(.red))
  }
}
