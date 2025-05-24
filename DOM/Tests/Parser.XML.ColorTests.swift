//
//  Parser.XML.ColorTests.swift
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
@testable import DOM

final class ParserColorTests: XCTestCase {
  
  func testColorNone() {
    XCTAssertEqual(try XMLParser().parseColor("none"), .none)
    XCTAssertEqual(try XMLParser().parseColor(" none"), .none)
    XCTAssertEqual(try XMLParser().parseColor("\t none \t"), .none)
  }

  func testColorTransparent() {
    XCTAssertEqual(try XMLParser().parseColor("transparent"), .none)
    XCTAssertEqual(try XMLParser().parseColor(" transparent"), .none)
    XCTAssertEqual(try XMLParser().parseColor("\t transparent \t"), .none)
  }

  func testColorCurrent() {
    XCTAssertEqual(try XMLParser().parseColor("currentColor"), .currentColor)
    XCTAssertEqual(try XMLParser().parseColor(" currentColor"), .currentColor)
    XCTAssertEqual(try XMLParser().parseColor("\t currentColor \t"), .currentColor)
  }

  func testColorKeyword() {
    XCTAssertEqual(try XMLParser().parseColor("aliceblue"), .keyword(.aliceblue))
    XCTAssertEqual(try XMLParser().parseColor("wheat"), .keyword(.wheat))
    XCTAssertEqual(try XMLParser().parseColor("cornflowerblue"), .keyword(.cornflowerblue))
    XCTAssertEqual(try XMLParser().parseColor(" magenta"), .keyword(.magenta))
    XCTAssertEqual(try XMLParser().parseColor("black "), .keyword(.black))
    XCTAssertEqual(try XMLParser().parseColor("\t red  \t"), .keyword(.red))
  }
  
  func testColorRGBi() {
    // integer 0-255
    XCTAssertEqual(try XMLParser().parseColor("rgb(0,1,2)"), .rgbi(0, 1, 2, 1.0))
    XCTAssertEqual(try XMLParser().parseColor(" rgb( 0 , 1 , 2) "), .rgbi(0, 1, 2, 1.0))
    XCTAssertEqual(try XMLParser().parseColor("rgb(255,100,78)"), .rgbi(255, 100, 78, 1.0))
  }
  
  func testColorRGBf() {
    // percentage 0-100%
    XCTAssertEqual(try XMLParser().parseColor("rgb(0,1%,99%)"), .rgbf(0.0, 0.01, 0.99, 1.0))
    XCTAssertEqual(try XMLParser().parseColor("rgb( 0%, 52% , 100%) "), .rgbf(0.0, 0.52, 1.0, 1.0))
    XCTAssertEqual(try XMLParser().parseColor("rgb(75%,25%,7%)"), .rgbf(0.75, 0.25, 0.07, 1.0))
  }
  
  func testColorRGBA() {
    // integer 0-255
    XCTAssertEqual(try XMLParser().parseColor("rgba(0,1,2,0.5)"), .rgbi(0, 1, 2, 0.5))
    XCTAssertEqual(try XMLParser().parseColor(" rgba( 0 , 1 , 2, 0.6) "), .rgbi(0, 1, 2, 0.6))
    XCTAssertEqual(try XMLParser().parseColor("rgba(255,100,78,0.7)"), .rgbi(255, 100, 78, 0.7))
    // percentage 0-100%
    XCTAssertEqual(try XMLParser().parseColor("rgba(0,1%,99%,0.5)"), .rgbf(0.0, 0.01, 0.99, 0.5))
    XCTAssertEqual(try XMLParser().parseColor("rgba( 0%, 52% , 100%, 0.6) "), .rgbf(0.0, 0.52, 1.0, 0.6))
    XCTAssertEqual(try XMLParser().parseColor("rgba(75%,25%,7%,0.7)"), .rgbf(0.75, 0.25, 0.07, 0.7))
  }
  
  func testColorHex() {
    XCTAssertEqual(try XMLParser().parseColor("#a06"), .hex(170, 0, 102))
    XCTAssertEqual(try XMLParser().parseColor("#123456"), .hex(18, 52, 86))
    XCTAssertEqual(try XMLParser().parseColor("#FF11DD"), .hex(255, 17, 221))
    XCTAssertThrowsError(try XMLParser().parseColor("#invalid"))
  }
  
  func testColorP3() {
    // percentage 0-100%
    XCTAssertEqual(try XMLParser().parseColor("color(display-p3 0 0.5 0.9)"), .p3(0, 0.5, 0.9))
    XCTAssertEqual(try XMLParser().parseColor("color(display-p3 0.1, 0.2, 0)"), .p3(0.1, 0.2, 0))
    XCTAssertEqual(try XMLParser().parseColor("color(display-p3 1,0.3,0.5)"), .p3(1, 0.3, 0.5))
  }
}

private extension DOMXMLParser {
  
  func parseColor(_ value: String) throws -> DOM.Color {
    return try parseFill(value).getColor()
  }
}
