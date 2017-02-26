//
//  ElementTests.swift
//  SwiftVG
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright © 2016 WhileLoop Pty Ltd. All rights reserved.
//

import XCTest
@testable import SwiftVG

class ElementTests: XCTestCase {
    
    func testLine() {
        let node = XML.Element(name: "line", attributes: ["x1": "0",
                                                          "y1": "10",
                                                          "x2": "50",
                                                          "y2": "60"])
        
        XCTAssertEqual(DOM.Line(x1: 0, y1: 10, x2: 50, y2: 60), try? XMLParser().parseLine(node))
    }
    
    func testCircle() {
        let node = XML.Element(name: "circle", attributes: ["cx": "0",
                                                            "cy": "10",
                                                            "r": "20"])
        
        XCTAssertEqual(DOM.Circle(cx: 0, cy: 10, r: 20), try? XMLParser().parseCircle(node))
    }
    
    func testEllipse() {
        let node = XML.Element(name: "ellipse", attributes: ["cx": "0",
                                                             "cy": "10",
                                                             "rx": "20",
                                                             "ry": "30"])
        
        XCTAssertEqual(DOM.Ellipse(cx: 0, cy: 10, rx: 20, ry: 30), try? XMLParser().parseEllipse(node))
    }
    
    func testRect() {
        let node = XML.Element(name: "rect", attributes: ["x": "0",
                                                          "y": "10",
                                                          "width": "20",
                                                          "height": "30"])
        
        let rect = DOM.Rect(x: 0, y: 10, width: 20, height: 30)
        XCTAssertEqual(rect, try? XMLParser().parseRect(node))
        
        node.attributes["rx"] = "3"
        node.attributes["ry"] = "2"
        rect.rx = 3
        rect.ry = 2
        XCTAssertEqual(rect, try? XMLParser().parseRect(node))
    }
    
    func testPolyline() {
        let node = XML.Element(name: "polyline", attributes: ["points": "0,1 2 3; 4;5;6;7;8 9"])
        
        XCTAssertEqual(DOM.Polyline(0, 1, 2, 3, 4, 5, 6, 7, 8, 9), try? XMLParser().parsePolyline(node))
    }
    
    func testPolygon() {
        let node = XML.Element(name: "polygon", attributes: ["points": "0,1,2,3;4;5;6;7;8 9"])
        
        XCTAssertEqual(DOM.Polygon(0, 1, 2, 3, 4, 5, 6, 7, 8, 9), try? XMLParser().parsePolygon(node))
    }
    
    func testPolygonFillRule() {
        
        let node = XML.Element(name: "polygon")
        node.attributes["points"] = "0,1,2,3"
        XCTAssertNil((try! XMLParser().parsePolygon(node)).fillRule)
        
        node.attributes["fill-rule"] = "nonzero"
        XCTAssertEqual(try XMLParser().parsePolygon(node).fillRule, .nonzero)
        
        node.attributes["fill-rule"] = "evenodd"
        XCTAssertEqual(try XMLParser().parsePolygon(node).fillRule, .evenodd)
        
        node.attributes["fill-rule"] = "asdf"
        XCTAssertThrowsError(try XMLParser().parsePolygon(node).fillRule)
    }
}

extension DOM.Polyline {
    
    // requires even number of elements
    convenience init(_ p: DOM.Coordinate...) {
        
        var points = Array<DOM.Point>()
        
        for index in stride(from: 0, to: points.count, by: 2) {
            points.append(DOM.Point(p[index], p[index + 1]))
        }
        
        self.init(points: points)
    }
}

extension DOM.Polygon {
    
    // requires even number of elements
    convenience init(_ p: DOM.Coordinate...) {
        
        var points = Array<DOM.Point>()
        
        for index in stride(from: 0, to: points.count, by: 2) {
            points.append(DOM.Point(p[index], p[index + 1]))
        }
        
        self.init(points: points)
    }
}
