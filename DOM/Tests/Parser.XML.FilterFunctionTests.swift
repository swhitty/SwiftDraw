//
//  Parser.XML.FilterFunctionTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 16/11/26.
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

// Filter Effects 1 §12: the `filter` property as a list of url() references and filter functions
struct ParserXMLFilterFunctionTests {

    typealias Length = DOM.UnitLength

    @Test(arguments: [
        ("blur()", DOM.FilterFunction.blur(Length(0))),
        ("blur(4)", .blur(Length(4))),
        ("blur(4px)", .blur(Length(4, unit: .pixel))),
        ("blur(1mm)", .blur(Length(1, unit: .millimeter))),
        ("blur(0.5em)", .blur(Length(0.5, unit: .em))),
        ("BLUR( 2 )", .blur(Length(2))),
        (
            "drop-shadow(blue 4 5 6)",
            .dropShadow(color: .keyword(.blue), dx: Length(4), dy: Length(5), stdDeviation: Length(6))
        ),
        (
            "drop-shadow(4 5 6 blue)",
            .dropShadow(color: .keyword(.blue), dx: Length(4), dy: Length(5), stdDeviation: Length(6))
        ),
        ("drop-shadow(-4 5)", .dropShadow(color: nil, dx: Length(-4), dy: Length(5), stdDeviation: Length(0))),
        (
            "drop-shadow(currentColor 1 2)",
            .dropShadow(color: nil, dx: Length(1), dy: Length(2), stdDeviation: Length(0))
        ),
        (
            "drop-shadow(red 1em 2mm 3)",
            .dropShadow(
                color: .keyword(.red),
                dx: Length(1, unit: .em),
                dy: Length(2, unit: .millimeter),
                stdDeviation: Length(3)
            )
        ),
        ("hue-rotate()", .hueRotate(degrees: 0)),
        ("hue-rotate(0)", .hueRotate(degrees: 0)),
        ("hue-rotate(45deg)", .hueRotate(degrees: 45)),
        ("hue-rotate(-90deg)", .hueRotate(degrees: -90)),
        ("hue-rotate(50grad)", .hueRotate(degrees: 45)),
        ("hue-rotate(0.25turn)", .hueRotate(degrees: 90)),
        ("hue-rotate(1rad)", .hueRotate(degrees: Float(180 / Double.pi))),
        ("grayscale()", .grayscale(1)),
        ("grayscale(50%)", .grayscale(0.5)),
        ("grayscale(2)", .grayscale(2)),
        ("sepia()", .sepia(1)),
        ("saturate(200%)", .saturate(2)),
        ("invert(0.25)", .invert(0.25)),
        ("opacity(0%)", .opacity(0)),
        ("brightness()", .brightness(1)),
        ("contrast(1.5)", .contrast(1.5)),
    ])
    func function(value: String, function: DOM.FilterFunction) throws {
        #expect(try XMLParser.parseFilterValue(value) == [.function(function)])
    }

    @Test
    func colorFunctionInDropShadow() throws {
        let values = try XMLParser.parseFilterValue("drop-shadow(rgb(0, 0, 255) 1 2)")
        guard case .function(.dropShadow(let color, _, _, _)) = try #require(values.first) else {
            Issue.record("expected drop-shadow")
            return
        }
        #expect(color != nil)
    }

    @Test
    func list() throws {
        #expect(
            try XMLParser.parseFilterValue("url(#a) grayscale()  url('#b')opacity(0.5)") == [
                .url(URL(string: "#a")!),
                .function(.grayscale(1)),
                .url(URL(string: "#b")!),
                .function(.opacity(0.5)),
            ]
        )
    }

    @Test
    func none() throws {
        #expect(try XMLParser.parseFilterValue(" None ") == [])
    }

    // any invalid entry invalidates the whole list
    @Test(arguments: [
        "", "4", "blur", "blur(4", "blur(-5)", "blur(50%)", "blur(4 2)", "blur(red)",
        "drop-shadow()", "drop-shadow(4)", "drop-shadow(red, 10, 15)", "drop-shadow(blue 4 5 6 7)",
        "drop-shadow(blue 3% 4% 5%)", "drop-shadow(1 2 -3)", "drop-shadow(red 1 2 blue)",
        "hue-rotate(45)", "hue-rotate(random)", "hue-rotate(1deg 2deg)",
        "grayscale(-1)", "opacity(1 2)", "saturate(1px)", "unknown(1)", "url()",
        "grayscale() hue-rotate(random) opacity(0.5)", "url(#a), blur(2)",
    ])
    func invalid(value: String) {
        #expect(throws: (any Error).self) { try XMLParser.parseFilterValue(value) }
    }

    @Test
    func invalidAttributeIsDropped() throws {
        let svg = try DOM.SVG.parse(
            xml: #"""
                <svg width="10" height="10" xmlns="http://www.w3.org/2000/svg">
                    <rect id="valid" width="10" height="10" filter="url(#f) blur(2)" />
                    <rect id="invalid" width="10" height="10" filter="url(#f) blur(-2)" />
                </svg>
                """#
        )
        #expect(svg.childElements[0].attributes.filter == [.url(URL(string: "#f")!), .function(.blur(Length(2)))])
        #expect(svg.childElements[1].attributes.filter == nil)
    }

    // an invalid declaration leaves a lower rule in place
    @Test
    func cascade() throws {
        let svg = try DOM.SVG.parse(
            xml: #"""
                <svg width="10" height="10" xmlns="http://www.w3.org/2000/svg">
                    <style>rect { filter: sepia(50%) !important } #b { filter: none }</style>
                    <rect id="a" width="10" height="10" style="filter: blur(-1)" />
                    <rect id="b" width="10" height="10" style="filter: grayscale()" />
                    <rect width="10" height="10" filter="invert()" style="filter: hue-rotate(90deg)" />
                </svg>
                """#
        )
        let attributes = svg.childElements.map { DOM.presentationAttributes(for: $0, styles: svg.styles).filter }
        #expect(
            attributes == [
                [.function(.sepia(0.5))],
                [.function(.sepia(0.5))],
                [.function(.sepia(0.5))],
            ]
        )
    }

    @Test
    func unitLengths() {
        #expect(Length(2).resolve(fontSize: 10) == 2)
        #expect(Length(2, unit: .em).resolve(fontSize: 10) == 20)
        #expect(Length(2, unit: .ex).resolve(fontSize: 10) == 10)
        #expect(Length(25.4, unit: .millimeter).resolve(fontSize: 10) == 96)
        #expect(Length(1, unit: .inch).resolve(fontSize: 10) == 96)
    }
}
