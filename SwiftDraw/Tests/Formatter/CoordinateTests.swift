//
//  CoordinateTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright 2020 Simon Whitty
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

import Testing
@testable import SwiftDraw

struct CoordinateTests {

    @Test(
        arguments: [
            (1.0, "1.0"),
            (1.01, "1.01"),
            (1.001, "1.001"),
            (1.0001, "1.0001"),
            (1.00001, "1.00001"),
            (1.000001, "1.000001"),
            (1.0000001, "1.0000001"),
            (1e-20, "1e-20"),
            (12e-20, "1.2e-19"),
        ] as [(Double, String)]
    )
    func maximumPrecision(value: Double, expected: String) {
        let f = CoordinateFormatter(precision: .maximum)
        #expect(f.format(value) == expected)
    }

    @Test(
        arguments: [
            (1.0, "1"),
            (1.01, "1.01"),
            (1.001, "1.001"),
            (1.0001, "1.0001"),
            (1.00001, "1"),
            (1.000001, "1"),
            (1.0000001, "1"),
            (1e-20, "0"),
            (12e-20, "0"),
        ] as [(Double, String)]
    )
    func precisionCappedAtFourPlaces(value: Double, expected: String) {
        let f = CoordinateFormatter(precision: .capped(max: 4))
        #expect(f.format(value) == expected)
    }

    @Test(
        arguments: [
            (1.0, "1"),
            (1.01, "1.01"),
            (114.052001953125, "114.05"),
            (1.001, "1"),
            (1.0001, "1"),
            (1.00001, "1"),
            (1.000001, "1"),
            (1.0000001, "1"),
            (1e-20, "0"),
            (12e-20, "0"),
        ] as [(Double, String)]
    )
    func precisionCappedAtTwoPlaces(value: Double, expected: String) {
        let f = CoordinateFormatter(precision: .capped(max: 2))
        #expect(f.format(value) == expected)
    }

    @Test
    func precisionCanBeOverriddenPerCall() {
        let f = CoordinateFormatter(precision: .capped(max: 2))

        #expect(f.format(114.052001953125, precision: .capped(max: 4)) == "114.052")
        #expect(f.format(1.0001, precision: .capped(max: 4)) == "1.0001")
    }

    @Test(
        arguments: [
            (.space, "2.05 4.5", "2.05 4.5 10 20"),
            (.comma, "2.05,4.5", "2.05,4.5,10,20"),
            (.commaSpace, "2.05, 4.5", "2.05, 4.5, 10, 20"),
        ] as [(CoordinateFormatter.Delimeter, String, String)]
    )
    func delimeterSeparatesCoordinates(delimeter: CoordinateFormatter.Delimeter, two: String, four: String) {
        let f = CoordinateFormatter(delimeter: delimeter)

        #expect(f.format(2.05) == "2.05")
        #expect(f.format(2.05, 4.5) == two)
        #expect(f.format(2.05, 4.5, 10, 20) == four)
    }
}
