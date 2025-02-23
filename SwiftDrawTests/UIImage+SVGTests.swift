//
//  UIImage+SVGTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 27/11/18.
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

import XCTest
@testable import SwiftDraw

#if canImport(UIKit)
import UIKit

final class UIImageSVGTests: XCTestCase {

    func testImageLoads() {
        let image = UIImage(svgNamed: "lines.svg", in: .test)
        XCTAssertNotNil(image)
    }

    func testMissingImageDoesNotLoad() {
        let image = UIImage(svgNamed: "missing.svg", in: .test)
        XCTAssertNil(image)
    }

    func testImageSize() throws {
        let image = try SVG.parseXML(#"""
            <?xml version="1.0" encoding="UTF-8"?>
            <svg width="64" height="64" version="1.1" xmlns="http://www.w3.org/2000/svg">
            </svg>
            """#
        )
    
        XCTAssertEqual(
            image.rasterize(scale: 1).size,
            CGSize(width: 64, height: 64)
        )
        XCTAssertEqual(
            image.rasterize(scale: 1).scale,
            1
        )
        XCTAssertEqual(
            image.rasterize(scale: 2).size,
            CGSize(width: 64, height: 64)
        )
        XCTAssertEqual(
            image.rasterize(scale: 2).scale,
            2
        )
    }
}

private extension SVG {

    static func parseXML(_ xml: String) throws -> SVG {
        guard let svg = SVG(xml: xml) else {
            throw InvalidSVG()
        }
        return svg
    }

    private struct InvalidSVG: LocalizedError {
        var errorDescription: String? = "Invalid SVG"
    }
}

#endif
