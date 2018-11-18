//
//  AttributeParserTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 6/3/17.
//  Copyright 2017 Simon Whitty
//
//  Distributed under the permissive zlib license
//  Get the latest version from here:
//
//  https://github.com/swhitty/SwiftDraw
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

import XCTest
@testable import SwiftDraw

final class AttributeParserTests: XCTestCase {
    
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
    public var options: SwiftDraw.XMLParser.Options { return [] }
    
    public func parse<T>(_ key: String, _ exp: (String) throws -> T) throws -> T {
        guard let dict = self as? [String: String],
              let value = dict[key] else { throw XMLParser.Error.missingAttribute(name: key) }
        
        return try exp(value)
    }
}



