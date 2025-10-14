//
//  Parser.XML.PatternTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 26/3/19.
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

import Testing
@testable import SwiftDrawDOM

private typealias Coordinate = DOM.Coordinate

@Suite("Parser XML Pattern Tests")
struct ParserXMLPatternTests {

    @Test
    func pattern() throws {
        let pattern = try XMLParser().parsePattern(["id": "p1", "width": "10", "height": "20"])

        #expect(pattern.id == "p1")
        #expect(pattern.width == 10)
        #expect(pattern.height == 20)

        #expect(throws: (any Error).self) {
            _ = try XMLParser().parsePattern(["width": "10", "height": "20"])
        }
        #expect(throws: (any Error).self) {
            _ = try XMLParser().parsePattern(["id": "p1", "height": "20"])
        }
        #expect(throws: (any Error).self) {
            _ = try XMLParser().parsePattern(["id": "p1", "width": "10"])
        }
    }

    @Test
    func patternUnits() throws {
        var node = ["id": "p1", "width": "10", "height": "20"]

        var pattern = try XMLParser().parsePattern(node)
        #expect(pattern.patternUnits == nil)

        node["patternUnits"] = "userSpaceOnUse"
        pattern = try XMLParser().parsePattern(node)
        #expect(pattern.patternUnits == .userSpaceOnUse)

        node["patternUnits"] = "objectBoundingBox"
        pattern = try XMLParser().parsePattern(node)
        #expect(pattern.patternUnits == .objectBoundingBox)

        node["patternUnits"] = "invalid"
        #expect(throws: (any Error).self) {
            _ = try XMLParser().parsePattern(node)
        }
    }

    @Test
    func patternContentUnits() throws {
        var node = ["id": "p1", "width": "10", "height": "20"]

        var pattern = try XMLParser().parsePattern(node)
        #expect(pattern.patternContentUnits == nil)

        node["patternContentUnits"] = "userSpaceOnUse"
        pattern = try XMLParser().parsePattern(node)
        #expect(pattern.patternContentUnits == .userSpaceOnUse)

        node["patternContentUnits"] = "objectBoundingBox"
        pattern = try XMLParser().parsePattern(node)
        #expect(pattern.patternContentUnits == .objectBoundingBox)

        node["patternContentUnits"] = "invalid"
        #expect(throws: (any Error).self) {
            _ = try XMLParser().parsePattern(node)
        }
    }
}
