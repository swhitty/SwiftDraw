//
//  Parser.GraphicAttributeTests.swift
//  SwiftVG
//
//  Created by Simon Whitty on 27/2/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

import XCTest
@testable import SwiftDraw

class ParserGraphicAttributeTests: XCTestCase {
    
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
        XCTAssertEqual(parsed.transform!, [.scale(sx: 15, sy: 15)])
        XCTAssertEqual(parsed.clipPath?.fragment, "circlePath")
        XCTAssertEqual(parsed.mask?.fragment, "fancyMask")
    }
    
    func testCircle() {
        let el = XML.Element("circle",style: "clip-path: url(#cp1); cx:10;cy:10;r:10; fill:black; stroke-width:2")
        
        let parsed = try? XMLParser().parseGraphicsElement(el)
        let circle = parsed as? DOM.Circle
        XCTAssertNotNil(circle)
        XCTAssertEqual(circle?.clipPath?.fragment, "cp1")
        XCTAssertEqual(circle?.fill, .keyword(.black))
        XCTAssertEqual(circle?.strokeWidth, 2)
    }
    

    
    func testDisplayMode() {
        let parser = XMLParser.ValueParser()
        
        XCTAssertEqual(try parser.parseRaw("none"), DOM.DisplayMode.none)
        XCTAssertEqual(try parser.parseRaw("  none  "), DOM.DisplayMode.none)
        XCTAssertThrowsError(try parser.parseRaw("ds") as DOM.DisplayMode )
    }

    func testStrokeLineCap() {
        let parser = XMLParser.ValueParser()
        
        XCTAssertEqual(try parser.parseRaw("butt"), DOM.LineCap.butt)
        XCTAssertEqual(try parser.parseRaw("  round"), DOM.LineCap.round)
        XCTAssertThrowsError(try parser.parseRaw("squdare") as DOM.LineCap)
    }
    
    func testStrokeLineJoin() {
        let parser = XMLParser.ValueParser()
        
        XCTAssertEqual(try parser.parseRaw("miter"), DOM.LineJoin.miter)
        XCTAssertEqual(try parser.parseRaw("  bevel"), DOM.LineJoin.bevel)
        XCTAssertThrowsError(try parser.parseRaw("ds") as DOM.LineJoin)
    }
}

