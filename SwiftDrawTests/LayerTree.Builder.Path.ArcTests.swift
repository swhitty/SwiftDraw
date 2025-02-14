//
//  LayerTree.Builder.Path.ArcTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 14/2/25.
//  Copyright 2025 Simon Whitty
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


import XCTest
@testable import SwiftDraw

final class LayerTreeBuilderPathArcTests: XCTestCase {

    func testClamped() {
        XCTAssertEqual(5.clamped(to: 0...10), 5)
        XCTAssertEqual((10.1).clamped(to: 0...10), 10)
        XCTAssertEqual((-1).clamped(to: 0...10), 0)
        XCTAssertEqual(Double.infinity.clamped(to: 0...10), 10)
        XCTAssertEqual((-Double.infinity).clamped(to: 0...10), 0)
        XCTAssertEqual(Double.nan.clamped(to: 0...10), 0)
        XCTAssertEqual((-Double.nan).clamped(to: 0...10), 0)
    }

    func testVectorAngle() {
        XCTAssertEqual(vectorAngle(ux: 1, uy: 1, vx: 1, vy: 1), 0)
        XCTAssertEqual(vectorAngle(ux: 1, uy: 1, vx: -1, vy: 1), 1.5707964, accuracy: 0.001)
        XCTAssertEqual(vectorAngle(ux: 1, uy: 1, vx: .nan, vy: 1), 3.1415925, accuracy: 0.001)
    }
}
