//
//  CoordinateTests.swift
//  SwiftVG
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright © 2016 WhileLoop Pty Ltd. All rights reserved.
//

import XCTest
@testable import SwiftVG

class CoordinateTests: XCTestCase {
    
    func testPrecisionMax() {
        var f = Formatter.CoordinateFormatter()
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
        
        var f = Formatter.CoordinateFormatter()
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
        var f = Formatter.CoordinateFormatter()
        f.delimeter = .space
        
        XCTAssertEqual(f.format(2.05), "2.05")
        XCTAssertEqual(f.format(2.05, 4.5), "2.05 4.5")
        XCTAssertEqual(f.format(2.05, 4.5, 10, 20), "2.05 4.5 10 20")
    }
    
    func testDelimeterComma() {
        var f = Formatter.CoordinateFormatter()
        f.delimeter = .comma
        
        XCTAssertEqual(f.format(2.05), "2.05")
        XCTAssertEqual(f.format(2.05, 4.5), "2.05,4.5")
        XCTAssertEqual(f.format(2.05, 4.5, 10, 20), "2.05,4.5,10,20")
    }
}
