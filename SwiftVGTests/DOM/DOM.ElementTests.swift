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
    
    func createLine() -> DOM.Line {
        return DOM.Line(x1: 0, y1: 1, x2: 3, y2: 4)
    }
    
    func testLine() {
        let element = createLine()
        var another = createLine()
        
        XCTAssertEqual(element, another)
        
        another.x1 = 1
        XCTAssertNotEqual(element, another)
        
        another = createLine()
        another.fill = .keyword(.black)
        XCTAssertNotEqual(element, another)
        
        another.fill = nil
        XCTAssertEqual(element, another)
    }
    
    func createCircle() -> DOM.Circle {
        return DOM.Circle(cx: 0, cy: 1, r: 2)
    }
    
    func testCircle() {
        let element = createCircle()
        var another = createCircle()
        
        XCTAssertEqual(element, another)
        
        another.cx = 1
        XCTAssertNotEqual(element, another)
        
        another = createCircle()
        another.fill = .keyword(.black)
        XCTAssertNotEqual(element, another)
        
        another.fill = nil
        XCTAssertEqual(element, another)
    }
    
    func createEllipse() -> DOM.Ellipse {
        return DOM.Ellipse(cx: 0, cy: 1, rx: 2, ry: 3)
    }
    
    func testEllipse() {
        let element = createEllipse()
        var another = createEllipse()
        
        XCTAssertEqual(element, another)
        
        another.cx = 1
        XCTAssertNotEqual(element, another)
        
        another = createEllipse()
        another.fill = .keyword(.black)
        XCTAssertNotEqual(element, another)
        
        another.fill = nil
        XCTAssertEqual(element, another)
    }
    
    func createRect() -> DOM.Rect {
        return DOM.Rect(x: 0, y: 1, width: 2, height: 3)
    }
    
    func testRect() {
        let element = createRect()
        var another = createRect()
        
        XCTAssertEqual(element, another)
        
        another.x = 1
        XCTAssertNotEqual(element, another)
        
        another = createRect()
        another.fill = .keyword(.black)
        XCTAssertNotEqual(element, another)
        
        another.fill = nil
        XCTAssertEqual(element, another)
    }
    
    func createPolygon() -> DOM.Polygon {
        return DOM.Polygon(0, 1, 2, 3, 4, 5)
    }
    
    func testPolygon() {
        let element = createPolygon()
        var another = createPolygon()
        
        XCTAssertEqual(element, another)
        
        another.points.append(DOM.Point(6, 7))
        XCTAssertNotEqual(element, another)
        
        another = createPolygon()
        another.fill = .keyword(.black)
        XCTAssertNotEqual(element, another)
        
        another.fill = nil
        XCTAssertEqual(element, another)
    }
    
    func createPolyline() -> DOM.Polyline {
        return DOM.Polyline(0, 1, 2, 3, 4, 5)
    }
    
    func testPolyline() {
        let element = createPolyline()
        var another = createPolyline()
        
        XCTAssertEqual(element, another)
        
        another.points.append(DOM.Point(6, 7))
        XCTAssertNotEqual(element, another)
        
        another = createPolyline()
        another.fill = .keyword(.black)
        XCTAssertNotEqual(element, another)
        
        another.fill = nil
        XCTAssertEqual(element, another)
    }
    
    func createText() -> DOM.Text {
        return DOM.Text(x: 0, y: 1, value: "The quick brown fox")
    }
    
    func testText() {
        let element = createText()
        var another = createText()
        
        XCTAssertEqual(element, another)
        
        another.value = "Simon"
        XCTAssertNotEqual(element, another)
        
        another = createText()
        another.fill = .keyword(.black)
        XCTAssertNotEqual(element, another)
        
        another.fill = nil
        XCTAssertEqual(element, another)
    }
    
    func createPath() -> DOM.Path {
        let path = DOM.Path(x: 0, y: 1)
        path.move(x: 10, y: 10)
        path.horizontal(x: 20)
        return path
    }
    
    func createGroup() -> DOM.Group {
        let group = DOM.Group()
        group.childElements.append(createLine())
        group.childElements.append(createPolygon())
        group.childElements.append(createCircle())
        group.childElements.append(createPath())
        group.childElements.append(createRect())
        group.childElements.append(createEllipse())
        return group
    }
    
    func testGroup() {
        let group = createGroup()
        var another = createGroup()
        
        XCTAssertEqual(group, another)
        
        another.childElements.append(createCircle())
        XCTAssertNotEqual(group, another)
        
        another = createGroup()
        another.fill = .keyword(.black)
        XCTAssertNotEqual(group, another)
        
        another.fill = nil
        XCTAssertEqual(group, another)
    }
}
