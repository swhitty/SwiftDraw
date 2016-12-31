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
        let node = XML.Element(name: "text", attributes: ["x": "10", "y": "25"])
        node.innerText = "Simon"
        XCTAssertNotNil(try? XMLParser().parseText(node))
        
        node.attributes["font-family"] = "Futura"
        node.attributes["font-size"] = "12.5"
        
        let expected = DOM.Text(x: 10, y: 25, value: "Simon")
        expected.fontFamily = "Futura"
        expected.fontSize = 12.5
        
        let parsed = try? XMLParser().parseText(node)
        XCTAssertEqual(parsed, expected)
        
        node.attributes = [:]
        XCTAssertThrowsError(try XMLParser().parseText(node))
        node.attributes["x"] = "1"
        XCTAssertThrowsError(try XMLParser().parseText(node))
        node.attributes["y"] = "1"
        XCTAssertNotNil(try? XMLParser().parseText(node))
    }
}
