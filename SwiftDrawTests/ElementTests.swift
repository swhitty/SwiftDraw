//
//  ElementTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright 2016 Simon Whitty
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
@testable import SwiftDraw

final class ElementTests: XCTestCase {
    
    func testLine() {
        let node = ["x1": "0",
                    "y1": "10",
                    "x2": "50",
                    "y2": "60"]
        
        let parsed = try? XMLParser().parseLine(node)
        XCTAssertEqual(DOM.Line(x1: 0, y1: 10, x2: 50, y2: 60), parsed)
    }
    
    func testCircle() {
        let node = ["cx": "0",
                    "cy": "10",
                    "r": "20"]
        
        let parsed = try? XMLParser().parseCircle(node)
        XCTAssertEqual(DOM.Circle(cx: 0, cy: 10, r: 20), parsed)
    }
    
    func testEllipse() {
        let node = ["cx": "0",
                    "cy": "10",
                    "rx": "20",
                    "ry": "30"]
        
        let parsed = try? XMLParser().parseEllipse(node)
        XCTAssertEqual(DOM.Ellipse(cx: 0, cy: 10, rx: 20, ry: 30), parsed)
    }
    
    func testRect() {
        var node = ["x": "0",
                    "y": "10",
                    "width": "20",
                    "height": "30"]
        
        let rect = DOM.Rect(x: 0, y: 10, width: 20, height: 30)
        XCTAssertEqual(rect, try? XMLParser().parseRect(node))
        
        node["rx"] = "3"
        node["ry"] = "2"
        rect.rx = 3
        rect.ry = 2
        XCTAssertEqual(rect, try? XMLParser().parseRect(node))
    }
    
    func testPolyline() throws {
        let node = ["points": "0,1 2 3; 4;5;6;7;8 9"]
        
        let parsed = try? XMLParser().parsePolyline(node)
        XCTAssertEqual(DOM.Polyline(0, 1, 2, 3, 4, 5, 6, 7, 8, 9), parsed)
    }
    
    func testPolygon() {
        let att = ["points": "0, 1,2,3;4;5;6;7;8 9"]
        let parsed =  try? XMLParser().parsePolygon(att)
        XCTAssertEqual(DOM.Polygon(0, 1, 2, 3, 4, 5, 6, 7, 8, 9), parsed)
    }
    
    func testPolygonFillRule() {
        let att = ["points": "0,1,2,3;4;5;6;7;8 9"]
        XCTAssertNil((try! XMLParser().parsePolygon(att)).fillRule)
        
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
