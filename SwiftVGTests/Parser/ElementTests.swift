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
        let node = ["x1": "0",
                    "y1": "10",
                    "x2": "50",
                    "y2": "60"]
        
        let parsed = try? XMLParser().parseLine(Attributes(node))
        XCTAssertEqual(DOM.Line(x1: 0, y1: 10, x2: 50, y2: 60), parsed)
    }
    
    func testCircle() {
        let node = ["cx": "0",
                    "cy": "10",
                    "r": "20"]
        
        let parsed = try? XMLParser().parseCircle(Attributes(node))
        XCTAssertEqual(DOM.Circle(cx: 0, cy: 10, r: 20), parsed)
    }
    
    func testEllipse() {
        let node = ["cx": "0",
                    "cy": "10",
                    "rx": "20",
                    "ry": "30"]
        
        let parsed = try? XMLParser().parseEllipse(Attributes(node))
        XCTAssertEqual(DOM.Ellipse(cx: 0, cy: 10, rx: 20, ry: 30), parsed)
    }
    
    func testRect() {
        var node = ["x": "0",
                    "y": "10",
                    "width": "20",
                    "height": "30"]
        
        let rect = DOM.Rect(x: 0, y: 10, width: 20, height: 30)
        XCTAssertEqual(rect, try? XMLParser().parseRect(Attributes(node)))
        
        node["rx"] = "3"
        node["ry"] = "2"
        rect.rx = 3
        rect.ry = 2
        XCTAssertEqual(rect, try? XMLParser().parseRect(Attributes(node)))
    }
    
    func testPolyline() {
        let node: Attributes = ["points": "0,1 2 3; 4;5;6;7;8 9"]
        
        XCTAssertEqual(DOM.Polyline(0, 1, 2, 3, 4, 5, 6, 7, 8, 9), try? XMLParser().parsePolyline(node))
    }
    
    func testPolygon() {
        let parsed =  try? XMLParser().parsePolygon(["points": "0,1,2,3;4;5;6;7;8 9"])
        XCTAssertEqual(DOM.Polygon(0, 1, 2, 3, 4, 5, 6, 7, 8, 9), parsed)
    }
    
    func testPolygonFillRule() {
        XCTAssertNil((try! XMLParser().parsePolygon(["points": "0,1,2,3"])).fillRule)
        
        let node = XML.Element(name: "polygon")
        node.attributes["points"] = "0,1,2,3"
        
        node.attributes["fill-rule"] = "nonzero"
        XCTAssertEqual(try XMLParser().parseGraphicsElement(node)!.fillRule, .nonzero)
        
        node.attributes["fill-rule"] = "evenodd"
        XCTAssertEqual(try XMLParser().parseGraphicsElement(node)!.fillRule, .evenodd)
        
        node.attributes["fill-rule"] = "asdf"
        XCTAssertThrowsError(try XMLParser().parseGraphicsElement(node)!.fillRule)
    }
}
