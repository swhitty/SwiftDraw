//
//  LayerTreet.Path+ReversedTests.swift
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

final class LayerTreePathReversedTests: XCTestCase {

    typealias Point = LayerTree.Point
    typealias Rect = LayerTree.Rect

    func testIgnoresRedundantMoves() {
        let path = LayerTree.Path([
            .move(to: Point(100, 100)),
            .line(to: Point(200, 200)),
            .line(to: Point(300, 300))
        ])

        XCTAssertEqual(
            path.reversed.segments,
            [.move(to: Point(300, 300)),
             .line(to: Point(200, 200)),
             .line(to: Point(100, 100))]
        )
    }

    func testCubic() {
        let path = LayerTree.Path([
            .move(to: Point(100, 100)),
            .cubic(to: Point(200, 100), control1: Point(110, 50), control2: Point(190, 50)),
            .line(to: Point(200, 300)),
            .cubic(to: Point(100, 300), control1: Point(190, 350), control2: Point(110, 350)),
            .close
        ])

        XCTAssertEqual(
            path.reversed.segments,
            [.move(to: Point(100, 300)),
             .cubic(to: Point(200, 300), control1: Point(110, 350), control2: Point(190, 350)),
             .line(to: Point(200, 100)),
             .cubic(to: Point(100, 100), control1: Point(190, 50), control2: Point(110, 50)),
             .close]
        )
    }

    func testEvenOddPathDirection() throws {
        let pathData = """
        M12 22C6.47715 22 2 17.5228 2 12C2 6.47715 6.47715 2 12 2C17.5228 2 22 6.47715 22 12C22 17.5228 17.5228 22 12 22Z
        M12 13C11.4477 13 11 12.5523 11 12V8C11 7.44772 11.4477 7 12 7C12.5523 7 13 7.44772 13 8V12C13 12.5523 12.5523 13 12 13
        ZM13 17H11V15H13V17Z
        """
        let domPath = try XMLParser().parsePath(from: pathData)
        let layerPath = try LayerTree.Builder.createPath(from: domPath)

        XCTAssertEqual(
            layerPath.subpaths.map(\.segments.direction),
            [.clockwise, .clockwise, .clockwise]
        )

        XCTAssertEqual(
            layerPath.makeNonZero().subpaths.map(\.segments.direction),
            [.clockwise, .anticlockwise, .anticlockwise]
        )
    }

    func testNonZeroDirection() throws {
        let pathData = """
        M12,22C17.523,22 22,17.523 22,12C22,6.477 17.523,2 12,2C6.477,2 2,6.477 2,12C2,17.523 6.477,22 12,22ZM13,17L11,17L11,15L13,15L13,17ZM12,13C11.448,13 11,12.552 11,12L11,8C11,7.448 11.448,7 12,7C12.552,7 13,7.448 13,8L13,12C13,12.552 12.552,13 12,13Z
        """
        let domPath = try XMLParser().parsePath(from: pathData)
        let layerPath = try LayerTree.Builder.createPath(from: domPath)

        XCTAssertEqual(
            layerPath.subpaths.map(\.segments.direction),
            [.anticlockwise, .clockwise, .clockwise]
        )

        XCTAssertEqual(
            layerPath.makeNonZero().subpaths.map(\.segments.direction),
            [.anticlockwise, .clockwise, .clockwise]
        )
    }
}
