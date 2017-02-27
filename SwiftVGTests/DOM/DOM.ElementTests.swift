//
//  DOM.ElementTests.swift
//  SwiftVG
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright © 2016 WhileLoop Pty Ltd. All rights reserved.
//

import XCTest
@testable import SwiftVG

class DOMElementTests: XCTestCase {
    
    func testLine() {
        let element = DOM.createLine()
        var another = DOM.createLine()
        
        XCTAssertEqual(element, another)
        
        another.x1 = 1
        XCTAssertNotEqual(element, another)
        
        another = DOM.createLine()
        another.fill = .keyword(.black)
        XCTAssertNotEqual(element, another)
        
        another.fill = nil
        XCTAssertEqual(element, another)
    }
    
    func testCircle() {
        let element = DOM.createCircle()
        var another = DOM.createCircle()
        
        XCTAssertEqual(element, another)
        
        another.cx = 1
        XCTAssertNotEqual(element, another)
        
        another = DOM.createCircle()
        another.fill = .keyword(.black)
        XCTAssertNotEqual(element, another)
        
        another.fill = nil
        XCTAssertEqual(element, another)
    }
    
    func testEllipse() {
        let element = DOM.createEllipse()
        var another = DOM.createEllipse()
        
        XCTAssertEqual(element, another)
        
        another.cx = 1
        XCTAssertNotEqual(element, another)
        
        another = DOM.createEllipse()
        another.fill = .keyword(.black)
        XCTAssertNotEqual(element, another)
        
        another.fill = nil
        XCTAssertEqual(element, another)
    }
    
    func testRect() {
        let element = DOM.createRect()
        var another = DOM.createRect()
        
        XCTAssertEqual(element, another)
        
        another.x = 1
        XCTAssertNotEqual(element, another)
        
        another = DOM.createRect()
        another.fill = .keyword(.black)
        XCTAssertNotEqual(element, another)
        
        another.fill = nil
        XCTAssertEqual(element, another)
    }
    
    func testPolygon() {
        let element = DOM.createPolygon()
        var another = DOM.createPolygon()
        
        XCTAssertEqual(element, another)
        
        another.points.append(DOM.Point(6, 7))
        XCTAssertNotEqual(element, another)
        
        another = DOM.createPolygon()
        another.fill = .keyword(.black)
        XCTAssertNotEqual(element, another)
        
        another.fill = nil
        XCTAssertEqual(element, another)
    }
    
    func testPolyline() {
        let element = DOM.createPolyline()
        var another = DOM.createPolyline()
        
        XCTAssertEqual(element, another)
        
        another.points.append(DOM.Point(6, 7))
        XCTAssertNotEqual(element, another)
        
        another = DOM.createPolyline()
        another.fill = .keyword(.black)
        XCTAssertNotEqual(element, another)
        
        another.fill = nil
        XCTAssertEqual(element, another)
    }

    func testText() {
        let element = DOM.createText()
        var another = DOM.createText()
        
        XCTAssertEqual(element, another)
        
        another.value = "Simon"
        XCTAssertNotEqual(element, another)
        
        another = DOM.createText()
        another.fill = .keyword(.black)
        XCTAssertNotEqual(element, another)
        
        another.fill = nil
        XCTAssertEqual(element, another)
    }
    
    func testGroup() {
        let group = DOM.createGroup()
        var another = DOM.createGroup()
        
        XCTAssertEqual(group, another)
        
        another.childElements.append(DOM.createCircle())
        XCTAssertNotEqual(group, another)
        
        another = DOM.createGroup()
        another.fill = .keyword(.black)
        XCTAssertNotEqual(group, another)
        
        another.fill = nil
        XCTAssertEqual(group, another)
    }
}
