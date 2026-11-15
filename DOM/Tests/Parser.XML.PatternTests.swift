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
    }

    @Test
    func missingOrInvalidGeometryIsDropped() throws {
        // SVG 1.1 §13.3: width/height default to 0, which disables rendering; it must not fail the document
        var pattern = try XMLParser().parsePattern(["id": "p1", "height": "20"])
        #expect(pattern.width == nil)
        #expect(pattern.height == 20)

        pattern = try XMLParser().parsePattern(["id": "p1"])
        #expect(pattern.width == nil)
        #expect(pattern.height == nil)

        pattern = try XMLParser().parsePattern(["id": "p1", "x": "bad", "y": "10%", "width": "50%", "height": "0.25"])
        #expect(pattern.x == nil)
        #expect(pattern.y == 0.1)
        #expect(pattern.width == 0.5)
        #expect(pattern.height == 0.25)
        #expect(pattern.percentageAttributes == ["y", "width"])
    }

    @Test
    func href() throws {
        var pattern = try XMLParser().parsePattern(["id": "p1", "xlink:href": "#base"])
        #expect(pattern.href?.fragmentID == "base")

        pattern = try XMLParser().parsePattern(["id": "p1", "href": "#svg2"])
        #expect(pattern.href?.fragmentID == "svg2")

        pattern = try XMLParser().parsePattern(["id": "p1", "href": "#svg2", "xlink:href": "#old"])
        #expect(pattern.href?.fragmentID == "svg2")

        pattern = try XMLParser().parsePattern(["id": "p1"])
        #expect(pattern.href == nil)
    }

    @Test
    func viewBox() throws {
        var pattern = try XMLParser().parsePattern(["id": "p1", "viewBox": "0 5 10, 20"])
        #expect(pattern.viewBox == DOM.SVG.ViewBox(x: 0, y: 5, width: 10, height: 20))

        pattern = try XMLParser().parsePattern(["id": "p1", "viewBox": "invalid"])
        #expect(pattern.viewBox == nil)
    }

    @Test
    func patternTransform() throws {
        var pattern = try XMLParser().parsePattern(["id": "p1", "patternTransform": "translate(10, 20) scale(2)"])
        #expect(pattern.patternTransform == [.translate(tx: 10, ty: 20), .scale(sx: 2, sy: 2)])

        pattern = try XMLParser().parsePattern(["id": "p1"])
        #expect(pattern.patternTransform == nil)

        pattern = try XMLParser().parsePattern(["id": "p1", "patternTransform": "wobble(3)"])
        #expect(pattern.patternTransform == nil)
    }

    @Test
    func documentKeepsInheritedAndIncompletePatterns() throws {
        let svg = try DOM.SVG.parse(xml: #"""
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="64" height="64">
            <defs>
                <pattern id="base" width="8" height="8" patternUnits="userSpaceOnUse">
                    <rect width="4" height="4" fill="red" />
                </pattern>
                <pattern id="derived" xlink:href="#base" patternTransform="rotate(45)" />
                <pattern width="8" height="8" />
            </defs>
            <rect width="64" height="64" fill="url(#derived)" />
        </svg>
        """#)

        #expect(svg.defs.patterns.map(\.id) == ["base", "derived"])
        let derived = try #require(svg.defs.patterns.last)
        #expect(derived.width == nil)
        #expect(derived.childElements.isEmpty)
        #expect(derived.href?.fragmentID == "base")
        #expect(derived.patternTransform == [.rotate(angle: 45)])
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

        // an unknown value drops the attribute instead of failing the document
        node["patternUnits"] = "invalid"
        pattern = try XMLParser().parsePattern(node)
        #expect(pattern.patternUnits == nil)
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
        pattern = try XMLParser().parsePattern(node)
        #expect(pattern.patternContentUnits == nil)
    }
}
