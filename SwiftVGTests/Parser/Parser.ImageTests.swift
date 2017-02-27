//
//  Parser.ImageTests.swift
//  SwiftVG
//
//  Created by Simon Whitty on 28/1/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

import XCTest
@testable import SwiftVG

class ParserImageTests: XCTestCase {
    
    func loadSVG(_ filename: String) -> DOM.Svg? {
        
        let bundle = Bundle(for: TextTests.self)
        
        guard let url = bundle.url(forResource: filename, withExtension: nil),
            let element = try? XML.SAXParser.parse(contentsOf: url),
            let svg = try? XMLParser().parseSvg(element) else {
            return nil
        }
        return svg
    }
    
    func testShapes() {
        guard let svg = loadSVG("shapes.svg") else {
            XCTFail("failed to load shapes.svg")
            return
        }
        
        XCTAssertEqual(svg.width, 500)
        XCTAssertEqual(svg.height, 700)
        XCTAssertEqual(svg.viewBox?.width, 500)
        XCTAssertEqual(svg.viewBox?.height, 700)
        XCTAssertEqual(svg.defs.clipPaths.count, 2)
        XCTAssertEqual(svg.defs.linearGradients.count, 1)
        XCTAssertNotNil(svg.defs.elements["star"])
        XCTAssertEqual(svg.defs.elements.count, 1)
        
        var c = svg.childElements.enumerated().makeIterator()
        
        XCTAssertTrue(c.next()!.element is DOM.Ellipse)
        XCTAssertTrue(c.next()!.element is DOM.Group)
        XCTAssertTrue(c.next()!.element is DOM.Circle)
        XCTAssertTrue(c.next()!.element is DOM.Group)
        XCTAssertTrue(c.next()!.element is DOM.Line)
        XCTAssertTrue(c.next()!.element is DOM.Path)
        XCTAssertTrue(c.next()!.element is DOM.Path)
        XCTAssertTrue(c.next()!.element is DOM.Path)
        XCTAssertTrue(c.next()!.element is DOM.Polyline)
        XCTAssertTrue(c.next()!.element is DOM.Polyline)
        XCTAssertTrue(c.next()!.element is DOM.Polygon)
        XCTAssertTrue(c.next()!.element is DOM.Group)
        XCTAssertTrue(c.next()!.element is DOM.Circle)
        XCTAssertTrue(c.next()!.element is DOM.Rect)
        XCTAssertTrue(c.next()!.element is DOM.Text)
        XCTAssertTrue(c.next()!.element is DOM.Line)
        XCTAssertTrue(c.next()!.element is DOM.Use)
        XCTAssertNil(c.next())
    }
    
    func testStarry() {
        guard let svg = loadSVG("starry.svg"),
            let g = svg.childElements.first as? DOM.Group,
            let g1 = g.childElements.first as? DOM.Group else {
            XCTFail("missing group")
            return
        }
        
        XCTAssertEqual(svg.width, 500)
        XCTAssertEqual(svg.height, 500)
        
        XCTAssertEqual(g1.childElements.count, 9323)
        
        var counter = [String: Int]()
        
        for e in g1.childElements {
            let key = String(describing: type(of: e))
            counter[key] = (counter[key] ?? 0) + 1
        }
        
        XCTAssertEqual(counter["Path"], 9314)
        XCTAssertEqual(counter["Polygon"], 9)
    }
    
}
