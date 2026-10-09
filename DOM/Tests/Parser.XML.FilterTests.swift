//
//  Parser.XML.FilterTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 16/8/22.
//  Copyright 2022 Simon Whitty
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


import Foundation

@testable import SwiftDrawDOM
import Testing

struct ParserXMLFilterTests {

    @Test
    func parseFilters() throws {
        let child = XML.Element(name: "child")
        child.children = [XML.Element.makeMockFilter(), XML.Element.makeMockFilter()]

        let parent = XML.Element(name: "parent")
        parent.children = [XML.Element.makeMockFilter(), child]

        #expect(try XMLParser().parseFilters(child).count == 2)
        #expect(try XMLParser().parseFilters(parent).count == 3)
    }

    @Test
    func parseEffect() throws {
        let element = XML.Element.makeMockFilter(id: "blur")

        element.children = [
            .makeElement("feGaussianBlur", ["stdDeviation": "0.5"]),
            .makeElement("other")
        ]

        let filter = try XMLParser().parseFilter(element)
        #expect(filter.id == "blur")
        #expect(filter.effects == [.gaussianBlur(stdDeviation: 0.5)])
    }

    @Test
    func parseBlurTwoValues() throws {
        let element = XML.Element.makeMockFilter()
        element.children = [.makeElement("feGaussianBlur", ["stdDeviation": "3 1.5"])]

        let filter = try XMLParser().parseFilter(element)
        #expect(filter.effects == [.gaussianBlur(stdDeviation: 3, stdDeviationY: 1.5)])
    }

    @Test
    func parseBlurMissingOrInvalidDeviationIsZero() throws {
        let element = XML.Element.makeMockFilter()
        element.children = [
            .makeElement("feGaussianBlur"),
            .makeElement("feGaussianBlur", ["stdDeviation": "abc"])
        ]

        let filter = try XMLParser().parseFilter(element)
        #expect(filter.effects == [.gaussianBlur(stdDeviation: 0), .gaussianBlur(stdDeviation: 0)])
    }

    @Test
    func parseRegionAndUnits() throws {
        let element = XML.Element(name: "filter", attributes: [
            "id": "f",
            "x": "-0.2", "y": "-20%", "width": "140%", "height": "1.4",
            "filterUnits": "objectBoundingBox",
            "primitiveUnits": "objectBoundingBox"
        ])

        let filter = try XMLParser().parseFilter(element)
        #expect(filter.x == -0.2)
        #expect(filter.y == -0.2)
        #expect(filter.width == 1.4)
        #expect(filter.height == 1.4)
        #expect(filter.filterUnits == .objectBoundingBox)
        #expect(filter.primitiveUnits == .objectBoundingBox)
    }

    @Test
    func parseInvalidRegionKeepsDefaults() throws {
        let element = XML.Element(name: "filter", attributes: [
            "id": "f", "x": "left", "filterUnits": "bogus"
        ])

        let filter = try XMLParser().parseFilter(element)
        #expect(filter.x == nil)
        #expect(filter.filterUnits == nil)
    }

    @Test
    func parseUnknownPrimitiveIsUnsupported() throws {
        let element = XML.Element.makeMockFilter()
        element.children = [
            .makeElement("feTurbulence", ["baseFrequency": "0.1"]),
            .makeElement("desc")
        ]

        let filter = try XMLParser().parseFilter(element)
        #expect(filter.effects == [.unsupported(name: "feTurbulence")])
    }

    // SD12: inputs and results are recorded as written; LayerTree resolves the references
    @Test
    func parseInputChain() throws {
        let element = XML.Element.makeMockFilter()
        element.children = [
            .makeElement("feGaussianBlur", ["in": "SourceGraphic", "stdDeviation": "1", "result": "a"]),
            .makeElement("feGaussianBlur", ["in": "a", "stdDeviation": "2"]),
            .makeElement("feGaussianBlur", ["in": "SourceAlpha", "stdDeviation": "3"])
        ]

        let filter = try XMLParser().parseFilter(element)
        #expect(filter.effects == [
            .gaussianBlur(stdDeviation: 1),
            .gaussianBlur(stdDeviation: 2),
            .gaussianBlur(stdDeviation: 3)
        ])
        #expect(filter.primitives.map(\.inputs) == [[.sourceGraphic], [.result("a")], [.sourceAlpha]])
        #expect(filter.primitives.map(\.result) == ["a", nil, nil])
    }

    @Test
    func parseInputKeywords() {
        #expect(XMLParser.parseFilterInput(nil) == nil)
        #expect(XMLParser.parseFilterInput(" ") == nil)
        #expect(XMLParser.parseFilterInput("SourceGraphic") == .sourceGraphic)
        #expect(XMLParser.parseFilterInput("SourceAlpha") == .sourceAlpha)
        #expect(XMLParser.parseFilterInput("BackgroundImage") == .backgroundImage)
        #expect(XMLParser.parseFilterInput("BackgroundAlpha") == .backgroundAlpha)
        #expect(XMLParser.parseFilterInput("FillPaint") == .fillPaint)
        #expect(XMLParser.parseFilterInput("StrokePaint") == .strokePaint)
        // keywords are case-sensitive: anything else names a result
        #expect(XMLParser.parseFilterInput("sourcegraphic") == .result("sourcegraphic"))
        #expect(XMLParser.parseFilterInput(" blur ") == .result("blur"))
    }

    @Test
    func parseOffset() throws {
        let element = XML.Element.makeMockFilter()
        element.children = [
            .makeElement("feOffset", ["dx": "2", "dy": "-3.5", "in": "SourceAlpha", "result": "o"]),
            .makeElement("feOffset", ["dy": "4"]),
            .makeElement("feOffset", ["dx": "abc", "dy": "1e60"])
        ]

        let filter = try XMLParser().parseFilter(element)
        #expect(filter.effects == [.offset(dx: 2, dy: -3.5), .offset(dx: 0, dy: 4), .offset(dx: 0, dy: 0)])
        #expect(filter.primitives[0].inputs == [.sourceAlpha])
        #expect(filter.primitives[1].inputs == [nil])
    }

    @Test
    func parseFlood() throws {
        let element = XML.Element(name: "filter", attributes: ["id": "f", "color": "blue"])
        element.children = [
            .makeElement("feFlood", ["flood-color": "red", "flood-opacity": "0.5"]),
            .makeElement("feFlood", ["style": "flood-color:rgb(0,0,255);flood-opacity:40%"]),
            .makeElement("feFlood"),
            .makeElement("feFlood", ["flood-color": "none", "flood-opacity": "2"]),
            .makeElement("feFlood", ["flood-color": "currentColor"]),
            .makeElement("feFlood", ["flood-color": "currentColor", "color": "lime"])
        ]

        let filter = try XMLParser().parseFilter(element)
        #expect(filter.effects == [
            .flood(color: .keyword(.red), opacity: 0.5),
            .flood(color: .rgbi(0, 0, 255, 1), opacity: 0.4),
            .flood(color: .keyword(.black), opacity: 1),
            .flood(color: .keyword(.black), opacity: 1),
            .flood(color: .keyword(.blue), opacity: 1),
            .flood(color: .keyword(.lime), opacity: 1)
        ])
        // feFlood has no input
        #expect(filter.primitives[0].inputs == [])
    }

    @Test
    func parseComposite() throws {
        let element = XML.Element.makeMockFilter()
        element.children = [
            .makeElement("feComposite", ["in": "SourceGraphic", "in2": "a"]),
            .makeElement("feComposite", ["operator": "in"]),
            .makeElement("feComposite", ["operator": "out"]),
            .makeElement("feComposite", ["operator": "atop"]),
            .makeElement("feComposite", ["operator": "xor"]),
            .makeElement("feComposite", ["operator": "lighter"]),
            .makeElement("feComposite", ["operator": "arithmetic", "k2": "-1", "k3": "1", "k4": "x"]),
            .makeElement("feComposite", ["operator": "plus"])
        ]

        let filter = try XMLParser().parseFilter(element)
        #expect(filter.effects == [
            .composite(.over), .composite(.in), .composite(.out), .composite(.atop), .composite(.xor),
            .composite(.lighter), .composite(.arithmetic(k1: 0, k2: -1, k3: 1, k4: 0)), .composite(.over)
        ])
        #expect(filter.primitives[0].inputs == [.sourceGraphic, .result("a")])
        #expect(filter.primitives[1].inputs == [nil, nil])
    }

    @Test
    func parseMerge() throws {
        let merge = XML.Element.makeElement("feMerge", ["result": "m"])
        merge.children = [
            .makeElement("feMergeNode", ["in": "shadow"]),
            .makeElement("desc"),
            .makeElement("feMergeNode"),
            .makeElement("feMergeNode", ["in": "SourceGraphic"])
        ]
        let element = XML.Element.makeMockFilter()
        element.children = [merge]

        let filter = try XMLParser().parseFilter(element)
        #expect(filter.effects == [.merge])
        #expect(filter.primitives[0].inputs == [.result("shadow"), nil, .sourceGraphic])
        #expect(filter.primitives[0].result == "m")
    }

    @Test
    func parseBlend() throws {
        let element = XML.Element.makeMockFilter()
        element.children = [
            .makeElement("feBlend", ["in": "SourceGraphic", "in2": "BackgroundImage"]),
            .makeElement("feBlend", ["mode": "multiply"]),
            .makeElement("feBlend", ["mode": "color-dodge"]),
            .makeElement("feBlend", ["mode": "luminosity"]),
            .makeElement("feBlend", ["mode": "plus-darker"])
        ]

        let filter = try XMLParser().parseFilter(element)
        #expect(filter.effects == [
            .blend(.normal), .blend(.multiply), .blend(.colorDodge), .blend(.luminosity), .blend(.normal)
        ])
        #expect(filter.primitives[0].inputs == [.sourceGraphic, .backgroundImage])
    }

    @Test
    func parseColorMatrix() throws {
        let identity: [DOM.Float] = [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0]
        let hardAlpha: [DOM.Float] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 127, 0]
        let element = XML.Element.makeMockFilter()
        element.children = [
            // Figma's hard alpha, commas and newlines allowed
            .makeElement("feColorMatrix", ["in": "SourceAlpha", "type": "matrix",
                                           "values": "0 0 0 0 0 0 0 0 0 0 0 0 0 0 0,\n0 0 0 127 0"]),
            .makeElement("feColorMatrix"),
            .makeElement("feColorMatrix", ["values": "1 2 3"]),
            .makeElement("feColorMatrix", ["type": "saturate", "values": "0.25"]),
            .makeElement("feColorMatrix", ["type": "saturate"]),
            .makeElement("feColorMatrix", ["type": "saturate", "values": "1 2"]),
            .makeElement("feColorMatrix", ["type": "hueRotate", "values": "90"]),
            .makeElement("feColorMatrix", ["type": "hueRotate"]),
            .makeElement("feColorMatrix", ["type": "luminanceToAlpha"]),
            .makeElement("feColorMatrix", ["type": "sepia", "values": "1"])
        ]

        let filter = try XMLParser().parseFilter(element)
        #expect(filter.effects == [
            .colorMatrix(.matrix(hardAlpha)),
            .colorMatrix(.matrix(identity)),
            .colorMatrix(.matrix(identity)),
            .colorMatrix(.saturate(0.25)),
            .colorMatrix(.saturate(1)),
            .colorMatrix(.saturate(1)),
            .colorMatrix(.hueRotate(90)),
            .colorMatrix(.hueRotate(0)),
            .colorMatrix(.luminanceToAlpha),
            .colorMatrix(.matrix(identity))
        ])
    }

    @Test
    func parseSubregionInUserSpace() throws {
        let svg = try DOM.SVG.parse(xml: #"""
        <svg width="200" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="f">
                <feFlood x="10" y="5mm" width="50%" height="25%" />
                <feOffset dx="1" />
            </filter>
        </svg>
        """#)

        let primitives = try #require(svg.defs.filters.first?.primitives)
        #expect(primitives[0].x == 10)
        #expect(abs((primitives[0].y ?? 0) - 18.897638) < 0.001)
        // percentages of the viewport
        #expect(primitives[0].width == 100)
        #expect(primitives[0].height == 25)
        #expect(primitives[1].x == nil)
        #expect(primitives[1].width == nil)
    }

    @Test
    func parseSubregionInBoundingBoxUnits() throws {
        let element = XML.Element(name: "filter", attributes: ["id": "f", "primitiveUnits": "objectBoundingBox"])
        element.children = [.makeElement("feFlood", ["x": "25%", "y": "0.5", "width": "abc", "height": "-1"])]

        let filter = try XMLParser().parseFilter(element)
        #expect(filter.primitives[0].x == 0.25)
        #expect(filter.primitives[0].y == 0.5)
        #expect(filter.primitives[0].width == nil)
        #expect(filter.primitives[0].height == -1)
    }

    @Test
    func parseColorInterpolationFilters() throws {
        let svg = try DOM.SVG.parse(xml: #"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="initial"><feOffset /></filter>
            <filter id="inkscape" style="color-interpolation-filters:sRGB">
                <feOffset />
                <feOffset color-interpolation-filters="linearRGB" />
                <feOffset color-interpolation-filters="bogus" />
            </filter>
            <filter id="figma" color-interpolation-filters="sRGB"><feOffset style="color-interpolation-filters: auto" /></filter>
            <g color-interpolation-filters="sRGB">
                <filter id="inherited"><feOffset /></filter>
            </g>
        </svg>
        """#)

        let spaces = svg.defs.filters.map { ($0.id, $0.primitives.map(\.colorInterpolation)) }
        #expect(spaces.map(\.0) == ["initial", "inkscape", "figma", "inherited"])
        #expect(spaces.map(\.1) == [[.linearRGB], [.sRGB, .linearRGB, .sRGB], [.auto], [.sRGB]])
    }

    // an unreadable attribute drops the attribute, never the filter or the document
    @Test
    func parseInvalidPrimitiveAttributesKeepDocument() throws {
        let svg = try DOM.SVG.parse(xml: #"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="f">
                <feFlood flood-color="var(--x)" flood-opacity="half" x="left" />
                <feComposite operator="" k1="none" in2="" />
                <feBlend mode="" />
                <feColorMatrix type="" values="a b c" />
                <feOffset dx="" dy="1px" />
            </filter>
            <rect width="10" height="10" filter="url(#f)" />
        </svg>
        """#)

        let filter = try #require(svg.defs.filters.first)
        #expect(filter.effects == [
            .flood(color: .keyword(.black), opacity: 1),
            .composite(.over),
            .blend(.normal),
            .colorMatrix(.matrix([1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0])),
            .offset(dx: 0, dy: 1)
        ])
        #expect(filter.primitives[1].inputs == [nil, nil])
        #expect(svg.childElements.count == 1)
    }
}

private extension XML.Element {

    static func makeMockFilter(id: String = "mock") -> XML.Element {
        return XML.Element(name: "filter", attributes: ["id": id])
    }

    static func makeElement(_ name: String, _ attributes: [String: String] = [:]) -> XML.Element {
        return XML.Element(name: name, attributes: attributes)
    }
}
