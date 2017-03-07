//
//  TextTests.swift
//  SwiftVG
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright © 2016 WhileLoop Pty Ltd. All rights reserved.
//

import XCTest
@testable import SwiftVG

class TextTests: XCTestCase {
    
    func testText() {
        XCTAssertEqual(try XMLParser().parseText([:], value: "Simon").value, "Simon")
        
        var node = ["x": "10", "y": "25"]
        XCTAssertNotNil(try? XMLParser().parseText(node, value: "Simon"))
        
        node["font-family"] = "Futura"
        node["font-size"] = "12.5"
        
        let expected = DOM.Text(x: 10, y: 25, value: "Simon")
        expected.fontFamily = "Futura"
        expected.fontSize = 12.5
        
        let parsed = try? XMLParser().parseText(node, value: "Simon")
        XCTAssertEqual(parsed, expected)
        
        let el = XML.Element(name: "text", attributes: [:])
        XCTAssertNil(try XMLParser().parseText(["x": "1", "y": "1"], element: el))
        el.innerText = "    "
        XCTAssertNil(try XMLParser().parseText(["x": "1", "y": "1"], element: el))
    }
}


