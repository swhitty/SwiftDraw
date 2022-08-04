//
//  CoordinateTests.swift
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

final class CoordinateTests: XCTestCase {
  
  func testPrecisionMax() {
      var f = XML.Formatter.CoordinateFormatter()
    f.precision = .maximum
    
    XCTAssertEqual(f.format(1.0), "1.0")
    XCTAssertEqual(f.format(1.01), "1.01")
    XCTAssertEqual(f.format(1.001), "1.001")
    XCTAssertEqual(f.format(1.0001), "1.0001")
    XCTAssertEqual(f.format(1.00001), "1.00001")
    XCTAssertEqual(f.format(1.000001), "1.000001")
    XCTAssertEqual(f.format(1.0000001), "1.0000001")
    XCTAssertEqual(f.format(1e-20), "1e-20")
    XCTAssertEqual(f.format(12e-20), "1.2e-19")
  }
  
  func testPrecisionCapped() {
    
    var f = XML.Formatter.CoordinateFormatter()
    f.precision = .capped(max: 4)
    
    XCTAssertEqual(f.format(1.0), "1")
    XCTAssertEqual(f.format(1.01), "1.01")
    XCTAssertEqual(f.format(1.001), "1.001")
    XCTAssertEqual(f.format(1.0001), "1.0001")
    XCTAssertEqual(f.format(1.00001), "1")
    XCTAssertEqual(f.format(1.000001), "1")
    XCTAssertEqual(f.format(1.0000001), "1")
    XCTAssertEqual(f.format(1e-20), "0")
    XCTAssertEqual(f.format(12e-20), "0")
  }
  
  func testDelimeterSpace() {
    var f = XML.Formatter.CoordinateFormatter()
    f.delimeter = .space
    
    XCTAssertEqual(f.format(2.05), "2.05")
    XCTAssertEqual(f.format(2.05, 4.5), "2.05 4.5")
    XCTAssertEqual(f.format(2.05, 4.5, 10, 20), "2.05 4.5 10 20")
  }
  
  func testDelimeterComma() {
    var f = XML.Formatter.CoordinateFormatter()
    f.delimeter = .comma
    
    XCTAssertEqual(f.format(2.05), "2.05")
    XCTAssertEqual(f.format(2.05, 4.5), "2.05,4.5")
    XCTAssertEqual(f.format(2.05, 4.5, 10, 20), "2.05,4.5,10,20")
  }
}
