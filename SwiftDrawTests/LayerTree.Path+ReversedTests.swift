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
}
