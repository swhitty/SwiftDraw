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
import XCTest

final class LayerTreePathBoundsTests: XCTestCase {

    typealias Point = LayerTree.Point
    typealias Rect = LayerTree.Rect

    func testBounds() {
        let path = LayerTree.Path([
            .move(to: Point(-50, -50)),
            .line(to: Point(50, 50))
        ])
        
        XCTAssertEqual(
            path.bounds,
            Rect(x: -50, y: -50, width: 100, height: 100)
        )
    }

    func testBoundsWithLines() {
        var finder = LayerTree.Path.BoundsFinder()

        finder.updateBounds(for: [
            .move(to: Point(10,10)),
            .line(to: Point(100,100)),
            .line(to: Point(80, 102))
        ])

        XCTAssertEqual(
            finder.min,
            Point(10,10)
        )

        XCTAssertEqual(
            finder.max,
            Point(100,102)
        )
    }

    func testBoundsWithCubic() {
        var finder = LayerTree.Path.BoundsFinder()

        finder.updateBounds(for: [
            .move(to: Point(10,10)),
            .line(to: Point(100,100)),
            .cubic(to: Point(75, 50), control1: Point(120, 100), control2: Point(120, 50))
        ])

        XCTAssertEqual(
            finder.min,
            Point(10,10)
        )

        XCTAssertEqual(
            finder.max,
            Point(112.8,100)
        )
    }

    func testBoundsWithClose() {
        var finder = LayerTree.Path.BoundsFinder()

        finder.updateBounds(for: [
            .move(to: Point(10,10)),
            .move(to: Point(50,50)),
            .line(to: Point(100, 100)),
            .line(to: Point(75, 100)),
            .close,
            .line(to: Point(75, 0))
        ])

        XCTAssertEqual(
            finder.min,
            Point(50,0)
        )

        XCTAssertEqual(
            finder.max,
            Point(100,100)
        )
    }
}
