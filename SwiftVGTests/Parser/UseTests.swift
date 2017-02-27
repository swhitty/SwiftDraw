//
//  UseTests.swift
//  SwiftVG
//
//  Created by Simon Whitty on 27/2/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

import XCTest
@testable import SwiftVG

class UseTests: XCTestCase {
    
    func testUse() throws {
        let node = XML.Element(name: "use", attributes: ["xlink:href": "#line2", "href": "#line1"])
   
        var parsed = try XMLParser().parseUse(node)
        XCTAssertEqual(parsed.href, "line2")
        XCTAssertNil(parsed.x)
        XCTAssertNil(parsed.y)
        
        node.attributes["x"] = "20"
        node.attributes["y"] = "30"
        
        parsed = try XMLParser().parseUse(node)
        XCTAssertEqual(parsed.href, "line2")
        XCTAssertEqual(parsed.x, 20)
        XCTAssertEqual(parsed.y, 30)
    }
}
