//
//  ColorTests.swift
//  SwiftVG
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright © 2016 WhileLoop Pty Ltd. All rights reserved.
//

import XCTest
@testable import SwiftVG

private func AssertColorEqual(_ text: String, _ color: DOM.Color, file: StaticString = #file, line: UInt = #line) {
    let parsedColor = try? XMLParser().parseColor(data: text)
    XCTAssertEqual(parsedColor, color, file: file, line: line)
}

private func AssertColorEqual(_ text: String, keyword: DOM.Color.Keyword, file: StaticString = #file, line: UInt = #line) {
    let parsed = XMLParser().parseColorKeyword(data: text)
    XCTAssertEqual(parsed, keyword, file: file, line: line)
}

private func AssertColorEqual(_ text: String, rgbi: (UInt8, UInt8, UInt8), file: StaticString = #file, line: UInt = #line) {
    guard let parsed = XMLParser().parseColorRGBi(data: text) else {
        XCTFail("Failed to parse rgbi from \(text)", file: file, line: line)
        return
    }
    
    XCTAssertTrue(rgbi == parsed, file: file, line: line)
}

private func AssertColorEqual(_ text: String, rgbf: (DOM.Float, DOM.Float, DOM.Float), file: StaticString = #file, line: UInt = #line) {
    guard let parsed = XMLParser().parseColorRGBf(data: text) else {
        XCTFail("Failed to parse rgbf from \(text)", file: file, line: line)
        return
    }
    
    XCTAssertTrue(rgbf == parsed, file: file, line: line)
}

private func AssertColorEqual(_ text: String, hex: UInt32, file: StaticString = #file, line: UInt = #line) {
    guard let parsed = XMLParser().parseColorHex(data: text) else {
        XCTFail("Failed to parse hex from \(text)", file: file, line: line)
        return
    }
    
    let r = UInt8((hex >> 16) & 0xff)
    let g = UInt8((hex >> 8) & 0xff)
    let b = UInt8(hex & 0xff)

    XCTAssertTrue(parsed == (r, g, b), file: file, line: line)
}


class ParserColorTests: XCTestCase {
    
    func testColorNone() {
        let p = XMLParser()
        XCTAssertEqual(p.parseColorNone(data: "none"), .none)
        XCTAssertEqual(p.parseColorNone(data: " none "), .none)
        XCTAssertEqual(p.parseColorNone(data: " \t none \t"), .none)
    }
    
    func testColorKeyword() {
        
        let p = XMLParser()
        
        XCTAssertEqual(p.parseColorKeyword(data: "aliceblue"), .aliceblue)
        XCTAssertEqual(p.parseColorKeyword(data: "wheat"), .wheat)
        XCTAssertEqual(p.parseColorKeyword(data: "cornflowerblue"), .cornflowerblue)
        XCTAssertEqual(p.parseColorKeyword(data: "  magenta"), .magenta)
        XCTAssertEqual(p.parseColorKeyword(data: "black  "), .black)
        XCTAssertEqual(p.parseColorKeyword(data: "\t red  \t"), .red)
    }
    
    func testColorRGBi() {
        AssertColorEqual("rgb(0,1,2)", rgbi: (0, 1, 2))
        AssertColorEqual(" rgb( 0 , 1 , 2) ", rgbi: (0, 1, 2))
        AssertColorEqual("rgb(255,100,78)", rgbi: (255, 100, 78))
    }
    
    func testColorRGBf() {
        AssertColorEqual("rgb(0,1%,99%)", rgbf: (0.0, 0.01, 0.99))
        AssertColorEqual("rgb( 0%, 52% , 100%) ", rgbf: (0.0, 0.52, 1.0))
        AssertColorEqual("rgb(75%,25%,7%)", rgbf: (0.75, 0.25, 0.07))
    }
    
    func testColorHex() {
        AssertColorEqual("#a06", hex: 0xa00060)
        AssertColorEqual("#123456", hex: 0x123456)
        AssertColorEqual("#FF11DD", hex: 0xFF11DD)
    }
    


}
