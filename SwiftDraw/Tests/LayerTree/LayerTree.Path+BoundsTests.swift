//
//  LayerTreet.Path+BoundsTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 15/8/22.
//  Copyright 2022 Simon Whitty
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

@testable import SwiftDraw
import Testing

struct LayerTreePathBoundsTests {

    typealias Point = LayerTree.Point
    typealias Rect = LayerTree.Rect

    @Test
    func bounds() {
        let path = LayerTree.Path([
            .move(to: Point(-50, -50)),
            .line(to: Point(50, 50)),
        ])

        #expect(path.bounds == Rect(x: -50, y: -50, width: 100, height: 100))
    }

    @Test
    func boundsWithLines() {
        var finder = LayerTree.Path.BoundsFinder()

        finder.updateBounds(for: [
            .move(to: Point(10, 10)),
            .line(to: Point(100, 100)),
            .line(to: Point(80, 102)),
        ])

        #expect(finder.min == Point(10, 10))
        #expect(finder.max == Point(100, 102))
    }

    @Test
    func boundsWithCubic() {
        var finder = LayerTree.Path.BoundsFinder()

        finder.updateBounds(for: [
            .move(to: Point(10, 10)),
            .line(to: Point(100, 100)),
            .cubic(to: Point(75, 50), control1: Point(120, 100), control2: Point(120, 50)),
        ])

        #expect(finder.min == Point(10, 10))
        #expect(finder.max == Point(112.8, 100))
    }

    @Test
    func boundsWithClose() {
        var finder = LayerTree.Path.BoundsFinder()

        finder.updateBounds(for: [
            .move(to: Point(10, 10)),
            .move(to: Point(50, 50)),
            .line(to: Point(100, 100)),
            .line(to: Point(75, 100)),
            .close,
            .line(to: Point(75, 0)),
        ])

        #expect(finder.min == Point(50, 0))
        #expect(finder.max == Point(100, 100))
    }

    @Test
    func endpointsIgnoreRedundantMoves() {
        let path = LayerTree.Path([
            .move(to: Point(-50, -50)),
            .move(to: Point(0, 0)),
            .move(to: Point(50, 10)),
            .line(to: Point(300, 300)),
            .line(to: Point(200, 15)),
        ])

        #expect(path.endpoints.start == Point(50, 10))
        #expect(path.endpoints.end == Point(200, 15))
    }
}
