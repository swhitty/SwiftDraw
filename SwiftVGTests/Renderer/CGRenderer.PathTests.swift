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
    
    let twoThirds = CGFloat(2.0/3.0)
    
    func testMove() {
        let r = CGRenderer()
        
        var m = r.createMove(from: .move(x: 10, y: 10, space: .absolute), last: CGPoint.zero)
        XCTAssertEqual(m, move(10, 10))
        
        m = r.createMove(from: .move(x: 10, y: 10, space: .absolute),
                         last: CGPoint(x: 100, y: 100))
        XCTAssertEqual(m, move(10, 10))
 
        m = r.createMove(from: .move(x: 10, y: -10, space: .relative),
                         last: CGPoint(x: 100, y: 100))
        XCTAssertEqual(m, move(110, 90))
    }
    
    func testLine() {
        let r = CGRenderer()
        
        var l = r.createLine(from: .line(x: 10, y: 10, space: .absolute), last: CGPoint.zero)
        XCTAssertEqual(l, line(10, 10))
        
        l = r.createLine(from: .line(x: 10, y: 10, space: .absolute),
                         last: CGPoint(x: 100, y: 100))
        XCTAssertEqual(l, line(10, 10))
        
        l = r.createLine(from: .line(x: 10, y: -10, space: .relative),
                         last: CGPoint(x: 100, y: 100))
        XCTAssertEqual(l, line(110, 90))
    }
    
    func testHorizontal() {
        let r = CGRenderer()
        
        var l = r.createHorizontal(from: .horizontal(x: 10, space: .absolute), last: CGPoint.zero)
        XCTAssertEqual(l, line(10, 0))
        
        l = r.createHorizontal(from: .horizontal(x: 10, space: .absolute),
                         last: CGPoint(x: 100, y: 100))
        XCTAssertEqual(l, line(10, 100))
        
        l = r.createHorizontal(from: .horizontal(x: 10, space: .relative),
                               last: CGPoint(x: 100, y: 100))
        XCTAssertEqual(l, line(110, 100))
        
        l = r.createHorizontal(from: .horizontal(x: -10, space: .relative),
                         last: CGPoint(x: 100, y: 100))
        XCTAssertEqual(l, line(90, 100))
    }
    
    func testVertical() {
        let r = CGRenderer()
        
        var l = r.createVertical(from: .vertical(y: 10, space: .absolute), last: CGPoint.zero)
        XCTAssertEqual(l, line(0, 10))
        
        l = r.createVertical(from: .vertical(y: 10, space: .absolute),
                               last: CGPoint(x: 100, y: 100))
        XCTAssertEqual(l, line(100, 10))
        
        l = r.createVertical(from: .vertical(y: 10, space: .relative),
                               last: CGPoint(x: 100, y: 100))
        XCTAssertEqual(l, line(100, 110))
        
        l = r.createVertical(from: .vertical(y: -10, space: .relative),
                               last: CGPoint(x: 100, y: 100))
        XCTAssertEqual(l, line(100, 90))
    }
    
    func testCubic() {
        let r = CGRenderer()
        
        var curve: DOM.Path.Segment
        curve = .cubic(x: 0, y: 10,
                       x1: 20, y1: 30,
                       x2: 40, y2: 50, space: .absolute)
        var c = r.createCubic(from: curve , last: CGPoint.zero)
        XCTAssertEqual(c, cubic(40, 50, 0, 10, 20, 30))
        
        curve = .cubic(x: 100, y: 0,
                       x1: -10, y1: 10,
                       x2: 110, y2: -10, space: .relative)
        c = r.createCubic(from: curve , last: CGPoint(x: 100, y: 100))
        XCTAssertEqual(c, cubic(210, 90, 200, 100, 90, 110))
    }
    
    func testCubicSmoothAbsolute() {
        let r = CGRenderer()
        
        var curve: DOM.Path.Segment
        curve = .cubicSmooth(x:80, y: 40, x2: 100, y2: 50, space: .absolute)
        var c = r.createCubicSmooth(from: curve, last: CGPoint.zero, previous: CGPoint.zero)
        XCTAssertEqual(c, cubic(100, 50, 0, 0, 80, 40))
        
        
        curve = .cubicSmooth(x:180, y: 60, x2: 200, y2: 50, space: .absolute)
        c = r.createCubicSmooth(from: curve, last: CGPoint(x: 100, y: 50), previous: CGPoint(x: 80, y: 40))
        XCTAssertEqual(c, cubic(200, 50, 120, 60, 180, 60))
    }
    
    func testCubicSmoothRelative() {
        let r = CGRenderer()
        
        var curve: DOM.Path.Segment
        curve = .cubicSmooth(x:80, y: -10, x2: 100, y2: 0, space: .relative)
        var c = r.createCubicSmooth(from: curve, last: CGPoint(x: 0, y: 50), previous: CGPoint(x: 0, y: 50))
        XCTAssertEqual(c, cubic(100, 50, 0, 50, 80, 40))
        
        curve = .cubicSmooth(x:80, y: 10, x2: 100, y2: 0, space: .relative)
        c = r.createCubicSmooth(from: curve, last: CGPoint(x: 100, y: 50), previous: CGPoint(x: 80, y: 40))
        XCTAssertEqual(c, cubic(200, 50, 120, 60, 180, 60))
    }
    
    func testQuadraticBalanced() {
        
        //balanced quad with control point centered on the curve
        let r = CGRenderer()
        var quad: DOM.Path.Segment
        quad = .quadratic(x: 150, y: 0,
                          x1: 300, y1: 50, space: .absolute)
        var c = r.createQuadratic(from: quad, last: CGPoint(x: 0, y: 50))
    
       XCTAssertEqual(c, cubic(300, 50, 100, 25*twoThirds, 200, 25*twoThirds))
        
        quad = .quadratic(x: 150, y: -50,
                          x1: 300, y1: 0, space: .relative)
        c = r.createQuadratic(from: quad, last: CGPoint(x: 0, y: 50))
        XCTAssertEqual(c, cubic(300, 50, 100, 25*twoThirds, 200, 25*twoThirds))
    }
    
    func testQuadraticUnbalanced() {
        //quad with control point to the left
        let r = CGRenderer()
        var quad: DOM.Path.Segment
        quad = .quadratic(x: 100, y: 0,
                          x1: 300, y1: 50, space: .absolute)
        var c = r.createQuadratic(from: quad, last: CGPoint(x: 0, y: 50))
        
        XCTAssertEqual(c, cubic(300, 50, 100*twoThirds, 25*twoThirds, 100*twoThirds+150*twoThirds, 25*twoThirds))
        
        //quad with control point to the right
        quad = .quadratic(x: 200, y: 0,
                          x1: 300, y1: 50, space: .absolute)
        c = r.createQuadratic(from: quad, last: CGPoint(x: 0, y: 50))
        XCTAssertEqual(c, cubic(300, 50, 200*twoThirds, 25*twoThirds, 200*twoThirds+150*twoThirds, 25*twoThirds))
    }

    func testQuadraticSmoothAbsolute() {
        let r = CGRenderer()
        
        var quad: DOM.Path.Segment
        quad = .quadraticSmooth(x: 100, y: 50, space: .absolute)
        
        let c = r.createQuadraticSmooth(from: quad, last: CGPoint(x: 0, y: 50), previous: CGPoint(x: -50, y: 0))
        XCTAssertEqual(c, cubic(100, 50, 50, 100, 50+50*twoThirds, 100))
    }
    
    func testClose() {
        let r = CGRenderer()
        XCTAssertEqual(r.createClose(from: .close), CGRenderer.Path.Segment.close)
    }
}

private typealias Segment = CGRenderer.Path.Segment

// helpers to create Segments without labels
// splatting of tuple is no longer supported
private func move(_ x: CGFloat, _ y: CGFloat) -> Segment {
    return .move(CGPoint(x: x, y: y))
}

private func line(_ x: CGFloat, _ y: CGFloat) -> Segment {
    return .line(CGPoint(x: x, y: y))
}

private func cubic(_ x: CGFloat, _ y: CGFloat,
                   _ x1: CGFloat, _ y1: CGFloat,
                   _ x2: CGFloat, _ y2: CGFloat) -> Segment {
    return .cubic(CGPoint(x: x, y: y), CGPoint(x: x1, y: y1), CGPoint(x: x2, y: y2))
}

extension CGRenderer.Path.Segment: Equatable {
    public static func ==(lhs: CGRenderer.Path.Segment, rhs: CGRenderer.Path.Segment) -> Bool {
        let toString: (Any) -> String = { var text = ""; dump($0, to: &text); return text }
        return toString(lhs) == toString(rhs)
    }
}
