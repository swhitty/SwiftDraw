//
//  ScannerTests.swift
//  SwiftVG
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright © 2016 WhileLoop Pty Ltd. All rights reserved.
//

import XCTest
@testable import SwiftVG

private func AssertScanCoordinate(_ text: String, _ coordinate: DOM.Coordinate, file: StaticString = #file, line: UInt = #line) {
    var scanner = Scanner(text: text)
    XCTAssertEqual(try? scanner.scanCoordinate(), coordinate, file: file, line: line)
}

private func AssertScanBool(_ text: String, _ bool: DOM.Bool, file: StaticString = #file, line: UInt = #line) {
    var scanner = SwiftVG.Scanner(text: text)
    XCTAssertEqual(try? scanner.scanBool(), bool, file: file, line: line)
}

class Scanner1Tests: XCTestCase {
    
    func testCharSet() {
        
        var scanner = Scanner(text: " 29384 Az 2939  \t 4 ; 54 ")
        scanner.precedingCharactersToSkip = nil
        
        let digits = CharacterSet.digits
        let whitespaces = CharacterSet.whitespaces
        
        XCTAssertNil(scanner.scan(any: digits))
        XCTAssertEqual(scanner.scan(any: whitespaces), " ")
        XCTAssertEqual(scanner.scan(any: digits), "29384")
        XCTAssertEqual(scanner.scan(any: whitespaces), " ")
        XCTAssertNil(scanner.scan(any: "za"))
        XCTAssertEqual(scanner.scan(any: "zA"), "Az")
        XCTAssertEqual(scanner.scan(any: whitespaces), " ")
        XCTAssertEqual(scanner.scan(any: digits), "2939")
        XCTAssertEqual(scanner.scan(any: whitespaces), "  \t ")
        XCTAssertEqual(scanner.scan("4"), "4")
        XCTAssertEqual(scanner.scan(any: whitespaces), " ")
        XCTAssertEqual(scanner.scan(";"), ";")
        XCTAssertEqual(scanner.scan(any: whitespaces), " ")
        XCTAssertEqual(scanner.scan(any: digits), "54")
        XCTAssertEqual(scanner.scan(any: whitespaces), " ")
        XCTAssertNil(scanner.scan(any: whitespaces))
        XCTAssertNil(scanner.scan(any: digits))
    }
    
    func testString() {
        var scanner = Scanner(text: "The quick brown  \tfox jumps over the lazy dog.")
        
        XCTAssertNil(scanner.scan("THE quick"))
        XCTAssertEqual(scanner.scan("The quick brown"), "The quick brown")
        XCTAssertEqual(scanner.scan("fox "), "fox ")
        XCTAssertEqual(scanner.scan("jumps over the lazy dog."), "jumps over the lazy dog.")
    }
    
    func testCoordinate() {
        AssertScanCoordinate("30", 30.0)
        AssertScanCoordinate("30.05", 30.05)
        AssertScanCoordinate("-30", -30)
        AssertScanCoordinate("-30.05", -30.05)
        
        // E notation
        AssertScanCoordinate("3E3", 3000)
        AssertScanCoordinate("3e3", 3000)
        AssertScanCoordinate("-3E3", -3000)
        AssertScanCoordinate("-3e3", -3000)
        
        // -E notation
        //TODO
//        AssertScanCoordinate("3E-3", 0.003)
//        AssertScanCoordinate("3e-3", 0.003)
//        AssertScanCoordinate("-3E-3", -0.003)
//        AssertScanCoordinate("-3e-3", -0.003)
        
        AssertScanCoordinate(" 30", 30.0)
        AssertScanCoordinate(" 30 ", 30.0)
    }
    
    func testCoordinateSequence() {
        var scanner = Scanner(text: "  30 10 30.40;  0.04    -10; -0.124 4 7E3")
        
        XCTAssertEqual(try? scanner.scanCoordinate(), 30.0)
        XCTAssertEqual(try? scanner.scanCoordinate(), 10.0)
        XCTAssertEqual(try? scanner.scanCoordinate(), 30.40)
        XCTAssertEqual(scanner.scan(";"), ";")
        XCTAssertEqual(try? scanner.scanCoordinate(), 0.04)
        XCTAssertEqual(try? scanner.scanCoordinate(), -10)
        XCTAssertEqual(scanner.scan(";"), ";")
        XCTAssertEqual(try? scanner.scanCoordinate(), -0.124)
        XCTAssertEqual(try? scanner.scanCoordinate(), 4)
        XCTAssertEqual(try? scanner.scanCoordinate(), 7e3)
    }
    
    func testCoordinateSequenceAnother() {
        var scanner = Scanner(text: "  30; 10 ; 20")
        
        XCTAssertEqual(try? scanner.scanCoordinate(), 30.0)
        XCTAssertEqual(scanner.scan(";"), ";")
        XCTAssertEqual(try? scanner.scanCoordinate(), 10.0)
        XCTAssertEqual(scanner.scan(";"), ";")
        XCTAssertEqual(try? scanner.scanCoordinate(), 20.0)
    }
    
    func testCoordinateSequenceTight() {
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
    
    func testBool() {
        AssertScanBool("0", false)
        AssertScanBool("1", true)
    }
    
    func testBoolSequence() throws {
        var scanner = Scanner(text: "0 1   1  0  1; 0;  0 ")
        
        XCTAssertEqual(try scanner.scanBool(), false)
        XCTAssertEqual(try scanner.scanBool(), true)
        XCTAssertEqual(try scanner.scanBool(), true)
        XCTAssertEqual(try scanner.scanBool(), false)
        XCTAssertEqual(try scanner.scanBool(), true)
        XCTAssertEqual(scanner.scan(";"), ";")
        XCTAssertEqual(try scanner.scanBool(), false)
        XCTAssertEqual(scanner.scan(";"), ";")
        XCTAssertEqual(try scanner.scanBool(), false)
    }
    
    func testScan() {
        var scanner = Scanner(text: "Simon;")
        XCTAssertEqual(scanner.scan("Sim"), "Sim")
        XCTAssertEqual(scanner.scan(""), "")
        XCTAssertEqual(scanner.scan("on"), "on")
        XCTAssertEqual(scanner.scan(";"), ";")
        XCTAssertEqual(scanner.scan(""), "")
        XCTAssertEqual(scanner.scan("Hi"), nil)
    }
}
