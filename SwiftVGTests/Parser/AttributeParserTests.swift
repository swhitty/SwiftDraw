//
//  AttributeParserTests.swift
//  SwiftVG
//
//  Created by Simon Whitty on 6/3/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

import XCTest
@testable import SwiftVG

class AttributeParserTests: XCTestCase {
    
    var parser = XMLParser.ValueParser()

    func testFloat() {
        XCTAssertEqual(try parser.parseFloat("10"), 10)
        XCTAssertEqual(try parser.parseFloat("10.0"), 10.0)
        
        XCTAssertThrowsError(try parser.parseFloat(""))
        //XCTAssertThrowsError(try parser.parseFloat("10a"))
    }
    
    func testFloats() {
        XCTAssertEqual(try parser.parseFloats("10 20 30.5"), [10, 20, 30.5])
        XCTAssertEqual(try parser.parseFloats("10.0"), [10.0])
        XCTAssertEqual(try parser.parseFloats(" "), [])
        XCTAssertEqual(try parser.parseFloats(""), [])
        
        //XCTAssertThrowsError(try parser.parseFloats(""))
        //XCTAssertThrowsError(try parser.parseFloat("10a"))
    }
    
    func testPercentage() {
        XCTAssertEqual(try parser.parsePercentage("0"), 0)
        XCTAssertEqual(try parser.parsePercentage("0.0%"), 0)
        XCTAssertEqual(try parser.parsePercentage("100%"), 1)
        XCTAssertEqual(try parser.parsePercentage("55%"), 0.55)
        XCTAssertEqual(try parser.parsePercentage("10.25%"), 0.1025)
        
        XCTAssertThrowsError(try parser.parsePercentage("100"))
        XCTAssertThrowsError(try parser.parsePercentage("asd"))
        XCTAssertThrowsError(try parser.parsePercentage("0.01"))
        XCTAssertThrowsError(try parser.parsePercentage(" "))
        //XCTAssertThrowsError(try parser.parseFloat("10a"))
    }
    
    func testCoordinate() {
        XCTAssertEqual(try parser.parseCoordinate("0"), 0)
        XCTAssertEqual(try parser.parseCoordinate("0.0"), 0)
        XCTAssertEqual(try parser.parseCoordinate("100"), 100)
        XCTAssertEqual(try parser.parseCoordinate("25.0"), 25.0)
        XCTAssertEqual(try parser.parseCoordinate("-25.0"), -25.0)
        
        XCTAssertThrowsError(try parser.parseCoordinate("asd"))
        XCTAssertThrowsError(try parser.parseCoordinate(" "))
    }
    
    func testLength() {
        XCTAssertEqual(try parser.parseLength("0"), 0)
        XCTAssertEqual(try parser.parseLength("100"), 100)
        XCTAssertEqual(try parser.parseLength("25"), 25)
        XCTAssertEqual(try parser.parseLength("1.3"), 1) //should error?
        
        XCTAssertThrowsError(try parser.parseLength("asd"))
        XCTAssertThrowsError(try parser.parseLength(" "))
        XCTAssertThrowsError(try parser.parseLength("-25"))
    }
    
    func testBool() {
        XCTAssertEqual(try parser.parseBool("false"), false)
        XCTAssertEqual(try parser.parseBool("FALSE"), false)
        XCTAssertEqual(try parser.parseBool("true"), true)
        XCTAssertEqual(try parser.parseBool("TRUE"), true)
        XCTAssertEqual(try parser.parseBool("1"), true)
        XCTAssertEqual(try parser.parseBool("0"), false)
    
        XCTAssertThrowsError(try parser.parseBool("asd"))
        XCTAssertThrowsError(try parser.parseBool("yes"))
    }
    
    func testColor() {
        XCTAssertEqual(try parser.parseColor("none"), .none)
        XCTAssertEqual(try parser.parseColor("black"), .keyword(.black))
        XCTAssertEqual(try parser.parseColor("red"), .keyword(.red))
        
        XCTAssertEqual(try parser.parseColor("rgb(10,20,30)"), .rgbi(10, 20, 30))
        XCTAssertEqual(try parser.parseColor("rgb(10%,20%,100%)"), .rgbf(0.1, 0.2, 1.0))
        XCTAssertEqual(try parser.parseColor("#AAFF00"), .hex(170, 255, 0))
        
        XCTAssertThrowsError(try parser.parseColor("Ns "))
        XCTAssertThrowsError(try parser.parseColor("d"))
    }
    
    func testUrl() {
        XCTAssertEqual(try parser.parseUrl("#testingId").fragment, "testingId")
        XCTAssertEqual(try parser.parseUrl("http://www.google.com").host, "www.google.com")
        
        //XCTAssertThrowsError(try parser.parseUrl("www.google.com"))
        //XCTAssertThrowsError(try parser.parseUrl("sd"))
    }
    
    func testUrlSelector() {
        XCTAssertEqual(try parser.parseUrlSelector("url(#testingId)").fragment, "testingId")
        XCTAssertEqual(try parser.parseUrlSelector("url(http://www.google.com)").host, "www.google.com")
    }
    
    func testPoints() {
        XCTAssertEqual(try parser.parsePoints("0 1 2 3"), [DOM.Point(0, 1), DOM.Point(2, 3)])
        XCTAssertEqual(try parser.parsePoints("0,1 2,3"), [DOM.Point(0, 1), DOM.Point(2, 3)])
        XCTAssertEqual(try parser.parsePoints("0 1.5 1e4 2.4"), [DOM.Point(0, 1.5), DOM.Point(1e4, 2.4)])
      //  XCTAssertEqual(try parser.parsePoints("0 1 2 3 5.0 6.5"), [0, 1 ,2])
    }
    
    func testRaw() {
        XCTAssertEqual(try parser.parseRaw("evenodd"), DOM.FillRule.evenodd)
        XCTAssertEqual(try parser.parseRaw("round"), DOM.LineCap.round)
        XCTAssertEqual(try parser.parseRaw("miter"), DOM.LineJoin.miter)
        
        XCTAssertThrowsError((try parser.parseRaw("sd")) as DOM.LineJoin)
    }
}



