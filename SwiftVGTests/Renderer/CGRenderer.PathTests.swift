//
//  CGRenderer.PathTests.swift
//  SwiftVG
//
//  Created by Simon Whitty on 14/3/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

import XCTest
@testable import SwiftVG

class CGRendererPathTests: XCTestCase {
    
    typealias Point = Builder.Point
    
    let twoThirds = Builder.Float(2.0/3.0)
    
    func testMove() {
        let b = Builder()
        
        var m = b.createMove(from: .move(x: 10, y: 10, space: .absolute), last: Point.zero)
        XCTAssertEqual(m, move(10, 10))
        
        m = b.createMove(from: .move(x: 10, y: 10, space: .absolute),
                         last: Point(100, 100))
        XCTAssertEqual(m, move(10, 10))
 
        m = b.createMove(from: .move(x: 10, y: -10, space: .relative),
                         last: Point(100, 100))
        XCTAssertEqual(m, move(110, 90))
    }
    
    func testLine() {
        let b = Builder()
        
        var l = b.createLine(from: .line(x: 10, y: 10, space: .absolute), last: Point.zero)
        XCTAssertEqual(l, line(10, 10))
        
        l = b.createLine(from: .line(x: 10, y: 10, space: .absolute),
                         last: Point(100, 100))
        XCTAssertEqual(l, line(10, 10))
        
        l = b.createLine(from: .line(x: 10, y: -10, space: .relative),
                         last: Point(100, 100))
        XCTAssertEqual(l, line(110, 90))
    }
    
    func testHorizontal() {
        let b = Builder()
        
        var l = b.createHorizontal(from: .horizontal(x: 10, space: .absolute), last: Point.zero)
        XCTAssertEqual(l, line(10, 0))
        
        l = b.createHorizontal(from: .horizontal(x: 10, space: .absolute),
                         last: Point(100, 100))
        XCTAssertEqual(l, line(10, 100))
        
        l = b.createHorizontal(from: .horizontal(x: 10, space: .relative),
                               last: Point(100, 100))
        XCTAssertEqual(l, line(110, 100))
        
        l = b.createHorizontal(from: .horizontal(x: -10, space: .relative),
                         last: Point(100, 100))
        XCTAssertEqual(l, line(90, 100))
    }
    
    func testVertical() {
        let b = Builder()
        
        var l = b.createVertical(from: .vertical(y: 10, space: .absolute), last: Point.zero)
        XCTAssertEqual(l, line(0, 10))
        
        l = b.createVertical(from: .vertical(y: 10, space: .absolute),
                               last: Point(100, 100))
        XCTAssertEqual(l, line(100, 10))
        
        l = b.createVertical(from: .vertical(y: 10, space: .relative),
                               last: Point(100, 100))
        XCTAssertEqual(l, line(100, 110))
        
        l = b.createVertical(from: .vertical(y: -10, space: .relative),
                               last: Point(100, 100))
        XCTAssertEqual(l, line(100, 90))
    }
    
    func testCubic() {
        let b = Builder()
        
        var curve: DOM.Path.Segment
        curve = .cubic(x1: 0, y1: 10,
                       x2: 20, y2: 30,
                       x: 40, y: 50, space: .absolute)
        var c = b.createCubic(from: curve , last: Point.zero)
        XCTAssertEqual(c, cubic(40, 50, 0, 10, 20, 30))
        
        curve = .cubic(x1: 100, y1: 0,
                       x2: -10, y2: 10,
                       x: 110, y: -10, space: .relative)
        c = b.createCubic(from: curve , last: Point(100, 100))
        XCTAssertEqual(c, cubic(210, 90, 200, 100, 90, 110))
    }
    
    func testCubicSmoothAbsolute() {
        let b = Builder()
        
        var curve: DOM.Path.Segment
        curve = .cubicSmooth(x2:80, y2: 40, x: 100, y: 50, space: .absolute)
        var c = b.createCubicSmooth(from: curve, last: Point.zero, previous: Point.zero)
        XCTAssertEqual(c, cubic(100, 50, 0, 0, 80, 40))
        
        curve = .cubicSmooth(x2:180, y2: 60, x: 200, y: 50, space: .absolute)
        c = b.createCubicSmooth(from: curve, last: Point(100, 50), previous: Point(80, 40))
        XCTAssertEqual(c, cubic(200, 50, 120, 60, 180, 60))
    }
    
    func testCubicSmoothRelative() {
        let b = Builder()
        
        var curve: DOM.Path.Segment
        curve = .cubicSmooth(x2:80, y2: -10, x: 100, y: 0, space: .relative)
        var c = b.createCubicSmooth(from: curve, last: Point(0, 50), previous: Point(0, 50))
        XCTAssertEqual(c, cubic(100, 50, 0, 50, 80, 40))
        
        curve = .cubicSmooth(x2:80, y2: 10, x: 100, y: 0, space: .relative)
        c = b.createCubicSmooth(from: curve, last: Point(100, 50), previous: Point(80, 40))
        XCTAssertEqual(c, cubic(200, 50, 120, 60, 180, 60))
    }
    
    func testQuadraticBalanced() {
        
        //balanced quad with control point centered on the curve
        let b = Builder()
        var quad: DOM.Path.Segment
        quad = .quadratic(x1: 150, y1: 0,
                          x: 300, y: 50, space: .absolute)
        var c = b.createQuadratic(from: quad, last: Point(0, 50))

       XCTAssertEqual(c, cubic(300, 50, 100, 16.6666641, 200, 16.6666641))
        
        quad = .quadratic(x1: 150, y1: -50,
                          x: 300, y: 0, space: .relative)
        c = b.createQuadratic(from: quad, last: Point(0, 50))
        XCTAssertEqual(c, cubic(300, 50, 100, 16.6666641, 200, 16.6666641))
    }
    
    func testQuadraticUnbalanced() {
        //quad with control point to the left
        let b = Builder()
        var quad: DOM.Path.Segment
        quad = .quadratic(x1: 100, y1: 0,
                          x: 300, y: 50, space: .absolute)
        var c = b.createQuadratic(from: quad, last: Point(0, 50))
        
        XCTAssertEqual(c, cubic(300, 50, 100*twoThirds, 16.6666641, 100*twoThirds+150*twoThirds, 16.6666641))
        
        //quad with control point to the right
        quad = .quadratic(x1: 200, y1: 0,
                          x: 300, y: 50, space: .absolute)
        c = b.createQuadratic(from: quad, last: Point(0, 50))
        XCTAssertEqual(c, cubic(300, 50, 200*twoThirds, 16.6666641, 200*twoThirds+150*twoThirds, 16.6666641))
    }

    func testQuadraticSmoothAbsolute() {
        let b = Builder()
        
        var quad: DOM.Path.Segment
        quad = .quadraticSmooth(x: 100, y: 50, space: .absolute)
        
        let c = b.createQuadraticSmooth(from: quad, last: Point(0, 50), previous: Point(-50, 0))
        XCTAssertEqual(c, cubic(100, 50, 50, 100, 50+50*twoThirds, 100))
    }
    
    func testClose() {
        let b = Builder()
        XCTAssertEqual(b.createClose(from: .close), Segment.close)
    }
}

private typealias Segment = Builder.Path.Segment

// helpers to create Segments without labels
// splatting of tuple is no longer supported
private func move(_ x: Builder.Float, _ y: Builder.Float) -> Segment {
    return .move(Builder.Point(x, y))
}

private func line(_ x: Builder.Float, _ y: Builder.Float) -> Segment {
    return .line(Builder.Point(x, y))
}

private func cubic(_ x: Builder.Float, _ y: Builder.Float,
                   _ x1: Builder.Float, _ y1: Builder.Float,
                   _ x2: Builder.Float, _ y2: Builder.Float) -> Segment {
    return .cubic(Builder.Point(x, y), Builder.Point(x1, y1), Builder.Point(x2, y2))
}
