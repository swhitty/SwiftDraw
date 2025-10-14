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
import XCTest
@testable import SwiftDraw
import CoreGraphics

final class ImageCoreGraphicsTests: XCTestCase {

    func testPixelWide() {
        XCTAssertEqual(
            SVG.makeBounds(size: CGSize(width: 100, height: 50),
                           scale: 1).pixelsWide,
            100
        )
        XCTAssertEqual(
            SVG.makeBounds(size: CGSize(width: 100.5, height: 50),
                           scale: 1).pixelsWide,
            101
        )
        XCTAssertEqual(
            SVG.makeBounds(size: CGSize(width: 100, height: 50),
                           scale: 2).pixelsWide,
            200
        )
        XCTAssertEqual(
            SVG.makeBounds(size: CGSize(width: 300, height: 200),
                           scale: 1).pixelsWide,
            300
        )
        XCTAssertEqual(
            SVG.makeBounds(size: CGSize(width: 300, height: 200),
                           scale: 2).pixelsWide,
            600
        )
    }

    func testPixelHigh() {
        XCTAssertEqual(
            SVG.makeBounds(size: CGSize(width: 100, height: 50),
                           scale: 1).pixelsHigh,
            50
        )
        XCTAssertEqual(
            SVG.makeBounds(size: CGSize(width: 100, height: 50.5),
                           scale: 1).pixelsHigh,
            51
        )
        XCTAssertEqual(
            SVG.makeBounds(size: CGSize(width: 100, height: 50),
                           scale: 2).pixelsHigh,
            100
        )
        XCTAssertEqual(
            SVG.makeBounds(size: CGSize(width: 300, height: 200),
                           scale: 1).pixelsHigh,
            200
        )
        XCTAssertEqual(
            SVG.makeBounds(size: CGSize(width: 300, height: 200),
                           scale: 2).pixelsHigh,
            400
        )
    }
}

#endif
