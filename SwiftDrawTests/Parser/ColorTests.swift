//
//  ColorTests.swift
//  SwiftVG
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright © 2016 WhileLoop Pty Ltd. All rights reserved.
//

import XCTest
@testable import SwiftDraw

private func AssertColorEqual(_ text: String, _ expected: DOM.Color, file: StaticString = #file, line: UInt = #line) {
    
    guard let parsed = try? XMLParser().parseColor(data: text) else {
        XCTFail("Failed to parse from \(text)", file: file, line: line)
        return
    }
    
    XCTAssertEqual(parsed, expected, file: file, line: line)
}

private func AssertColorEqual(_ text: String, hex: UInt32, file: StaticString = #file, line: UInt = #line) {
    let r = UInt8((hex >> 16) & 0xff)
    let g = UInt8((hex >> 8) & 0xff)
    let b = UInt8(hex & 0xff)
    
    AssertColorEqual(text, .hex(r, g, b), file: file, line: line)
}

class ParserColorTests: XCTestCase {
    
    func testColorNone() {
        AssertColorEqual("none", .none)
        AssertColorEqual(" none ", .none)
        AssertColorEqual("\t none \t", .none)
    }
    
    func testColorKeyword() {
        AssertColorEqual("aliceblue", .keyword(.aliceblue))
        AssertColorEqual("wheat", .keyword(.wheat))
        AssertColorEqual("cornflowerblue", .keyword(.cornflowerblue))
        AssertColorEqual("  magenta", .keyword(.magenta))
        AssertColorEqual("black  ", .keyword(.black))
        AssertColorEqual("\t red  \t", .keyword(.red))
    }
    
    func testColorRGB() {
        // integer 0-255
        AssertColorEqual("rgb(0,1,2)", .rgbi(0, 1, 2))
        AssertColorEqual(" rgb( 0 , 1 , 2) ", .rgbi(0, 1, 2))
        AssertColorEqual("rgb(255,100,78)", .rgbi(255, 100, 78))
        
        // percentage 0-100%
        AssertColorEqual("rgb(0,1%,99%)", .rgbf(0.0, 0.01, 0.99))
        AssertColorEqual("rgb( 0%, 52% , 100%) ", .rgbf(0.0, 0.52, 1.0))
        AssertColorEqual("rgb(75%,25%,7%)", .rgbf(0.75, 0.25, 0.07))
    }
    
    func testColorHex() {
        AssertColorEqual("#a06", hex: 0xa00060)
        AssertColorEqual("#123456", hex: 0x123456)
        AssertColorEqual("#FF11DD", hex: 0xff11dd)
    }
}
