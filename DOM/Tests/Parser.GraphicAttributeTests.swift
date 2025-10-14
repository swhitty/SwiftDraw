//
//  Parser.GraphicAttributeTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 27/2/17.
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

struct ParserGraphicAttributeTests {

    @Test
    func presentationAttributes() throws {
        var parsed = try XMLParser().parsePresentationAttributes([:])
        #expect(parsed.opacity == nil)
        #expect(parsed.display == nil)
        #expect(parsed.stroke == nil)
        #expect(parsed.strokeWidth == nil)
        #expect(parsed.strokeOpacity == nil)
        #expect(parsed.strokeLineCap == nil)
        #expect(parsed.strokeLineJoin == nil)
        #expect(parsed.strokeDashArray == nil)
        #expect(parsed.fill == nil)
        #expect(parsed.fillOpacity == nil)
        #expect(parsed.fillRule == nil)
        #expect(parsed.transform == nil)
        #expect(parsed.clipPath == nil)
        #expect(parsed.mask == nil)

        let att = ["opacity": "95%",
                   "display": "none",
                   "stroke": "green",
                   "stroke-width": "15.0",
                   "stroke-opacity": "75.6%",
                   "stroke-linecap": "butt",
                   "stroke-linejoin": "miter",
                   "stroke-dasharray": "1 5 10",
                   "fill": "purple",
                   "fill-opacity": "25%",
                   "fill-rule": "evenodd",
                   "transform": "scale(15)",
                   "clip-path": "url(#circlePath)",
                   "mask": "url(#fancyMask)",
                   "filter": "url(#blur)"
        ]

        parsed = try XMLParser().parsePresentationAttributes(att)

        #expect(parsed.opacity == 0.95)
        #expect(parsed.display == DOM.DisplayMode.none)
        #expect(parsed.stroke == .color(.keyword(.green)))
        #expect(parsed.strokeWidth == 15)
        #expect(parsed.strokeOpacity == 0.756)
        #expect(parsed.strokeLineCap == .butt)
        #expect(parsed.strokeLineJoin == .miter)
        #expect(parsed.strokeDashArray == [1, 5, 10])
        #expect(parsed.fill == .color(.keyword(.purple)))
        #expect(parsed.fillOpacity == 0.25)
        #expect(parsed.fillRule == .evenodd)
        #expect(parsed.transform == [.scale(sx: 15, sy: 15)])
        #expect(parsed.clipPath?.fragmentID == "circlePath")
        #expect(parsed.mask?.fragmentID == "fancyMask")
        #expect(parsed.filter?.fragmentID == "blur")
    }

    @Test
    func circle() throws {
        let el = XML.Element("circle", style: "clip-path: url(#cp1); cx:10;cy:10;r:10; fill:black; stroke-width:2")

        let parsed = try XMLParser().parseGraphicsElement(el)
        let circle = parsed as? DOM.Circle
        #expect(circle != nil)
        #expect(circle?.style.clipPath?.fragmentID == "cp1")
        #expect(circle?.style.fill == .color(.keyword(.black)))
        #expect(circle?.style.strokeWidth == 2)
    }

    @Test
    func displayMode() throws {
        let parser = XMLParser.ValueParser()

        #expect(try parser.parseRaw("none") == DOM.DisplayMode.none)
        #expect(try parser.parseRaw("  none  ") == DOM.DisplayMode.none)
        #expect(throws: (any Error).self) {
            try parser.parseRaw("ds") as DOM.DisplayMode
        }
    }

    @Test
    func strokeLineCap() throws {
        let parser = XMLParser.ValueParser()

        #expect(try parser.parseRaw("butt") == DOM.LineCap.butt)
        #expect(try parser.parseRaw("  round") == DOM.LineCap.round)
        #expect(throws: (any Error).self) {
            try parser.parseRaw("squdare") as DOM.LineCap
        }
    }

    @Test
    func strokeLineJoin() throws {
        let parser = XMLParser.ValueParser()

        #expect(try parser.parseRaw("miter") == DOM.LineJoin.miter)
        #expect(try parser.parseRaw("  bevel") == DOM.LineJoin.bevel)
        #expect(throws: (any Error).self) {
            try parser.parseRaw("ds") as DOM.LineJoin
        }
    }
}
