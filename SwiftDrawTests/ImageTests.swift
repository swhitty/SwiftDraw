//
//  ScannerTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 19/11/18.
//  Copyright 2018 Simon Whitty
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

final class ImageTests: XCTestCase {

    func testValidSVGLoads() {
        XCTAssertNotNil(Image(named: "lines.svg", in: .test))
    }

    func testInvalidSVGReturnsNil() {
        XCTAssertNil(Image(named: "invalid.svg", in: .test))
    }

    func testMissingSVGReturnsNil() {
        XCTAssertNil(Image(named: "missing.svg", in: .test))
    }

    func testImageRasterizes() {
        let image = Image(named: "lines.svg", in: .test)!
        let rendered = image.rasterize()
        XCTAssertEqual(rendered.size, image.size)
        XCTAssertNotNil(image.pngData())
    }

    func testImageRasterizeAndScales() {
        let image = Image(named: "lines.svg", in: .test)!
        let doubleSize = CGSize(width: 200, height: 200)
        let rendered = image.rasterize(with: doubleSize)
        XCTAssertEqual(rendered.size, doubleSize)
        XCTAssertNotNil(image.pngData(size: doubleSize))
    }

}
