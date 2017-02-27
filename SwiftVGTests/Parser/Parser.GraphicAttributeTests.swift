//
//  Parser.GraphicAttributeTests.swift
//  SwiftVG
//
//  Created by Simon Whitty on 27/2/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

import XCTest
@testable import SwiftVG

class ParserGraphicAttributeTests: XCTestCase {
    
    func testURLAnchor() {
        AssertURLAnchorEqual("url(#clipPath1)", "clipPath1")
        AssertURLAnchorEqual("url(#cp1)", "cp1")
        AssertURLAnchorEqual(" url( # cp1 )   ", "cp1")
    }
    
    func testPresentationAttributes() throws {
        var parsed = try XMLParser().parsePresentationAttributes([:])
        XCTAssertNil(parsed.fill)
        XCTAssertNil(parsed.stroke)
        XCTAssertNil(parsed.strokeWidth)
        XCTAssertNil(parsed.transform)
        XCTAssertNil(parsed.clipPath)
        
        let att = ["fill": "blue",
                   "stroke": "green",
                   "stroke-width": "15.0",
                   "transform": "scale(15)",
                   "clip-path": "url(#circlePath)"]
        
        parsed = try XMLParser().parsePresentationAttributes(att)
        
        XCTAssertEqual(parsed.fill, .keyword(.blue))
        XCTAssertEqual(parsed.stroke, .keyword(.green))
        XCTAssertEqual(parsed.strokeWidth, 15)
        XCTAssertEqual(parsed.transform!, [.scale(sx: 15, sy: 0)])
        XCTAssertEqual(parsed.clipPath, "circlePath")
    }
    
    func testCircle() {
        let el = XML.Element("circle",style: "clip-path: url(#cp1); cx:10;cy:10;r:10; fill:black; stroke-width:2")
        
        let parsed = try? XMLParser().parseGraphicsElement(el)
        let circle = parsed as? DOM.Circle
        XCTAssertNotNil(circle)
        XCTAssertEqual(circle?.clipPath, "cp1")
        XCTAssertEqual(circle?.fill, .keyword(.black))
        XCTAssertEqual(circle?.strokeWidth, 2)
    }
}

private func AssertURLAnchorEqual(_ text: String, _ expected: String, file: StaticString = #file, line: UInt = #line) {
    XCTAssertEqual(try XMLParser().parseUrlAnchor(data: text), expected, file: file, line: line)
}



