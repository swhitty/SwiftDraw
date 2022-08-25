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

    func testPixelWide_WithInsetsZero() {
        XCTAssertEqual(
            SVG.makeBounds(size: nil,
                           defaultSize: CGSize(width: 100, height: 50),
                           scale: 1,
                           insets: .zero).pixelsWide,
            100
        )
        XCTAssertEqual(
            SVG.makeBounds(size: nil,
                           defaultSize: CGSize(width: 100, height: 50),
                           scale: 2,
                           insets: .zero).pixelsWide,
            200
        )
        XCTAssertEqual(
            SVG.makeBounds(size: CGSize(width: 300, height: 200),
                           defaultSize: CGSize(width: 100, height: 50),
                           scale: 1,
                           insets: .zero).pixelsWide,
            300
        )
        XCTAssertEqual(
            SVG.makeBounds(size: CGSize(width: 300, height: 200),
                           defaultSize: CGSize(width: 100, height: 50),
                           scale: 2,
                           insets: .zero).pixelsWide,
            600
        )
    }

    func testPixelHigh_WithInsetsZero() {
        XCTAssertEqual(
            SVG.makeBounds(size: nil,
                           defaultSize: CGSize(width: 100, height: 50),
                           scale: 1,
                           insets: .zero).pixelsHigh,
            50
        )
        XCTAssertEqual(
            SVG.makeBounds(size: nil,
                           defaultSize: CGSize(width: 100, height: 50),
                           scale: 2,
                           insets: .zero).pixelsHigh,
            100
        )
        XCTAssertEqual(
            SVG.makeBounds(size: CGSize(width: 300, height: 200),
                           defaultSize: CGSize(width: 100, height: 50),
                           scale: 1,
                           insets: .zero).pixelsHigh,
            200
        )
        XCTAssertEqual(
            SVG.makeBounds(size: CGSize(width: 300, height: 200),
                           defaultSize: CGSize(width: 100, height: 50),
                           scale: 2,
                           insets: .zero).pixelsHigh,
            400
        )
    }

    func testPixelWide_WithInsets() {
        XCTAssertEqual(
            SVG.makeBounds(size: nil,
                           defaultSize: CGSize(width: 100, height: 50),
                           scale: 1,
                           insets: .make(left: 5, right: 20)).pixelsWide,
            75
        )
        XCTAssertEqual(
            SVG.makeBounds(size: nil,
                           defaultSize: CGSize(width: 100, height: 50),
                           scale: 2,
                           insets: .make(left: 5, right: 20)).pixelsWide,
            150
        )
        XCTAssertEqual(
            SVG.makeBounds(size: CGSize(width: 300, height: 200),
                           defaultSize: CGSize(width: 100, height: 50),
                           scale: 1,
                           insets: .make(left: 5, right: 20)).pixelsWide,
            300
        )
        XCTAssertEqual(
            SVG.makeBounds(size: CGSize(width: 300, height: 200),
                           defaultSize: CGSize(width: 100, height: 50),
                           scale: 2,
                           insets: .make(left: 5, right: 20)).pixelsWide,
            600
        )
    }

    func testPixelHigh_WithInsets() {
        XCTAssertEqual(
            SVG.makeBounds(size: nil,
                           defaultSize: CGSize(width: 100, height: 50),
                           scale: 1,
                           insets: .make(top: 15, bottom: 30)).pixelsHigh,
            5
        )
        XCTAssertEqual(
            SVG.makeBounds(size: nil,
                           defaultSize: CGSize(width: 100, height: 50),
                           scale: 2,
                           insets: .make(top: 15, bottom: 30)).pixelsHigh,
            10
        )
        XCTAssertEqual(
            SVG.makeBounds(size: CGSize(width: 300, height: 200),
                           defaultSize: CGSize(width: 100, height: 50),
                           scale: 1,
                           insets: .make(top: 15, bottom: 30)).pixelsHigh,
            200
        )
        XCTAssertEqual(
            SVG.makeBounds(size: CGSize(width: 300, height: 200),
                           defaultSize: CGSize(width: 100, height: 50),
                           scale: 2,
                           insets: .make(top: 15, bottom: 30)).pixelsHigh,
            400
        )
    }

    func testBounds_WithInsetsZero() {
        XCTAssertEqual(
            SVG.makeBounds(size: nil,
                           defaultSize: CGSize(width: 100, height: 50),
                           scale: 1,
                           insets: .zero).bounds,
            CGRect(x: 0, y: 0, width: 100, height: 50)
        )
        XCTAssertEqual(
            SVG.makeBounds(size: nil,
                           defaultSize: CGSize(width: 100, height: 50),
                           scale: 2,
                           insets: .zero).bounds,
            CGRect(x: 0, y: 0, width: 200, height: 100)
        )
        XCTAssertEqual(
            SVG.makeBounds(size: CGSize(width: 300, height: 200),
                           defaultSize: CGSize(width: 100, height: 50),
                           scale: 1,
                           insets: .zero).bounds,
            CGRect(x: 0, y: 0, width: 300, height: 200)
        )
        XCTAssertEqual(
            SVG.makeBounds(size: CGSize(width: 300, height: 200),
                           defaultSize: CGSize(width: 100, height: 50),
                           scale: 2,
                           insets: .zero).bounds,
            CGRect(x: 0, y: 0, width: 600, height: 400)
        )
    }

    func testBounds_WithInsets() {
        XCTAssertEqual(
            SVG.makeBounds(size: nil,
                           defaultSize: CGSize(width: 100, height: 50),
                           scale: 1,
                           insets: .make(top: 5, left: 10, bottom: 15, right: 20)).bounds,
            CGRect(x: -10, y: -5, width: 100, height: 50)
        )
        XCTAssertEqual(
            SVG.makeBounds(size: nil,
                           defaultSize: CGSize(width: 100, height: 50),
                           scale: 2,
                           insets: .make(top: 5, left: 10, bottom: 15, right: 20)).bounds,
            CGRect(x: -20, y: -10, width: 200, height: 100)
        )
        XCTAssertEqual(
            SVG.makeBounds(size: CGSize(width: 200, height: 200),
                           defaultSize: CGSize(width: 100, height: 100),
                           scale: 1,
                           insets: .make(top: 10, left: 10, bottom: 10, right: 10)).bounds,
            CGRect(x: -25, y: -25, width: 250, height: 250)
        )
        XCTAssertEqual(
            SVG.makeBounds(size: CGSize(width: 200, height: 200),
                           defaultSize: CGSize(width: 100, height: 100),
                           scale: 2,
                           insets: .make(top: 10, left: 10, bottom: 10, right: 10)).bounds,
            CGRect(x: -50, y: -50, width: 500, height: 500)
        )
    }
}

private extension SVG.Insets {
    static func make(top: CGFloat = 0,
                     left: CGFloat = 0,
                     bottom: CGFloat = 0,
                     right: CGFloat = 0) -> Self {
        Self(top: top, left: left, bottom: bottom, right: right)
    }
}

#endif
