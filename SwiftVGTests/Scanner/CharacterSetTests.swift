//
//  CharacterSetTests.swift
//  SwiftVG
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright © 2016 WhileLoop Pty Ltd. All rights reserved.
//

import XCTest
@testable import SwiftVG

class CharacterSetTests: XCTestCase {
    
    func testLiteral() {
        AssertTrue(charset: "Simon", includes: ["S","i","m","o","n"])
        AssertTrue(charset: CharacterSet.whitespaces, includes: [" ", "\t"])
        AssertFalse(charset: CharacterSet.whitespaces, includes: ["\n"])
        AssertTrue(charset: CharacterSet.whitespacesAndNewLines, includes: [" ", "\t", "\n", "\r"])
        
        AssertFalse(charset: CharacterSet.empty, includes: ["\n", " ", "S"])
    }
    
}

private func AssertTrue(charset: CharacterSet, includes: Set<Character>, file: StaticString = #file, line: UInt = #line) {
    
    for c in includes {
        XCTAssertTrue(charset.contains(c), "character '\(c)' \(c.hashValue) was not found", file: file, line: line)
    }
}

private func AssertFalse(charset: CharacterSet, includes: Set<Character>, file: StaticString = #file, line: UInt = #line) {
    
    for c in includes {
        XCTAssertFalse(charset.contains(c), "character '\(c)' \(c.hashValue) was found", file: file, line: line)
    }
}
