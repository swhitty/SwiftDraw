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


import XCTest
@testable import DOM

final class ParserGraphicAttributeTests: XCTestCase {

    func testPresentationAttributes() throws {
        var parsed = try XMLParser().parsePresentationAttributes([:])
        XCTAssertNil(parsed.opacity)
        XCTAssertNil(parsed.display)
        XCTAssertNil(parsed.stroke)
        XCTAssertNil(parsed.strokeWidth)
        XCTAssertNil(parsed.strokeOpacity)
        XCTAssertNil(parsed.strokeLineCap)
        XCTAssertNil(parsed.strokeLineJoin)
        XCTAssertNil(parsed.strokeDashArray)
        XCTAssertNil(parsed.fill)
        XCTAssertNil(parsed.fillOpacity)
        XCTAssertNil(parsed.fillRule)
        XCTAssertNil(parsed.transform)
        XCTAssertNil(parsed.clipPath)
        XCTAssertNil(parsed.mask)

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
                   "filter": "url(#blur)"]

        parsed = try XMLParser().parsePresentationAttributes(att)

        XCTAssertEqual(parsed.opacity, 0.95)
        XCTAssertEqual(parsed.display!, .none)
        XCTAssertEqual(parsed.stroke, .color(.keyword(.green)))
        XCTAssertEqual(parsed.strokeWidth, 15)
        XCTAssertEqual(parsed.strokeOpacity, 0.756)
        XCTAssertEqual(parsed.strokeLineCap, .butt)
        XCTAssertEqual(parsed.strokeLineJoin, .miter)
        XCTAssertEqual(parsed.strokeDashArray!, [1, 5, 10])
        XCTAssertEqual(parsed.fill, .color(.keyword(.purple)))
        XCTAssertEqual(parsed.fillOpacity, 0.25)
        XCTAssertEqual(parsed.fillRule, .evenodd)
        XCTAssertEqual(parsed.transform!, [.scale(sx: 15, sy: 15)])
        XCTAssertEqual(parsed.clipPath?.fragmentID, "circlePath")
        XCTAssertEqual(parsed.mask?.fragmentID, "fancyMask")
        XCTAssertEqual(parsed.filter?.fragmentID, "blur")
    }

    func testCircle() throws {
        let el = XML.Element("circle", style: "clip-path: url(#cp1); cx:10;cy:10;r:10; fill:black; stroke-width:2")

        let parsed = try XMLParser().parseGraphicsElement(el)
        let circle = parsed as? DOM.Circle
        XCTAssertNotNil(circle)
        XCTAssertEqual(circle?.style.clipPath?.fragmentID, "cp1")
        XCTAssertEqual(circle?.style.fill, .color(.keyword(.black)))
        XCTAssertEqual(circle?.style.strokeWidth, 2)
    }

    func testDisplayMode() {
        let parser = XMLParser.ValueParser()

        XCTAssertEqual(try parser.parseRaw("none"), DOM.DisplayMode.none)
        XCTAssertEqual(try parser.parseRaw("  none  "), DOM.DisplayMode.none)
        XCTAssertThrowsError(try parser.parseRaw("ds") as DOM.DisplayMode )
    }

    func testStrokeLineCap() {
        let parser = XMLParser.ValueParser()

        XCTAssertEqual(try parser.parseRaw("butt"), DOM.LineCap.butt)
        XCTAssertEqual(try parser.parseRaw("  round"), DOM.LineCap.round)
        XCTAssertThrowsError(try parser.parseRaw("squdare") as DOM.LineCap)
    }

    func testStrokeLineJoin() {
        let parser = XMLParser.ValueParser()

        XCTAssertEqual(try parser.parseRaw("miter"), DOM.LineJoin.miter)
        XCTAssertEqual(try parser.parseRaw("  bevel"), DOM.LineJoin.bevel)
        XCTAssertThrowsError(try parser.parseRaw("ds") as DOM.LineJoin)
    }
}

