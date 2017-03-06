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
    
    func testParserOrder() {
       let parser = XMLParser.ValueParser()
        
       let att = XMLParser.Attributes(parser: parser,
                                       element: ["x": "10", "y": "20.0", "fill": "red"],
                                       style:  ["x": "d", "fill": "green"])
        
        //parse from style
        XCTAssertEqual(try att.parseColor("fill"), .keyword(.green))
        XCTAssertThrowsError(try att.parseFloat("x"))
        
        //missing throws error
        XCTAssertThrowsError(try att.parseFloat("other"))
        //missing returns optional
        XCTAssertNil(try att.parseFloat("other") as DOM.Float?)
        
        //fall through to element
        XCTAssertEqual(try att.parseFloat("y"), 20)
        
        //SkipInvalidAttributes
        let another = XMLParser.Attributes(parser: parser,
                                            options: [.skipInvalidAttributes],
                                            element: att.element,
                                            style:  att.style)
        
        
        XCTAssertEqual(try another.parseColor("fill"), .keyword(.green))
        XCTAssertEqual(try another.parseFloat("x"), 10)
        XCTAssertEqual(try another.parseFloat("y"), 20)
        
        //missing throws error
        XCTAssertThrowsError(try another.parseFloat("other"))
        //missing returns optional
        XCTAssertNil(try another.parseFloat("other") as DOM.Float?)
        //invalid returns optional
        XCTAssertNil(try another.parseColor("x") as DOM.Color?)
    }
    
    func testDictionary() {
        let att = ["x": "20", "y": "30", "fill": "#a0a0a0", "display": "none", "some": "random"]
        
        XCTAssertEqual(try att.parseCoordinate("x"), 20.0)
        XCTAssertEqual(try att.parseCoordinate("y"), 30.0)
        XCTAssertEqual(try att.parseColor("fill"), .hex(160, 160, 160))
        XCTAssertEqual(try att.parseRaw("display"), DOM.DisplayMode.none)
        
        XCTAssertThrowsError(try att.parseFloat("other"))
        XCTAssertThrowsError(try att.parseColor("some"))
        
        //missing returns optional
        XCTAssertNil(try att.parseFloat("other") as DOM.Float?)
    }
}


//Allow Dictionary to become an attribute parser
extension Dictionary: AttributeParser {
    public var parser: AttributeValueParser { return XMLParser.ValueParser() }
    public var options: SwiftVG.XMLParser.Options { return [] }
    
    public func parse<T>(_ key: String, _ exp: (String) throws -> T) throws -> T {
        guard let dict = self as? [String: String],
              let value = dict[key] else { throw XMLParser.Error.missingAttribute(name: key) }
        
        return try exp(value)
    }
}



