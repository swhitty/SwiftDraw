//
//  Parser.GraphicAttributeTests.swift
//  SwiftVG
//
//  Created by Simon Whitty on 27/2/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

import XCTest
@testable import SwiftVG

class ParserGraphicAttributeTests: XCTestCase {
    
    func testURLSelector() {
        AssertURLSelector("url(#clipPath1)", "#clipPath1")
        AssertURLSelector("url(#cp1)", "#cp1")
        AssertURLSelector(" url( #cp1 )   ", "#cp1")
    }
    
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
                   "mask": "url(#fancyMask)"]
        
        parsed = try XMLParser().parsePresentationAttributes(att)
        
        XCTAssertEqual(parsed.opacity, 0.95)
        XCTAssertEqual(parsed.display!, .none)
        XCTAssertEqual(parsed.stroke, .keyword(.green))
        XCTAssertEqual(parsed.strokeWidth, 15)
        XCTAssertEqual(parsed.strokeOpacity, 0.756)
        XCTAssertEqual(parsed.strokeLineCap, .butt)
        XCTAssertEqual(parsed.strokeLineJoin, .miter)
        XCTAssertEqual(parsed.strokeDashArray!, [1, 5, 10])
        XCTAssertEqual(parsed.fill, .keyword(.purple))
        XCTAssertEqual(parsed.fillOpacity, 0.25)
        XCTAssertEqual(parsed.fillRule, .evenodd)
        XCTAssertEqual(parsed.transform!, [.scale(sx: 15, sy: 0)])
        XCTAssertEqual(parsed.clipPath?.fragment, "circlePath")
        XCTAssertEqual(parsed.mask?.fragment, "fancyMask")
    }
    
    func testCircle() {
        let el = XML.Element("circle",style: "clip-path: url(#cp1); cx:10;cy:10;r:10; fill:black; stroke-width:2")
        
        let parsed = try? XMLParser().parseGraphicsElement(el)
        let circle = parsed as? DOM.Circle
        XCTAssertNotNil(circle)
        XCTAssertEqual(circle?.clipPath?.fragment, "cp1")
        XCTAssertEqual(circle?.fill, .keyword(.black))
        XCTAssertEqual(circle?.strokeWidth, 2)
    }
    
    func ParseDisplayMode(_ text: String?) throws -> DOM.DisplayMode? {
        let att = Attributes()
        att.element["val"] = text
        return try att.parseRaw("val")
    }
    
    func testDisplayMode() {
        XCTAssertNil(try ParseDisplayMode(nil))
        XCTAssertEqual(try ParseDisplayMode("none"), DOM.DisplayMode.none)
        XCTAssertEqual(try ParseDisplayMode(" none "), DOM.DisplayMode.none)

        XCTAssertThrowsError(try ParseDisplayMode("ds"))
    }
    
    func ParseLineCap(_ text: String?) throws -> DOM.LineCap? {
        let att = Attributes()
        att.element["val"] = text
        return try att.parseRaw("val")
    }

    func testStrokeLineCap() {
        XCTAssertNil(try ParseLineCap(nil))
        XCTAssertEqual(try ParseLineCap("butt"), .butt)
        XCTAssertEqual(try ParseLineCap("round"), .round)
        XCTAssertEqual(try ParseLineCap("square"), .square)
        XCTAssertEqual(try ParseLineCap(" square "), .square)

        XCTAssertThrowsError(try ParseLineCap("ds"))
    }
    
    func ParseLineJoin(_ text: String?) throws -> DOM.LineJoin? {
        let att = Attributes()
        att.element["val"] = text
        return try att.parseRaw("val")
    }
    
    func testStrokeLineJoin() {
        XCTAssertNil(try ParseLineJoin(nil))
        XCTAssertEqual(try ParseLineJoin("miter"), .miter)
        XCTAssertEqual(try ParseLineJoin("round"), .round)
        XCTAssertEqual(try ParseLineJoin("bevel"), .bevel)
        XCTAssertEqual(try ParseLineJoin(" bevel "), .bevel)

        XCTAssertThrowsError(try ParseLineJoin("ds"))
    }
    
    func ParseDashArray(_ text: String?) throws -> [DOM.Float]? {
        let att = Attributes()
        att.element["val"] = text
        return try att.parseDashArray("val")
    }

    func testStrokeDashArray() {
        XCTAssertNil(try ParseDashArray(nil))
        XCTAssertEqual(try ParseDashArray("5 10 1 5")!, [5, 10, 1, 5])
        XCTAssertEqual(try ParseDashArray(" 1, 2.5, 3.5 ")!, [1, 2.5, 3.5])
        XCTAssertThrowsError(try ParseDashArray("ds"))
    }
}

private func AssertURLSelector(_ text: String, _ expected: String, file: StaticString = #file, line: UInt = #line) {
    let url = URL(string: expected)!
    let att: Attributes = ["val": text]
    XCTAssertEqual(try att.parseUrlSelector("val"), url, file: file, line: line)
}

extension SwiftVG.XMLParser {
    func parsePresentationAttributes(_ elements: [String: String]) throws -> PresentationAttributes {
        return try parsePresentationAttributes(Attributes(element: elements, style: [:]))
    }
}

typealias Attributes = SwiftVG.XMLParser.Attributes

extension Attributes: ExpressibleByDictionaryLiteral {
    public typealias Key = String
    public typealias Value = String

    public convenience init(_ elements: [String: String]) {
        self.init(element: elements, style: [:])
    }
    public convenience init(dictionaryLiteral elements: (String, String)...) {
        var att = [String: String]()
        for (key, value) in elements {
            att[key] = value
        }
        self.init(element: att, style: [:])
    }
     
}
