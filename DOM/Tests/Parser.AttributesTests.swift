//
//  AttributeParserTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 6/3/17.
//  Copyright 2020 Simon Whitty
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

@testable import SwiftDrawDOM
import Testing
import Foundation

struct AttributeParserTests {

    @Test
    func parserOrder() throws {
        let parser = XMLParser.ValueParser()
        
        let att = XMLParser.Attributes(parser: parser,
                                       element: ["x": "10", "y": "20.0", "fill": "red"],
                                       style:  ["x": "d", "fill": "green"])
        
        //parse from style
        #expect(try att.parseColor("fill") == .keyword(.green))
        #expect(throws: (any Error).self) {
            try att.parseFloat("x")
        }

        //missing throws error
        #expect(throws: (any Error).self) {
            try att.parseFloat("other")
        }
        //missing returns optional
        #expect(try att.parseFloat("other") as DOM.Float? == nil)

        //fall through to element
        #expect(try att.parseFloat("y") == 20)

        //SkipInvalidAttributes
        let another = XMLParser.Attributes(parser: parser,
                                           options: [.skipInvalidAttributes],
                                           element: att.element,
                                           style:  att.style)
        
        
        #expect(try another.parseColor("fill") == .keyword(.green))
        #expect(try another.parseFloat("x") == 10)
        #expect(try another.parseFloat("y") == 20)

        //missing throws error
        #expect(throws: (any Error).self) {
            try another.parseFloat("other")
        }
        //missing returns optional
        #expect(try another.parseFloat("other") as DOM.Float? == nil)
        //invalid returns optional
        #expect(try another.parseColor("x") as DOM.Color? == nil)
    }

    @Test
    func dictionary() throws {
        let att = ["x": "20", "y": "30", "fill": "#a0a0a0", "display": "none", "some": "random"]
        
        #expect(try att.parseCoordinate("x") == 20.0)
        #expect(try att.parseCoordinate("y") == 30.0)
        #expect(try att.parseColor("fill") == .hex(160, 160, 160))
        #expect(try att.parseRaw("display") == DOM.DisplayMode.none)

        #expect(throws: (any Error).self) {
            try att.parseFloat("other")
        }
        #expect(throws: (any Error).self) {
            try att.parseColor("some")
        }

        //missing returns optional
        #expect(try att.parseFloat("other") as DOM.Float? == nil)
    }

    @Test
    func parseString() throws {
        let att = ["x": "20", "some": "random"]
        #expect(try att.parseString("x") == "20")
        #expect(throws: (any Error).self) {
            try att.parseString("missing")
        }
    }

    @Test
    func parseFloat() throws {
        let att = ["x": "20", "some": "random"]
        #expect(try att.parseFloat("x") == 20.0)
        #expect(try att.parseFloat("missing") == nil)
        #expect(throws: (any Error).self) {
            try att.parseFloat("some")
        }
    }

    @Test
    func parseFloats() throws {
        let att = ["x": "20 30 40", "some": "random"]
        #expect(try att.parseFloats("x") == [20.0, 30.0, 40.0])
        #expect(throws: (any Error).self) {
            try att.parseFloats("some")
        }
    }
    
    @Test
    func parsePoints() throws {
        let att = ["x": "20 30 40 50", "some": "random"]
        #expect(try att.parsePoints("x") == [DOM.Point(20, 30), DOM.Point(40, 50)])
        #expect(try att.parsePoints("missing") == nil)
        #expect(throws: (any Error).self) {
            try att.parsePoints("some")
        }
        #expect(throws: (any Error).self) {
            try att.parsePoints("some") as [DOM.Point]?
        }
    }
    
    @Test
    func parseLength() throws {
        let att = ["x": "20", "y": "aa"]
        #expect(try att.parseLength("x") == 20)
        #expect(try att.parseLength("missing") == nil)
        #expect(throws: (any Error).self) {
            try att.parseLength("y")
        }
        #expect(throws: (any Error).self) {
            try att.parseLength("y") as DOM.Length?
        }
    }
    
    @Test
    func parseBool() throws {
        let att = ["x": "true", "y": "5"]
        #expect(try att.parseBool("x") == true)
        #expect(try att.parseBool("missing") == nil)
        #expect(throws: (any Error).self) {
            try att.parseBool("y")
        }
        #expect(throws: (any Error).self) {
            try att.parseBool("y") as Bool?
        }
    }
    
    @Test
    func parseURL() throws {
        let att = ["clip": "http://www.test.com", "mask": "20 twenty"]
        #expect(try att.parseUrl("clip") == URL(string: "http://www.test.com"))
        #expect(try att.parseUrl("missing") == nil)
        #expect(throws: (any Error).self) {
            try att.parseUrl(" ")
        }
    }
    
    @Test
    func parseURLSelector() throws {
        let att = ["clip": "url(#shape)", "mask": "aa"]
        #expect(try att.parseUrlSelector("clip") == URL(string: "#shape"))
        #expect(try att.parseUrlSelector("missing") == nil)
        #expect(throws: (any Error).self) {
            try att.parseUrlSelector("mask")
        }
    }
}

