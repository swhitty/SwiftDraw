//
//  LayerTreet.Path+SubpathTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 21/8/22.
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

final class LayerTreePathSubpathTests: XCTestCase {

    typealias Point = LayerTree.Point
    typealias Rect = LayerTree.Rect

    func testIgnoresRedundantMoves() {
        let path = LayerTree.Path([
            .move(to: Point(-50, -50)),
            .move(to: Point(100, 100)),
            .line(to: Point(200, 200)),
            .move(to: Point(-50, -50)),
            .move(to: Point(0, 0)),
            .line(to: Point(0, 200))
        ])

        XCTAssertEqual(
            path.subpaths.count, 1
        )

        XCTAssertEqual(
            path.subpaths[0].segments,
            [.move(to: Point(100, 100)),
             .line(to: Point(200, 200)),
             .move(to: Point(0, 0)),
             .line(to: Point(0, 200))]
        )
    }

    func testClosedPathsStartNewSubpath() {
        let path = LayerTree.Path([
            .move(to: Point(100, 100)),
            .line(to: Point(200, 200)),
            .line(to: Point(200, 100)),
            .close,
            .line(to: Point(0, 200)),
            .line(to: Point(0, 100)),
            .close,
            .move(to: Point(500, 500))
        ])

        XCTAssertEqual(
            path.subpaths.count, 2
        )

        XCTAssertEqual(
            path.subpaths[0].segments.direction,
            .anticlockwise
        )
        XCTAssertEqual(
            path.subpaths[0].segments,
            [.move(to: Point(100, 100)),
             .line(to: Point(200, 200)),
             .line(to: Point(200, 100)),
             .close]
        )

        XCTAssertEqual(
            path.subpaths[1].segments.direction,
            .clockwise
        )
        XCTAssertEqual(
            path.subpaths[1].segments,
            [.move(to: Point(100, 100)),
             .line(to: Point(0, 200)),
             .line(to: Point(0, 100)),
             .close]
        )
    }
}
