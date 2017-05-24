//
//  FormatterTests.swift
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

class DOMPathTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testFormatter() {
        let path = DOM.Path(x: 10, y: 10)
        
        path.horizontal(x: 10, space: .relative)
        path.vertical(y: 10, space: .relative)
        path.horizontal(x: -10, space: .relative)
        path.vertical(y: -10, space: .relative)
        
        var formatter = XMLFormatter.Path()
        formatter.coordinateFormatter.delimeter = .space
        formatter.segmentFormatter.delimeter = .space
        var s = formatter.format(path.segments)
        XCTAssertEqual("M 10 10 h 10 v 10 h -10 v -10", s)
        
        formatter = XMLFormatter.Path()
        formatter.coordinateFormatter.delimeter = .comma
        formatter.segmentFormatter.delimeter = .none
        s = formatter.format(path.segments)
        XCTAssertEqual("M10,10 h10 v10 h-10 v-10", s)
        
        let n = formatter.format(path)
        XCTAssertEqual(n.name, "path")
        XCTAssertEqual(n.attributes["d"], s)
    }
}
