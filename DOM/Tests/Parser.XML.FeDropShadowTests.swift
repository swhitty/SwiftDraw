//
//  Parser.XML.FeDropShadowTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 15/11/26.
//  Copyright 2026 Simon Whitty
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

// Filter Effects 1 §9.12 feDropShadow
struct ParserXMLFeDropShadowTests {

    typealias DropShadow = DOM.Filter.DropShadow

    @Test
    func defaults() throws {
        let filter = try parseFilter(#"<filter id="f"><feDropShadow /></filter>"#)
        #expect(filter.effects == [.dropShadow(DropShadow(dx: 2, dy: 2, stdDeviation: 2, stdDeviationY: nil,
                                                          color: .keyword(.black), opacity: 1))])
        #expect(filter.primitives[0].inputs == [nil])
    }

    @Test
    func attributes() throws {
        let filter = try parseFilter(#"""
        <filter id="f">
            <feDropShadow dx="-3" dy="4.5" stdDeviation="1.5" flood-color="red" flood-opacity="0.25" />
        </filter>
        """#)
        #expect(filter.effects == [.dropShadow(DropShadow(dx: -3, dy: 4.5, stdDeviation: 1.5,
                                                          color: .keyword(.red), opacity: 0.25))])
    }

    @Test(arguments: [
        ("3 1", DropShadow(stdDeviation: 3, stdDeviationY: 1)),
        ("0 4", DropShadow(stdDeviation: 0, stdDeviationY: 4)),
        ("0", DropShadow(stdDeviation: 0)),
        // unreadable: the default 2
        ("abc", DropShadow()),
        ("1 2 3", DropShadow()),
        ("", DropShadow())
    ])
    func stdDeviation(value: String, expected: DropShadow) throws {
        let filter = try parseFilter(#"<filter id="f"><feDropShadow stdDeviation="\#(value)" /></filter>"#)
        #expect(filter.effects == [.dropShadow(expected)])
    }

    @Test
    func invalidOffsetKeepsDefault() throws {
        let filter = try parseFilter(#"<filter id="f"><feDropShadow dx="abc" dy="5" /></filter>"#)
        #expect(filter.effects == [.dropShadow(DropShadow(dx: 2, dy: 5))])
    }

    @Test
    func floodFromStyle() throws {
        let filter = try parseFilter(#"""
        <filter id="f">
            <feDropShadow style="flood-color: rgb(0, 0, 255); flood-opacity: 40%" />
            <feDropShadow flood-color="none" flood-opacity="2" />
        </filter>
        """#)
        #expect(filter.effects == [
            .dropShadow(DropShadow(color: .rgbi(0, 0, 255, 1), opacity: 0.4)),
            .dropShadow(DropShadow(color: .keyword(.black), opacity: 1))
        ])
    }

    @Test
    func floodCurrentColor() throws {
        let filter = try parseFilter(#"""
        <filter id="f" color="blue">
            <feDropShadow flood-color="currentColor" />
            <feDropShadow flood-color="currentColor" color="lime" />
        </filter>
        """#)
        #expect(filter.effects == [
            .dropShadow(DropShadow(color: .keyword(.blue))),
            .dropShadow(DropShadow(color: .keyword(.lime)))
        ])
    }

    @Test
    func wiringSubregionAndColorInterpolation() throws {
        let filter = try parseFilter(#"""
        <filter id="f" primitiveUnits="objectBoundingBox" color-interpolation-filters="sRGB">
            <feGaussianBlur result="blur" />
            <feDropShadow in="blur" result="shadow" x="10%" width="0.5" />
            <feDropShadow in="SourceAlpha" color-interpolation-filters="linearRGB" />
        </filter>
        """#)
        let shadow = filter.primitives[1]
        #expect(shadow.inputs == [.result("blur")])
        #expect(shadow.result == "shadow")
        #expect(shadow.x == 0.1)
        #expect(shadow.width == 0.5)
        #expect(shadow.y == nil)
        #expect(shadow.colorInterpolation == .sRGB)
        #expect(filter.primitives[2].inputs == [.sourceAlpha])
        #expect(filter.primitives[2].colorInterpolation == .linearRGB)
    }

    @Test
    func parsedFromDocument() throws {
        let svg = try DOM.SVG.parse(xml: #"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="f"><feDropShadow dx="1" /></filter>
            <rect width="10" height="10" filter="url(#f)" />
        </svg>
        """#)
        #expect(svg.defs.filters.first?.effects == [.dropShadow(DropShadow(dx: 1))])
    }

    func parseFilter(_ xml: String) throws -> DOM.Filter {
        let element = try XML.SAXParser.parse(data: Data(xml.utf8))
        return try XMLParser().parseFilter(element)
    }
}
