//
//  StyleTests.swift
//  SwiftVG
//
//  Created by Simon Whitty on 27/2/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

import XCTest
@testable import SwiftVG

class StyleTests: XCTestCase {
    
    func testStyle() {
        AssertAttributeEqual("selector: hi;", ("selector", "hi"))
        AssertAttributeEqual("selector: hi", ("selector", "hi"))
        AssertAttributeEqual("selector: hi ", ("selector", "hi"))
        AssertAttributeEqual(" trans-form : rotate(4)", ("trans-form", "rotate(4)"))
        
        XCTAssertThrowsError(try XMLParser().parseStyleAttribute("selector"))
      // TODO  XCTAssertThrowsError(try XMLParser().parseStyleAttribute("selector:: hi"))
      // TODO  XCTAssertThrowsError(try XMLParser().parseStyleAttribute("sele ctor: hi"))
        XCTAssertThrowsError(try XMLParser().parseStyleAttribute(": hmm"))
    }
    
    func testStyles() throws {
        let e = XML.Element(name: "line")
        e.attributes["x"] = "5"
        e.attributes["y"] = "5"
        e.attributes["stroke-color"] = "black"
        e.attributes["style"] = "fill: red; x: 20"
        
        //Style attributes should override any XML.Element attribute
        let attributes = try XMLParser().parseStyleAttributes(e)
        let expected = ["x": "20", "y": "5", "stroke-color": "black", "fill": "red"]
        
        XCTAssertEqual(attributes, expected)
    }
}

private func AssertAttributeEqual(_ text: String, _ expected: (String, String), file: StaticString = #file, line: UInt = #line) {
    XCTAssertTrue(try XMLParser().parseStyleAttribute(text) == expected, file: file, line: line)
}

extension SwiftVG.XMLParser {
    func parseStyleAttribute(_ text: String) throws -> (String, String) {
        var scanner = Scanner(text: text)
        return try XMLParser().parseStyleAttribute(&scanner)
    }
}
