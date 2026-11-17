//
//  Image+CoreGraphicsTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 24/8/22.
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

#if canImport(CoreGraphics)
import Testing
@testable import SwiftDraw
import CoreGraphics

struct ImageCoreGraphicsTests {

    @Test(
        arguments: [
            (CGSize(width: 100, height: 50), 1, 100),
            (CGSize(width: 100.5, height: 50), 1, 101),
            (CGSize(width: 100, height: 50), 2, 200),
            (CGSize(width: 300, height: 200), 1, 300),
            (CGSize(width: 300, height: 200), 2, 600),
        ] as [(CGSize, CGFloat, Int)]
    )
    func pixelsWide(size: CGSize, scale: CGFloat, expected: Int) {
        #expect(SVG.makeBounds(size: size, scale: scale).pixelsWide == expected)
    }

    @Test(
        arguments: [
            (CGSize(width: 100, height: 50), 1, 50),
            (CGSize(width: 100, height: 50.5), 1, 51),
            (CGSize(width: 100, height: 50), 2, 100),
            (CGSize(width: 300, height: 200), 1, 200),
            (CGSize(width: 300, height: 200), 2, 400),
        ] as [(CGSize, CGFloat, Int)]
    )
    func pixelsHigh(size: CGSize, scale: CGFloat, expected: Int) {
        #expect(SVG.makeBounds(size: size, scale: scale).pixelsHigh == expected)
    }
}

#endif
