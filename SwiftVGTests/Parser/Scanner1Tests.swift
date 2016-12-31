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
    var scanner = SwiftVG.ScannerB(text: text)
    XCTAssertEqual(scanner.scanCoordinate(), coordinate, file: file, line: line)
}

private func AssertScanBool(_ text: String, _ bool: DOM.Bool, file: StaticString = #file, line: UInt = #line) {
    var scanner = SwiftVG.ScannerB(text: text)
    XCTAssertEqual(scanner.scanBool(), bool, file: file, line: line)
}


class Scanner1Tests: XCTestCase {
    
    func testCharSet() {
        
        var scanner = SwiftVG.ScannerB(text: " 29384 Az 2939  \t 4 ; 54 ")
        
        XCTAssertNil(scanner.scan(scanner.digits))
        XCTAssertEqual(scanner.scan(scanner.whitespace), " ")
        XCTAssertEqual(scanner.scan(scanner.digits), "29384")
        XCTAssertEqual(scanner.scan(scanner.whitespace), " ")
        XCTAssertNil(scanner.scan(["z", "a"]))
        XCTAssertEqual(scanner.scan(["z", "A"]), "Az")
        XCTAssertEqual(scanner.scan(scanner.whitespace), " ")
        XCTAssertEqual(scanner.scan(scanner.digits), "2939")
        XCTAssertEqual(scanner.scan(scanner.whitespace), "  \t ")
        XCTAssertEqual(scanner.scanCharacter(["4"]), "4")
        XCTAssertEqual(scanner.scan(scanner.whitespace), " ")
        XCTAssertEqual(scanner.scan([";"]), ";")
        XCTAssertEqual(scanner.scan(scanner.whitespace), " ")
        XCTAssertEqual(scanner.scan(scanner.digits), "54")
        XCTAssertEqual(scanner.scan(scanner.whitespace), " ")
        XCTAssertNil(scanner.scan(scanner.whitespace))
        XCTAssertNil(scanner.scan(scanner.digits))
    }
    
    func testString() {
        var scanner = SwiftVG.ScannerB(text: "The quick brown  \tfox jumps over the lazy dog.")
        
        XCTAssertNil(scanner.scan("THE quick"))
        XCTAssertEqual(scanner.scan("The quick brown"), "The quick brown")
        XCTAssertEqual(scanner.scan(scanner.whitespace), "  \t")
        XCTAssertEqual(scanner.scan("fox"), "fox")
        XCTAssertEqual(scanner.scan(" jumps over the lazy dog."), " jumps over the lazy dog.")
    }

    func testCoordinate() {
        AssertScanCoordinate("30", 30.0)
        AssertScanCoordinate("30.05", 30.05)
        AssertScanCoordinate("-30", -30)
        AssertScanCoordinate("-30.05", -30.05)
        
        //E notation
        AssertScanCoordinate("3E3", 3000)
        AssertScanCoordinate("3e3", 3000)
        AssertScanCoordinate("-3E3", -3000)
        AssertScanCoordinate("-3e3", -3000)
        
        //-E notation
        AssertScanCoordinate("3E-3", 0.003)
        AssertScanCoordinate("3e-3", 0.003)
        AssertScanCoordinate("-3E-3", -0.003)
        AssertScanCoordinate("-3e-3", -0.003)
       
        AssertScanCoordinate(" 30", 30.0)
        AssertScanCoordinate(" 30 ", 30.0)
    }
    
    
    func testCoordinateSequence() {
        var scanner = SwiftVG.ScannerB(text: "  30 10 30.40;  0.04    -10; -0.124 4 7E3")
        
        XCTAssertEqual(scanner.scanCoordinate(), 30.0)
        XCTAssertEqual(scanner.scanCoordinate(), 10.0)
        XCTAssertEqual(scanner.scanCoordinate(), 30.40)
        XCTAssertEqual(scanner.scanCoordinate(), 0.04)
        XCTAssertEqual(scanner.scanCoordinate(), -10)
        XCTAssertEqual(scanner.scanCoordinate(), -0.124)
        XCTAssertEqual(scanner.scanCoordinate(), 4)
        XCTAssertEqual(scanner.scanCoordinate(), 7e3)
    }
    
    func testCoordinateSequenceAnother() {
        var scanner = SwiftVG.ScannerB(text: "  30; 10 ; 20")
        
        XCTAssertEqual(scanner.scanCoordinate(), 30.0)
        XCTAssertEqual(scanner.scanCoordinate(), 10.0)
        XCTAssertEqual(scanner.scanCoordinate(), 20.0)
    }
    
    func testBool() {
        AssertScanBool("0", false)
        AssertScanBool("1", true)
    }
    
    func testBoolSequence() {
        var scanner = SwiftVG.ScannerB(text: "0 1   1  0  1; 0;  0 ")
        
        XCTAssertEqual(scanner.scanBool(), false)
        XCTAssertEqual(scanner.scanBool(), true)
        XCTAssertEqual(scanner.scanBool(), true)
        XCTAssertEqual(scanner.scanBool(), false)
        XCTAssertEqual(scanner.scanBool(), true)
        XCTAssertEqual(scanner.scanBool(), false)
        XCTAssertEqual(scanner.scanBool(), false)
    }
    
    func testScan() {
        var scanner = SwiftVG.ScannerB(text: "Simon;")
        XCTAssertEqual(scanner.scan("Sim"), "Sim")
        XCTAssertEqual(scanner.scan(""), "")
        XCTAssertEqual(scanner.scan("on"), "on")
        XCTAssertEqual(scanner.scan(";"), ";")
        XCTAssertEqual(scanner.scan(""), "")
        XCTAssertEqual(scanner.scan("Hi"), nil)
    }
    
    func testPercentage() {
        var scanner = SwiftVG.ScannerB(text: "99%")
        XCTAssertEqual(scanner.scanPercentage(), 0.99)
        
        scanner = SwiftVG.ScannerB(text: "54.35%")
        XCTAssertEqual(scanner.scanPercentage(), 0.5435)
        
        scanner = SwiftVG.ScannerB(text: "0")
        XCTAssertEqual(scanner.scanPercentage(), 0)
    }
    
    func testFunction() {
        var scanner = SwiftVG.ScannerB(text: "rgb(1,2,4)")
        XCTAssertEqual(scanner.scanFunction("rgb"), "rgb")
        
        scanner = SwiftVG.ScannerB(text: "transform()")
        XCTAssertEqual(scanner.scanFunction("transform"), "transform")
        
        scanner = SwiftVG.ScannerB(text: "shrink()")
        XCTAssertNil(scanner.scanFunction("transform"))
    }
}
