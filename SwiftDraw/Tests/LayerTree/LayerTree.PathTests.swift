//
//  LayerTree.PathTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 3/6/17.
//  Copyright 2020 WhileLoop Pty Ltd. All rights reserved.
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

import SwiftDrawDOM
import Testing
@testable import SwiftDraw

struct LayerTreePathTests {

    typealias Float = LayerTree.Float
    typealias Point = LayerTree.Point
    typealias Path = LayerTree.Path
    typealias Segment = LayerTree.Path.Segment

    @Test
    func location() {
        let path = Path()
        #expect(path.location == nil)

        path.segments.append(move(10, 10))
        #expect(path.location == Point(10, 10))

        path.segments.append(line(20, 20))
        #expect(path.location == Point(20, 20))

        path.segments.append(move(110, 90))
        #expect(path.location == Point(110, 90))

        path.segments.append(line(200, 200))
        #expect(path.location == Point(200, 200))

        path.segments.append(.cubic(to: Point(300, 300), control1: Point(200, 200), control2: Point(250, 250)))
        #expect(path.location == Point(300, 300))

        path.segments.append(.close)
        #expect(path.location == Point(110, 90))
    }

    @Test
    func createsMove() {
        var m = LayerTree.Builder.createMove(from: .move(x: 10, y: 10, space: .absolute), last: .zero)
        #expect(m == move(10, 10))

        m = LayerTree.Builder.createMove(
            from: .move(x: 10, y: 10, space: .absolute),
            last: Point(100, 100)
        )
        #expect(m == move(10, 10))

        m = LayerTree.Builder.createMove(
            from: .move(x: 10, y: -10, space: .relative),
            last: Point(100, 100)
        )
        #expect(m == move(110, 90))
    }

    @Test
    func createsLine() {
        var l = LayerTree.Builder.createLine(from: .line(x: 10, y: 10, space: .absolute), last: .zero)
        #expect(l == line(10, 10))

        l = LayerTree.Builder.createLine(
            from: .line(x: 10, y: 10, space: .absolute),
            last: Point(100, 100)
        )
        #expect(l == line(10, 10))

        l = LayerTree.Builder.createLine(
            from: .line(x: 10, y: -10, space: .relative),
            last: Point(100, 100)
        )
        #expect(l == line(110, 90))
    }

    @Test
    func createsHorizontalLine() {
        var l = LayerTree.Builder.createHorizontal(from: .horizontal(x: 10, space: .absolute), last: .zero)
        #expect(l == line(10, 0))

        l = LayerTree.Builder.createHorizontal(
            from: .horizontal(x: 10, space: .absolute),
            last: Point(100, 100)
        )
        #expect(l == line(10, 100))

        l = LayerTree.Builder.createHorizontal(
            from: .horizontal(x: 10, space: .relative),
            last: Point(100, 100)
        )
        #expect(l == line(110, 100))

        l = LayerTree.Builder.createHorizontal(
            from: .horizontal(x: -10, space: .relative),
            last: Point(100, 100)
        )
        #expect(l == line(90, 100))
    }

    @Test
    func createsVerticalLine() {
        var l = LayerTree.Builder.createVertical(from: .vertical(y: 10, space: .absolute), last: .zero)
        #expect(l == line(0, 10))

        l = LayerTree.Builder.createVertical(
            from: .vertical(y: 10, space: .absolute),
            last: Point(100, 100)
        )
        #expect(l == line(100, 10))

        l = LayerTree.Builder.createVertical(
            from: .vertical(y: 10, space: .relative),
            last: Point(100, 100)
        )
        #expect(l == line(100, 110))

        l = LayerTree.Builder.createVertical(
            from: .vertical(y: -10, space: .relative),
            last: Point(100, 100)
        )
        #expect(l == line(100, 90))
    }

    @Test
    func createsCubic() {
        var curve: DOM.Path.Segment
        curve = .cubic(
            x1: 0,
            y1: 10,
            x2: 20,
            y2: 30,
            x: 40,
            y: 50,
            space: .absolute
        )
        var c = LayerTree.Builder.createCubic(from: curve, last: .zero)
        #expect(c == cubic(40, 50, 0, 10, 20, 30))

        curve = .cubic(
            x1: 100,
            y1: 0,
            x2: -10,
            y2: 10,
            x: 110,
            y: -10,
            space: .relative
        )
        c = LayerTree.Builder.createCubic(from: curve, last: Point(100, 100))
        #expect(c == cubic(210, 90, 200, 100, 90, 110))
    }

    @Test
    func createsAbsoluteSmoothCubic() {
        var curve: DOM.Path.Segment
        curve = .cubicSmooth(x2: 80, y2: 40, x: 100, y: 50, space: .absolute)
        var c = LayerTree.Builder.createCubicSmooth(from: curve, last: .zero, previous: Point.zero)
        #expect(c == cubic(100, 50, 0, 0, 80, 40))

        curve = .cubicSmooth(x2: 180, y2: 60, x: 200, y: 50, space: .absolute)
        c = LayerTree.Builder.createCubicSmooth(from: curve, last: Point(100, 50), previous: Point(80, 40))
        #expect(c == cubic(200, 50, 120, 60, 180, 60))
    }

    @Test
    func createsRelativeSmoothCubic() {
        var curve: DOM.Path.Segment
        curve = .cubicSmooth(x2: 80, y2: -10, x: 100, y: 0, space: .relative)
        var c = LayerTree.Builder.createCubicSmooth(from: curve, last: Point(0, 50), previous: Point(0, 50))
        #expect(c == cubic(100, 50, 0, 50, 80, 40))

        curve = .cubicSmooth(x2: 80, y2: 10, x: 100, y: 0, space: .relative)
        c = LayerTree.Builder.createCubicSmooth(from: curve, last: Point(100, 50), previous: Point(80, 40))
        #expect(c == cubic(200, 50, 120, 60, 180, 60))
    }

    @Test
    func createsBalancedQuadratic() {
        //balanced quad with control point centered on the curve
        var quad: DOM.Path.Segment
        quad = .quadratic(
            x1: 150,
            y1: 0,
            x: 300,
            y: 50,
            space: .absolute
        )
        var c = LayerTree.Builder.createQuadratic(from: quad, last: Point(0, 50))

        #expect(c == cubic(300, 50, 100, 16.6666641, 200, 16.6666641))

        quad = .quadratic(
            x1: 150,
            y1: -50,
            x: 300,
            y: 0,
            space: .relative
        )
        c = LayerTree.Builder.createQuadratic(from: quad, last: Point(0, 50))
        #expect(c == cubic(300, 50, 100, 16.6666641, 200, 16.6666641))
    }

    @Test
    func createsUnbalancedQuadratic() {
        //quad with control point to the left
        var quad: DOM.Path.Segment
        quad = .quadratic(
            x1: 100,
            y1: 0,
            x: 300,
            y: 50,
            space: .absolute
        )
        var c = LayerTree.Builder.createQuadratic(from: quad, last: Point(0, 50))

        #expect(c == cubic(300, 50, 66.66667, 16.666664, 166.66666, 16.666664))

        //quad with control point to the right
        quad = .quadratic(
            x1: 200,
            y1: 0,
            x: 300,
            y: 50,
            space: .absolute
        )
        c = LayerTree.Builder.createQuadratic(from: quad, last: Point(0, 50))
        #expect(c == cubic(300, 50, 133.33334, 16.666664, 233.33333, 16.666664))
    }

    @Test
    func createsAbsoluteSmoothQuadratic() {
        var quad: DOM.Path.Segment
        quad = .quadraticSmooth(x: 100, y: 50, space: .absolute)

        let c = LayerTree.Builder.createQuadraticSmooth(from: quad, last: Point(0, 50), previous: Point(-50, 0))
        // the reflected quadratic control point (50, 100) converted to cubic control points
        #expect(c == cubic(100, 50, 33.333336, 83.333336, 66.666664, 83.333336))
    }

    @Test
    func createsClose() {
        #expect(LayerTree.Builder.createClose(from: .close) == Segment.close)
    }

    @Test
    func makesSegmentFromDOMSmoothQuadratic() {
        let domSegment = DOM.Path.Segment.quadraticSmooth(x: 10.0, y: 10.0, space: .relative)
        let segment = LayerTree.Builder.makeSegment(from: domSegment, last: .init(10, 10), previous: nil)

        #expect(
            segment == .cubic(to: .init(20.0, 20.0), control1: .init(10, 10), control2: .init(13.333333, 13.333333))
        )
    }

    @Test
    func makesSegmentFromDOMSmoothCubic() {
        let domSegment = DOM.Path.Segment.cubicSmooth(x2: 10, y2: 10, x: 10, y: 10, space: .relative)
        let segment = LayerTree.Builder.makeSegment(from: domSegment, last: .init(10, 10), previous: nil)

        #expect(segment == .cubic(to: .init(20.0, 20.0), control1: .init(10, 10), control2: .init(20.0, 20.0)))
    }

    @Test
    func directionInverts() {
        #expect(!LayerTree.Path.Direction.anticlockwise == .clockwise)
        #expect(!LayerTree.Path.Direction.clockwise == .anticlockwise)
    }

    @Test
    func clockwiseDirection() {
        let segments: [LayerTree.Path.Segment] = [
            .move(to: Point(10, 10)),
            .line(to: Point(15, 15)),
            .line(to: Point(10, 20)),
            .line(to: Point(5, 10)),
            .close,
        ]

        #expect(segments.direction == .clockwise)
    }

    @Test
    func anticlockwiseDirection() {
        let segments: [LayerTree.Path.Segment] = [
            .move(to: Point(10, 10)),
            .line(to: Point(5, 10)),
            .line(to: Point(10, 20)),
            .line(to: Point(15, 15)),
            .close,
        ]

        #expect(segments.direction == .anticlockwise)
    }

    // helpers to create Segments without labels
    // splatting of tuple is no longer supported
    private func move(_ x: Float, _ y: Float) -> Path.Segment {
        .move(to: Point(x, y))
    }

    private func line(_ x: Float, _ y: Float) -> Path.Segment {
        .line(to: Point(x, y))
    }

    private func cubic(
        _ x: Float,
        _ y: Float,
        _ x1: Float,
        _ y1: Float,
        _ x2: Float,
        _ y2: Float
    ) -> Path.Segment {
        .cubic(to: Point(x, y), control1: Point(x1, y1), control2: Point(x2, y2))
    }
}
