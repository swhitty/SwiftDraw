//
//  Parser.SVGTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 3/2/17.
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

struct ParserSVGTests {

    @Test
    func svg() throws {
        let node = XML.Element(name: "svg", attributes: ["width": "100", "height": "200"])
        let parser = DOMXMLParser()

        var parsed = try parser.parseSVG(node)
        let expected = DOM.SVG(width: 100, height: 200)
        #expect(parsed == expected)

        let expected2 = expected
        expected2.viewBox = DOM.SVG.ViewBox(x: 10, y: 20, width: 100, height: 200)
        #expect(parsed != expected2)

        node.attributes["viewBox"] = "10 20 100 200"
        parsed = try parser.parseSVG(node)
        #expect(parsed == expected2)

        expected2.attributes.fill = .color(.keyword(.red))
        #expect(parsed != expected2)
    }

    @Test
    func parseSVGInvalidNode() {
        let node = XML.Element(name: "svg2", attributes: ["width": "100", "height": "200"])
        #expect(throws: (any Error).self) {
            try XMLParser().parseSVG(node)
        }
    }

    @Test
    func parseSVGMissingHeightInvalidNode() {
        let node = XML.Element(name: "svg", attributes: ["width": "100"])
        #expect(throws: (any Error).self) {
            try XMLParser().parseSVG(node)
        }
    }

    @Test
    func parseSVGMissingWidthInvalidNode() {
        let node = XML.Element(name: "svg", attributes: ["height": "100"])
        #expect(throws: (any Error).self) {
            try XMLParser().parseSVG(node)
        }
    }

    @Test
    func viewBox() throws {
        let parsed = try #require(try XMLParser().parseViewBox(" 10\t20  300.0  5e2"))
        #expect(parsed.x == 10)
        #expect(parsed.y == 20)
        #expect(parsed.width == 300)
        #expect(parsed.height == 500)

        #expect(try XMLParser().parseViewBox("10 10 10 10") != nil)
        #expect(throws: (any Error).self) {
            try XMLParser().parseViewBox("10 10 10 10a")
        }
        #expect(throws: (any Error).self) {
            try XMLParser().parseViewBox(" 10\t20  300")
        }
        #expect(throws: (any Error).self) {
            try XMLParser().parseViewBox("10 10 10 10a")
        }
    }

    @Test
    func clipPath() throws {
        let node = XML.Element(name: "clipPath", attributes: ["id": "hello"])

        var parsed = try XMLParser().parseClipPath(node)
        #expect(parsed.id == "hello")

        node.children.append(XML.Element("line", style: "x1:0;y1:0;x2:50;y2:60"))
        node.children.append(XML.Element("circle", style: "cx:0;cy:10;r:20"))

        parsed = try XMLParser().parseClipPath(node)
        #expect(parsed.id == "hello")
        #expect(parsed.childElements.count == 2)
    }

    @Test
    func parseDefs() throws {
        let svg = XML.Element(name: "svg")
        let defs = XML.Element(name: "defs")
        let g = XML.Element(name: "g")
        svg.children.append(defs)
        svg.children.append(g)

        g.children.append(XML.Element("circle", id: "c2", style: "cx:0;cy:10;r:20"))
        let defs1 = XML.Element(name: "defs")
        g.children.append(defs1)
        defs1.children.append(XML.Element("circle", id: "c3", style: "cx:0;cy:10;r:20"))

        defs.children.append(XML.Element("circle", id: "c1", style: "cx:0;cy:10;r:20"))
        svg.children.append(defs1)

        let elements = try DOMXMLParser().parseSVGDefs(svg).elements
        #expect(elements.count == 2)
    }

    @Test
    func use() throws {
        let svg = try DOM.SVG.parse(xml: #"""
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="64" height="64" version="1.1" xmlns="http://www.w3.org/2000/svg">
            <defs>
                <rect id="a" x="10" y="20" width="30" height="40" />
            </defs>
            <circle id="b" cx="50" cy="60" r="70" />
        </svg>
        """#)

        let rect = try #require(svg.firstGraphicsElement(with: "a") as? DOM.Rect)
        #expect(rect.id == "a")

        let circle = try #require(svg.firstGraphicsElement(with: "b") as? DOM.Circle)
        #expect(circle.id == "b")
    }

    @Test
    func missingNamespce() throws {
        let svg = try DOM.SVG.parse(xml: #"""
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="64" height="64" version="1.1">
            <defs>
                <rect id="a" x="10" y="20" width="30" height="40" />
            </defs>
            <circle id="b" cx="50" cy="60" r="70" />
        </svg>
        """#)

        let rect = try #require(svg.firstGraphicsElement(with: "a") as? DOM.Rect)
        #expect(rect.id == "a")

        let circle = try #require(svg.firstGraphicsElement(with: "b") as? DOM.Circle)
        #expect(circle.id == "b")
    }

    @Test
    func deepNestingParses() throws {
        let groupOpen = String(repeating: "<g>", count: 500)
        let groupClose = String(repeating: "</g>", count: 500)

        // If this throws, the test will fail automatically
        _ = try DOM.SVG.parse(xml: #"""
            <?xml version="1.0" encoding="UTF-8"?>
            <svg width="64" height="64" version="1.1">
                \#(groupOpen)
                <circle id="b" cx="50" cy="60" r="70" />
                \#(groupClose)
            </svg>
            """#)
    }
}
