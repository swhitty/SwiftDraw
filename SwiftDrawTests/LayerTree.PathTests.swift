//
//  LayerTree.PathTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 3/6/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
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

final class LayerTreePathTests: XCTestCase {

    typealias Float = LayerTree.Float
    typealias Point = LayerTree.Point
    typealias Path = LayerTree.Path
    typealias Segment = LayerTree.Path.Segment
    
    let twoThirds = Float(2.0/3.0)


    func testLocation() {
        let path = Path()
        XCTAssertNil(path.location)

        path.segments.append(move(110, 90))
        XCTAssertEqual(path.location, Point(110, 90))

        path.segments.append(line(200, 200))
        XCTAssertEqual(path.location, Point(200, 200))

        path.segments.append(.cubic(to: Point(300, 300), control1: Point(200, 200), control2: Point(250, 250)))
        XCTAssertEqual(path.location, Point(300, 300))

        path.segments.append(.close)
        XCTAssertEqual(path.location, Point(110, 90))
    }

    func testMove() {

        var m = LayerTree.Builder.createMove(from: .move(x: 10, y: 10, space: .absolute), last: .zero)
        XCTAssertEqual(m, move(10, 10))
        
        m = LayerTree.Builder.createMove(from: .move(x: 10, y: 10, space: .absolute),
                                         last: Point(100, 100))
        XCTAssertEqual(m, move(10, 10))
        
        m = LayerTree.Builder.createMove(from: .move(x: 10, y: -10, space: .relative),
                                         last: Point(100, 100))
        XCTAssertEqual(m, move(110, 90))
    }
    
    func testLine() {
        var l = LayerTree.Builder.createLine(from: .line(x: 10, y: 10, space: .absolute), last: .zero)
        XCTAssertEqual(l, line(10, 10))
        
        l = LayerTree.Builder.createLine(from: .line(x: 10, y: 10, space: .absolute),
                         last: Point(100, 100))
        XCTAssertEqual(l, line(10, 10))
        
        l = LayerTree.Builder.createLine(from: .line(x: 10, y: -10, space: .relative),
                         last: Point(100, 100))
        XCTAssertEqual(l, line(110, 90))
    }
    
    func testHorizontal() {
        var l = LayerTree.Builder.createHorizontal(from: .horizontal(x: 10, space: .absolute), last: .zero)
        XCTAssertEqual(l, line(10, 0))
        
        l = LayerTree.Builder.createHorizontal(from: .horizontal(x: 10, space: .absolute),
                               last: Point(100, 100))
        XCTAssertEqual(l, line(10, 100))
        
        l = LayerTree.Builder.createHorizontal(from: .horizontal(x: 10, space: .relative),
                               last: Point(100, 100))
        XCTAssertEqual(l, line(110, 100))
        
        l = LayerTree.Builder.createHorizontal(from: .horizontal(x: -10, space: .relative),
                               last: Point(100, 100))
        XCTAssertEqual(l, line(90, 100))
    }
    
    func testVertical() {
        var l = LayerTree.Builder.createVertical(from: .vertical(y: 10, space: .absolute), last: .zero)
        XCTAssertEqual(l, line(0, 10))
        
        l = LayerTree.Builder.createVertical(from: .vertical(y: 10, space: .absolute),
                             last: Point(100, 100))
        XCTAssertEqual(l, line(100, 10))
        
        l = LayerTree.Builder.createVertical(from: .vertical(y: 10, space: .relative),
                             last: Point(100, 100))
        XCTAssertEqual(l, line(100, 110))
        
        l = LayerTree.Builder.createVertical(from: .vertical(y: -10, space: .relative),
                             last: Point(100, 100))
        XCTAssertEqual(l, line(100, 90))
    }
    
    func testCubic() {
        var curve: DOM.Path.Segment
        curve = .cubic(x1: 0, y1: 10,
                       x2: 20, y2: 30,
                       x: 40, y: 50, space: .absolute)
        var c = LayerTree.Builder.createCubic(from: curve , last: .zero)
        XCTAssertEqual(c, cubic(40, 50, 0, 10, 20, 30))
        
        curve = .cubic(x1: 100, y1: 0,
                       x2: -10, y2: 10,
                       x: 110, y: -10, space: .relative)
        c = LayerTree.Builder.createCubic(from: curve , last: Point(100, 100))
        XCTAssertEqual(c, cubic(210, 90, 200, 100, 90, 110))
    }
    
    func testCubicSmoothAbsolute() {
        var curve: DOM.Path.Segment
        curve = .cubicSmooth(x2:80, y2: 40, x: 100, y: 50, space: .absolute)
        var c = LayerTree.Builder.createCubicSmooth(from: curve, last: .zero, previous: Point.zero)
        XCTAssertEqual(c, cubic(100, 50, 0, 0, 80, 40))
        
        curve = .cubicSmooth(x2:180, y2: 60, x: 200, y: 50, space: .absolute)
        c = LayerTree.Builder.createCubicSmooth(from: curve, last: Point(100, 50), previous: Point(80, 40))
        XCTAssertEqual(c, cubic(200, 50, 120, 60, 180, 60))
    }
    
    func testCubicSmoothRelative() {
        var curve: DOM.Path.Segment
        curve = .cubicSmooth(x2:80, y2: -10, x: 100, y: 0, space: .relative)
        var c = LayerTree.Builder.createCubicSmooth(from: curve, last: Point(0, 50), previous: Point(0, 50))
        XCTAssertEqual(c, cubic(100, 50, 0, 50, 80, 40))
        
        curve = .cubicSmooth(x2:80, y2: 10, x: 100, y: 0, space: .relative)
        c = LayerTree.Builder.createCubicSmooth(from: curve, last: Point(100, 50), previous: Point(80, 40))
        XCTAssertEqual(c, cubic(200, 50, 120, 60, 180, 60))
    }
    
    func testQuadraticBalanced() {
        //balanced quad with control point centered on the curve
        var quad: DOM.Path.Segment
        quad = .quadratic(x1: 150, y1: 0,
                          x: 300, y: 50, space: .absolute)
        var c = LayerTree.Builder.createQuadratic(from: quad, last: Point(0, 50))
        
        XCTAssertEqual(c, cubic(300, 50, 100, 16.6666641, 200, 16.6666641))
        
        quad = .quadratic(x1: 150, y1: -50,
                          x: 300, y: 0, space: .relative)
        c = LayerTree.Builder.createQuadratic(from: quad, last: Point(0, 50))
        XCTAssertEqual(c, cubic(300, 50, 100, 16.6666641, 200, 16.6666641))
    }
    
    func testQuadraticUnbalanced() {
        //quad with control point to the left
        var quad: DOM.Path.Segment
        quad = .quadratic(x1: 100, y1: 0,
                          x: 300, y: 50, space: .absolute)
        var c = LayerTree.Builder.createQuadratic(from: quad, last: Point(0, 50))
        
        XCTAssertEqual(c, cubic(300, 50, 100*twoThirds, 16.6666641, 100*twoThirds+150*twoThirds, 16.6666641))
        
        //quad with control point to the right
        quad = .quadratic(x1: 200, y1: 0,
                          x: 300, y: 50, space: .absolute)
        c = LayerTree.Builder.createQuadratic(from: quad, last: Point(0, 50))
        XCTAssertEqual(c, cubic(300, 50, 200*twoThirds, 16.6666641, 200*twoThirds+150*twoThirds, 16.6666641))
    }
    
    func testQuadraticSmoothAbsolute() {
        var quad: DOM.Path.Segment
        quad = .quadraticSmooth(x: 100, y: 50, space: .absolute)
        
        let c = LayerTree.Builder.createQuadraticSmooth(from: quad, last: Point(0, 50), previous: Point(-50, 0))
        XCTAssertEqual(c, cubic(100, 50, 50, 100, 50+50*twoThirds, 100))
    }
    
    func testClose() {
        XCTAssertEqual(LayerTree.Builder.createClose(from: .close), Segment.close)
    }

    func testDOMQuadraticSmooth() {
        let domSegment = DOM.Path.Segment.quadraticSmooth(x: 10.0, y: 10.0, space: .relative)
        let segment = LayerTree.Builder.makeSegment(from: domSegment, last: .init(10, 10), previous: nil)

        XCTAssertEqual(segment, .cubic(to: .init(20.0, 20.0), control1: .init(10, 10), control2: .init(13.333334, 10)))
    }

    func testDOMCubicSmooth() {
        let domSegment = DOM.Path.Segment.cubicSmooth(x2: 10, y2: 10, x: 10, y: 10, space: .relative)
        let segment = LayerTree.Builder.makeSegment(from: domSegment, last: .init(10, 10), previous: nil)

        XCTAssertEqual(segment, .cubic(to: .init(20.0, 20.0), control1: .init(10, 10), control2: .init(20.0, 20.0)))
    }

    // helpers to create Segments without labels
    // splatting of tuple is no longer supported
    private func move(_ x: Float, _ y: Float) -> Path.Segment {
        return .move(to: Point(x, y))
    }
    
    private func line(_ x: Float, _ y: Float) -> Path.Segment {
        return .line(to: Point(x, y))
    }
    
    private func cubic(_ x: Float, _ y: Float,
                       _ x1: Float, _ y1: Float,
                       _ x2: Float, _ y2: Float) -> Path.Segment {
        return .cubic(to: Point(x, y), control1: Point(x1, y1), control2: Point(x2, y2))
    }

}


