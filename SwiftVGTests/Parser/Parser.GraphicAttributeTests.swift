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
        XCTAssertNil(parsed.opacity)
        XCTAssertNil(parsed.display)
        XCTAssertNil(parsed.stroke)
        XCTAssertNil(parsed.strokeWidth)
        XCTAssertNil(parsed.strokeOpacity)
        XCTAssertNil(parsed.strokeLineCap)
        XCTAssertNil(parsed.strokeLineJoin)
        XCTAssertNil(parsed.strokeDashArray)
        XCTAssertNil(parsed.fill)
        XCTAssertNil(parsed.fillOpacity)
        XCTAssertNil(parsed.fillRule)
        XCTAssertNil(parsed.transform)
        XCTAssertNil(parsed.clipPath)
        XCTAssertNil(parsed.mask)
        
        let att = ["opacity": "95%",
                   "display": "none",
                   "stroke": "green",
                   "stroke-width": "15.0",
                   "stroke-opacity": "75.6%",
                   "stroke-linecap": "butt",
                   "stroke-linejoin": "miter",
                   "stroke-dasharray": "1 5 10",
                   "fill": "purple",
                   "fill-opacity": "25%",
                   "fill-rule": "evenodd",
                   "transform": "scale(15)",
                   "clip-path": "url(#circlePath)",
                   "mask": "url(#fancyMask)"]
        
        parsed = try XMLParser().parsePresentationAttributes(att)
        
        XCTAssertEqual(parsed.opacity, 0.95)
        XCTAssertEqual(parsed.display!, .none)
        XCTAssertEqual(parsed.stroke, .keyword(.green))
        XCTAssertEqual(parsed.strokeWidth, 15)
        XCTAssertEqual(parsed.strokeOpacity, 0.756)
        XCTAssertEqual(parsed.strokeLineCap, .butt)
        XCTAssertEqual(parsed.strokeLineJoin, .miter)
        XCTAssertEqual(parsed.strokeDashArray!, [1, 5, 10])
        XCTAssertEqual(parsed.fill, .keyword(.purple))
        XCTAssertEqual(parsed.fillOpacity, 0.25)
        XCTAssertEqual(parsed.fillRule, .evenodd)
        XCTAssertEqual(parsed.transform!, [.scale(sx: 15, sy: 0)])
        XCTAssertEqual(parsed.clipPath, "circlePath")
        XCTAssertEqual(parsed.mask, "fancyMask")
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
    
    func testDisplayMode() {
        XCTAssertNil(try XMLParser().parseDisplayMode(nil))
        XCTAssertEqual(try XMLParser().parseDisplayMode("none"), .none)
        XCTAssertEqual(try XMLParser().parseDisplayMode(" none "), .none)
        
        XCTAssertThrowsError(try XMLParser().parseDisplayMode("ds"))
    }
    
    func testStrokeLineCap() {
        XCTAssertNil(try XMLParser().parseLineCap(nil))
        XCTAssertEqual(try XMLParser().parseLineCap("butt"), .butt)
        XCTAssertEqual(try XMLParser().parseLineCap("round"), .round)
        XCTAssertEqual(try XMLParser().parseLineCap("square"), .square)
        XCTAssertEqual(try XMLParser().parseLineCap(" square "), .square)
        
        XCTAssertThrowsError(try XMLParser().parseLineCap("ds"))
    }

    func testStrokeLineJoin() {
        XCTAssertNil(try XMLParser().parseLineJoin(nil))
        XCTAssertEqual(try XMLParser().parseLineJoin("miter"), .miter)
        XCTAssertEqual(try XMLParser().parseLineJoin("round"), .round)
        XCTAssertEqual(try XMLParser().parseLineJoin("bevel"), .bevel)
        XCTAssertEqual(try XMLParser().parseLineJoin(" bevel "), .bevel)
        
        XCTAssertThrowsError(try XMLParser().parseLineJoin("ds"))
    }
    
    func testStrokeDashArray() {
        XCTAssertNil(try XMLParser().parseDashArray(nil))
        XCTAssertEqual(try XMLParser().parseDashArray("5 10 1 5")!, [5, 10, 1, 5])
        XCTAssertEqual(try XMLParser().parseDashArray(" 1, 2.5, 3.5 ")!, [1, 2.5, 3.5])
        XCTAssertThrowsError(try XMLParser().parseDashArray("ds"))
    }
    
}

private func AssertURLAnchorEqual(_ text: String, _ expected: String, file: StaticString = #file, line: UInt = #line) {
    XCTAssertEqual(try XMLParser().parseUrlAnchor(data: text), expected, file: file, line: line)
}



