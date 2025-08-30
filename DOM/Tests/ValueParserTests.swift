//
//  ValueParserTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 6/3/17.
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

final class ValueParserTests: XCTestCase {
  
  var parser = XMLParser.ValueParser()
  
  func testFloat() {
    XCTAssertEqual(try parser.parseFloat("10"), 10)
    XCTAssertEqual(try parser.parseFloat("10.0"), 10.0)
    
    XCTAssertThrowsError(try parser.parseFloat(""))
    //XCTAssertThrowsError(try parser.parseFloat("10a"))
  }
  
  func testFloats() {
    XCTAssertEqual(try parser.parseFloats("10 20 30.5"), [10, 20, 30.5])
    XCTAssertEqual(try parser.parseFloats("10.0"), [10.0])
    XCTAssertEqual(try parser.parseFloats("5 10 1 5"), [5, 10, 1, 5])
    XCTAssertEqual(try parser.parseFloats(" 1, 2.5, 3.5 "), [1, 2.5, 3.5])
    XCTAssertEqual(try parser.parseFloats(" "), [])
    XCTAssertEqual(try parser.parseFloats(""), [])
    
    //XCTAssertThrowsError(try parser.parseFloats(""))
    //XCTAssertThrowsError(try parser.parseFloat("10a"))
  }
  
  func testPercentage() {
    XCTAssertEqual(try parser.parsePercentage("0"), 0)
    XCTAssertEqual(try parser.parsePercentage("1"), 1)
    XCTAssertEqual(try parser.parsePercentage("0.45"), 0.45)
    XCTAssertEqual(try parser.parsePercentage("0.0%"), 0)
    XCTAssertEqual(try parser.parsePercentage("100%"), 1)
    XCTAssertEqual(try parser.parsePercentage("55%"), 0.55)
    XCTAssertEqual(try parser.parsePercentage("10.25%"), 0.1025)
    
    XCTAssertThrowsError(try parser.parsePercentage("100"))
    XCTAssertThrowsError(try parser.parsePercentage("asd"))
    XCTAssertThrowsError(try parser.parsePercentage(" "))
    //XCTAssertThrowsError(try parser.parseFloat("10a"))
  }
  
  func testCoordinate() {
    XCTAssertEqual(try parser.parseCoordinate("0"), 0)
    XCTAssertEqual(try parser.parseCoordinate("0.0"), 0)
    XCTAssertEqual(try parser.parseCoordinate("100"), 100)
    XCTAssertEqual(try parser.parseCoordinate("25.0"), 25.0)
    XCTAssertEqual(try parser.parseCoordinate("-25.0"), -25.0)
    
    XCTAssertThrowsError(try parser.parseCoordinate("asd"))
    XCTAssertThrowsError(try parser.parseCoordinate(" "))
  }
  
  func testLength() {
    XCTAssertEqual(try parser.parseLength("0"), 0)
    XCTAssertEqual(try parser.parseLength("100"), 100)
    XCTAssertEqual(try parser.parseLength("25"), 25)
    XCTAssertEqual(try parser.parseLength("1.3"), 1) //should error?
    
    XCTAssertThrowsError(try parser.parseLength("asd"))
    XCTAssertThrowsError(try parser.parseLength(" "))
    XCTAssertThrowsError(try parser.parseLength("-25"))
  }
  
  func testBool() {
    XCTAssertEqual(try parser.parseBool("false"), false)
    XCTAssertEqual(try parser.parseBool("FALSE"), false)
    XCTAssertEqual(try parser.parseBool("true"), true)
    XCTAssertEqual(try parser.parseBool("TRUE"), true)
    XCTAssertEqual(try parser.parseBool("1"), true)
    XCTAssertEqual(try parser.parseBool("0"), false)
    
    XCTAssertThrowsError(try parser.parseBool("asd"))
    XCTAssertThrowsError(try parser.parseBool("yes"))
  }
  
  func testFill() {
    XCTAssertEqual(try parser.parseFill("none"), .color(.none))
    XCTAssertEqual(try parser.parseFill("black"), .color(.keyword(.black)))
    XCTAssertEqual(try parser.parseFill("red"), .color(.keyword(.red)))
    
    XCTAssertEqual(try parser.parseFill("rgb(10,20,30)"), .color(.rgbi(10, 20, 30, 1.0)))
    XCTAssertEqual(try parser.parseFill("rgb(10%,20%,100%)"), .color(.rgbf(0.1, 0.2, 1.0, 1.0)))
    XCTAssertEqual(try parser.parseFill("rgba(10, 20, 30, 0.5)"), .color(.rgbi(10, 20, 30, 0.5)))
    XCTAssertEqual(try parser.parseFill("rgba(10%,20%,100%,0.6)"), .color(.rgbf(0.1, 0.2, 1.0, 0.6)))
    XCTAssertEqual(try parser.parseFill("#AAFF00"), .color(.hex(170, 255, 0)))
    
    XCTAssertEqual(try parser.parseFill("url(#test)"), .url(URL(string: "#test")!))
    
    XCTAssertThrowsError(try parser.parseFill("Ns "))
    XCTAssertThrowsError(try parser.parseFill("d"))
    XCTAssertThrowsError(try parser.parseFill("url()"))
    //XCTAssertThrowsError(try parser.parseFill("url(asdf"))
  }
  
  func testUrl() {
#if canImport(Darwin)
    XCTAssertEqual(try parser.parseUrl("#testing🐟").fragmentID, "testing🐟")
#else
      XCTAssertEqual(try parser.parseUrl("#testing").fragmentID, "testing")
#endif
    XCTAssertEqual(try parser.parseUrl("http://www.google.com").host, "www.google.com")
  }
  
  func testUrlSelector() {
    XCTAssertEqual(try parser.parseUrlSelector("url(#testingId)").fragmentID, "testingId")
    XCTAssertEqual(try parser.parseUrlSelector("url(http://www.google.com)").host, "www.google.com")
    
    XCTAssertThrowsError(try parser.parseUrlSelector("url(#testingId) other"))
  }
  
  func testPoints() {
    XCTAssertEqual(try parser.parsePoints("0 1 2 3"), [DOM.Point(0, 1), DOM.Point(2, 3)])
    XCTAssertEqual(try parser.parsePoints("0,1 2,3"), [DOM.Point(0, 1), DOM.Point(2, 3)])
    XCTAssertEqual(try parser.parsePoints("0 1.5 1e4 2.4"), [DOM.Point(0, 1.5), DOM.Point(1e4, 2.4)])
    //  XCTAssertEqual(try parser.parsePoints("0 1 2 3 5.0 6.5"), [0, 1 ,2])
  }
  
  func testRaw() {
    XCTAssertEqual(try parser.parseRaw("evenodd"), DOM.FillRule.evenodd)
    XCTAssertEqual(try parser.parseRaw("round"), DOM.LineCap.round)
    XCTAssertEqual(try parser.parseRaw("miter"), DOM.LineJoin.miter)
    
    XCTAssertThrowsError((try parser.parseRaw("sd")) as DOM.LineJoin)
  }
}



