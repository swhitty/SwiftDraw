//
//  ColorTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright 2016 Simon Whitty
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
