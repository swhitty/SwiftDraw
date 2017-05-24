//
//  CharacterSetTests.swift
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

class CharacterSetTests: XCTestCase {
    
    func testLiteral() {
        AssertTrue(charset: "Simon", includes: ["S", "i", "m", "o", "n"])
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
