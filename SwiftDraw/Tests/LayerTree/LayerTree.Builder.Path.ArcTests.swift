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

@testable import SwiftDraw
import Testing

struct LayerTreeBuilderPathArcTests {

    @Test
    func clampedLimitsValueToRange() {
        #expect(5.clamped(to: 0...10) == 5)
        #expect((10.1).clamped(to: 0...10) == 10)
        #expect((-1).clamped(to: 0...10) == 0)
        #expect(Double.infinity.clamped(to: 0...10) == 10)
        #expect((-Double.infinity).clamped(to: 0...10) == 0)
        #expect(Double.nan.clamped(to: 0...10) == 0)
        #expect((-Double.nan).clamped(to: 0...10) == 0)
    }

    @Test
    func vectorAngleBetweenVectors() {
        #expect(vectorAngle(ux: 1, uy: 1, vx: 1, vy: 1) == 0)
        #expect(vectorAngle(ux: 1, uy: 1, vx: -1, vy: 1).isApproximately(1.5707964, tolerance: 0.001))
        #expect(vectorAngle(ux: 1, uy: 1, vx: .nan, vy: 1).isApproximately(3.1415925, tolerance: 0.001))
    }
}
