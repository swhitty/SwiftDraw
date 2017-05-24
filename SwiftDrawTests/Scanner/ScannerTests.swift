//
//  ScannerTests.swift
//  SwiftVG
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright © 2016 WhileLoop Pty Ltd. All rights reserved.
//

import XCTest
@testable import SwiftDraw

typealias CharacterSet = SwiftDraw.CharacterSet
typealias Scanner = SwiftDraw.Scanner

class ScannerTests: XCTestCase {
    
    private let emoji: CharacterSet = "🤠🌞💎🐶\u{1f1e6}\u{1f1fa}"
    
    func testScanCharsetHex() {
        var scanner = Scanner(text: "  \t   8badf00d  \t  \t  007")
        
        XCTAssertEqual(scanner.scan(any: CharacterSet.hexadecimal), "8badf00d")
        XCTAssertEqual(scanner.scan(any: CharacterSet.hexadecimal), "007")
        XCTAssertNil(scanner.scan(any: CharacterSet.hexadecimal))
    }
    
    func testScanCharsetEmoji() {
        var scanner = Scanner(text: "  \t   8badf00d  \t🐶  \t🌞🇦🇺  007")
        
        XCTAssertNil(scanner.scan(any: emoji))
        XCTAssertEqual(scanner.scan(any: CharacterSet.hexadecimal), "8badf00d")
        XCTAssertNil(scanner.scan(any: CharacterSet.hexadecimal))
        XCTAssertEqual(scanner.scan(any: emoji), "🐶")
        XCTAssertNil(scanner.scan(any: CharacterSet.hexadecimal))
        XCTAssertEqual(scanner.scan(any: emoji), "🌞🇦🇺")
        XCTAssertNil(scanner.scan(any: emoji))
        XCTAssertEqual(scanner.scan(any: CharacterSet.hexadecimal), "007")
    }
    
    func testScanString() {
        var scanner = Scanner(text: "  \t The quick brown fox")
        
        XCTAssertNil(scanner.scan("fox"))
        XCTAssertEqual(scanner.scan("The"), "The")
        XCTAssertNil(scanner.scan("quick fox"))
        XCTAssertEqual(scanner.scan("quick brown"), "quick brown")
        XCTAssertEqual(scanner.scan("fox"), "fox")
        XCTAssertNil(scanner.scan("fox"))
    }
    
    func testScanCharacter() {
        var scanner = Scanner(text: "  \t The fox 8badf00d ")
        
        XCTAssertNil(scanner.scan(first: "qfxh"))
        XCTAssertEqual(scanner.scan(first: "fxT"), "T")
        XCTAssertNil(scanner.scan(first: "fxT"))
        XCTAssertEqual(scanner.scan(first: "qfxh"), "h")
        XCTAssertEqual(scanner.scan("e fox"), "e fox")
        XCTAssertNil(scanner.scan(first: "fxT"))
        XCTAssertEqual(scanner.scan(first: CharacterSet.hexadecimal), "8")
        XCTAssertEqual(scanner.scan(first: CharacterSet.hexadecimal), "b")
        XCTAssertEqual(scanner.scan(first: CharacterSet.hexadecimal), "a")
        XCTAssertEqual(scanner.scan(first: CharacterSet.hexadecimal), "d")
        XCTAssertEqual(scanner.scan(first: CharacterSet.hexadecimal), "f")
        XCTAssertEqual(scanner.scan(first: CharacterSet.hexadecimal), "0")
        XCTAssertEqual(scanner.scan(first: CharacterSet.hexadecimal), "0")
        XCTAssertEqual(scanner.scan(first: CharacterSet.hexadecimal), "d")
        XCTAssertNil(scanner.scan(first: CharacterSet.hexadecimal))
    }
    
    func testScanUInt8() {
        AssertScanUInt8("0", 0)
        AssertScanUInt8("124", 124)
        AssertScanUInt8(" 045", 45)
        AssertScanUInt8("-29", nil)
        AssertScanUInt8("ab24", nil)
    }
    
    func testScanBool() {
        AssertScanBool("0", false)
        AssertScanBool("1", true)
        AssertScanBool("true", true)
        AssertScanBool("false", false)
        AssertScanBool("false", false)
        AssertScanUInt8("-29", nil)
        AssertScanUInt8("ab24", nil)
    }
    
    func testScanPercentage() {
        AssertScanPercentage("0", 0)
        AssertScanPercentage("0%", 0)
        AssertScanPercentage("100%", 1.0)
        AssertScanPercentage("100 %", 1.0)
        AssertScanPercentage("45.5 %", 0.455)
        AssertScanPercentage("0.5 %", 0.005)
        AssertScanPercentage("as", nil)
        AssertScanPercentage("29", nil)
        AssertScanPercentage("24", nil)
    }
    
    func testScanCoordinate() {
        var scanner = Scanner(text: "10.05,12.04-49.05,30.02-10")
        
        XCTAssertEqual(try? scanner.scanCoordinate(), 10.05)
        _ = scanner.scan(first: ",")
        XCTAssertEqual(try? scanner.scanCoordinate(), 12.04)
        _ = scanner.scan(first: ",")
        XCTAssertEqual(try? scanner.scanCoordinate(), -49.05)
        _ = scanner.scan(first: ",")
        XCTAssertEqual(try? scanner.scanCoordinate(), 30.02)
        _ = scanner.scan(first: ",")
        XCTAssertEqual(try? scanner.scanCoordinate(), -10)
    }
    
}

private func AssertScanUInt8(_ text: String, _ expected: UInt8?, file: StaticString = #file, line: UInt = #line) {
    var scanner = Scanner(text: text)
    XCTAssertEqual(try? scanner.scanUInt8(), expected, file: file, line: line)
}

private func AssertScanBool(_ text: String, _ expected: Bool?, file: StaticString = #file, line: UInt = #line) {
    var scanner = Scanner(text: text)
    XCTAssertEqual(try? scanner.scanBool(), expected, file: file, line: line)
}

private func AssertScanPercentage(_ text: String, _ expected: Float?, file: StaticString = #file, line: UInt = #line) {
    var scanner = Scanner(text: text)
    XCTAssertEqual(try? scanner.scanPercentage(), expected, file: file, line: line)
}
