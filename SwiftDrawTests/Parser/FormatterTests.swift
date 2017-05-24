//
//  FormatterTests.swift
//  SwiftVG
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright © 2016 WhileLoop Pty Ltd. All rights reserved.
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
