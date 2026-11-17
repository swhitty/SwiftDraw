//
//  ColorTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 3/6/17.
//  Copyright 2020 WhileLoop Pty Ltd. All rights reserved.
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

import SwiftDrawDOM
@testable import SwiftDraw
import Testing

struct LayerTreeColorTests {

    typealias Color = LayerTree.Color

    let noColor = Color.none
    let someColor = Color.srgb(r: 0.1, g: 0.2, b: 0.3, a: 0.4)
    let anotherColor = Color.srgb(r: 0.4, g: 0.3, b: 0.2, a: 0.1)

    @Test
    func blackAndWhiteAreOpaqueSRGB() {
        #expect(Color.black == .srgb(r: 0, g: 0, b: 0, a: 1.0))
        #expect(Color.white == .srgb(r: 1, g: 1, b: 1, a: 1.0))
    }

    @Test
    func withAlpha() {
        //test alpha can be easily adjusted on rgba values
        //apha 0.0 == .none

        //.none color cannot change alpha
        #expect(noColor.withAlpha(1.0).maybeNone() == .none)
        #expect(noColor.withAlpha(0.5).maybeNone() == .none)
        #expect(noColor.withAlpha(0.3).maybeNone() == .none)
        #expect(noColor.withAlpha(0.0).maybeNone() == .none)

        #expect(someColor.withAlpha(1.0).maybeNone() == .srgb(r: 0.1, g: 0.2, b: 0.3, a: 0.4 * 1))
        #expect(someColor.withAlpha(0.5).maybeNone() == .srgb(r: 0.1, g: 0.2, b: 0.3, a: 0.4 * 0.5))
        #expect(someColor.withAlpha(0.3).maybeNone() == .srgb(r: 0.1, g: 0.2, b: 0.3, a: 0.4 * 0.3))
        #expect(someColor.withAlpha(0.0).maybeNone() == .none)

        #expect(anotherColor.withAlpha(1.0).maybeNone() == .srgb(r: 0.4, g: 0.3, b: 0.2, a: 0.1 * 1))
        #expect(anotherColor.withAlpha(0.5).maybeNone() == .srgb(r: 0.4, g: 0.3, b: 0.2, a: 0.1 * 0.5))
        #expect(anotherColor.withAlpha(0.3).maybeNone() == .srgb(r: 0.4, g: 0.3, b: 0.2, a: 0.1 * 0.3))
        #expect(anotherColor.withAlpha(0.0).maybeNone() == .none)
    }

    @Test
    func multiplyingAlpha() {
        //test alpha can be easily multiplied on rgba values
        //apha 0.0 == .none

        #expect(noColor.withMultiplyingAlpha(1.0) == .none)
        #expect(noColor.withMultiplyingAlpha(0.5) == .none)
        #expect(noColor.withMultiplyingAlpha(0.3) == .none)
        #expect(noColor.withMultiplyingAlpha(0.0) == .none)

        #expect(someColor.withMultiplyingAlpha(1.0) == .srgb(r: 0.1, g: 0.2, b: 0.3, a: 0.4))
        #expect(someColor.withMultiplyingAlpha(0.5) == .srgb(r: 0.1, g: 0.2, b: 0.3, a: 0.2))
        #expect(someColor.withMultiplyingAlpha(0.0).maybeNone() == .none)

        #expect(anotherColor.withMultiplyingAlpha(1.0) == .srgb(r: 0.4, g: 0.3, b: 0.2, a: 0.1))
        #expect(anotherColor.withMultiplyingAlpha(0.5) == .srgb(r: 0.4, g: 0.3, b: 0.2, a: 0.05))
        #expect(anotherColor.withMultiplyingAlpha(0.0).maybeNone() == .none)
    }

    @Test
    func rgbIntegerComponents() {
        //a color can be created from (UInt8, UInt8, UInt8)

        #expect(Color(UInt8(102), UInt8(102), UInt8(102)) == .srgb(r: 0.4, g: 0.4, b: 0.4, a: 1.0))
        #expect(Color(UInt8(102), UInt8(0), UInt8(102)) == .srgb(r: 0.4, g: 0.0, b: 0.4, a: 1.0))
        #expect(Color(UInt8(102), UInt8(102), UInt8(0)) == .srgb(r: 0.4, g: 0.4, b: 0.0, a: 1.0))

        #expect(Color(UInt8(204), UInt8(204), UInt8(204)) == .srgb(r: 0.8, g: 0.8, b: 0.8, a: 1.0))
        #expect(Color(UInt8(204), UInt8(0), UInt8(204)) == .srgb(r: 0.8, g: 0.0, b: 0.8, a: 1.0))
        #expect(Color(UInt8(204), UInt8(204), UInt8(0)) == .srgb(r: 0.8, g: 0.8, b: 0.0, a: 1.0))
    }

    @Test
    func initFromDOMColor() {
        // DOM.Color converts correctly

        let none = DOM.Color.none
        let black = DOM.Color.keyword(.black)
        let white = DOM.Color.keyword(.white)
        let red = DOM.Color.rgbi(255, 0, 0, 1.0)
        let green = DOM.Color.rgbi(0, 255, 0, 1.0)
        let blue = DOM.Color.rgbi(0, 0, 255, 1.0)

        #expect(Color(none) == .none)
        #expect(Color(black) == .srgb(r: 0.0, g: 0.0, b: 0.0, a: 1.0))
        #expect(Color(white) == .srgb(r: 1.0, g: 1.0, b: 1.0, a: 1.0))
        #expect(Color(red) == .srgb(r: 1.0, g: 0.0, b: 0.0, a: 1.0))
        #expect(Color(green) == .srgb(r: 0.0, g: 1.0, b: 0.0, a: 1.0))
        #expect(Color(blue) == .srgb(r: 0.0, g: 0.0, b: 1.0, a: 1.0))
    }

    @Test
    func currentColorResolvesToCurrent() {
        // DOM.Color converts correctly

        let none = DOM.Color.none
        let black = DOM.Color.keyword(.black)
        let white = DOM.Color.keyword(.white)

        #expect(Color.create(from: .currentColor, current: none) == .none)
        #expect(Color.create(from: .currentColor, current: black) == Color(black))
        #expect(Color.create(from: .currentColor, current: white) == Color(white))
    }
}

extension LayerTree.Color {

    init(_ color: DOM.Color) {
        self = LayerTree.Color.create(from: color, current: .none)
    }

    static func srgb(
        r: LayerTree.Float,
        g: LayerTree.Float,
        b: LayerTree.Float,
        a: LayerTree.Float
    ) -> Self {
        .rgba(r: r, g: g, b: b, a: a, space: .srgb)
    }
}
