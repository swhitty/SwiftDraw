//
//  CGRenderer+FilterTests.swift
//  SwiftDraw
//
//  Created by Misoservices on 8/10/26.
//  Copyright 2026 Misoservices. Altered version of SwiftDraw by Simon Whitty.
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
@testable import SwiftDraw
import CoreGraphics
import XCTest

final class CGRendererFilterTests: XCTestCase {

    // 100x100 bitmap, black square 25...75 blurred by stdDeviation 5, filter region 20...80
    func testGaussianBlurSoftensEdges() throws {
        let bitmap = try render(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="blur"><feGaussianBlur stdDeviation="5" /></filter>
            <rect x="25" y="25" width="50" height="50" fill="black" filter="url(#blur)" />
        </svg>
        """#)

        // centre is opaque, the edge is half covered, the blur spreads outside the shape
        XCTAssertGreaterThan(bitmap.alpha(x: 50, y: 50), 0.95)
        XCTAssertEqual(bitmap.alpha(x: 25, y: 50), 0.5, accuracy: 0.15)
        XCTAssertGreaterThan(bitmap.alpha(x: 22, y: 50), 0.05)
        XCTAssertLessThan(bitmap.alpha(x: 28, y: 50), 0.95)
        // nothing is drawn outside the filter region
        XCTAssertEqual(bitmap.alpha(x: 10, y: 50), 0)
        XCTAssertEqual(bitmap.alpha(x: 50, y: 90), 0)
    }

    func testGaussianBlurHonoursDeviceScale() throws {
        let bitmap = try render(#"""
        <svg width="50" height="50" xmlns="http://www.w3.org/2000/svg">
            <filter id="blur"><feGaussianBlur stdDeviation="2.5" /></filter>
            <rect x="12.5" y="12.5" width="25" height="25" fill="black" filter="url(#blur)" />
        </svg>
        """#, scale: 2)

        // same picture as above in 2x device pixels
        XCTAssertGreaterThan(bitmap.alpha(x: 50, y: 50), 0.95)
        XCTAssertEqual(bitmap.alpha(x: 25, y: 50), 0.5, accuracy: 0.15)
        XCTAssertGreaterThan(bitmap.alpha(x: 22, y: 50), 0.05)
        XCTAssertEqual(bitmap.alpha(x: 10, y: 50), 0)
    }

    func testVerticalOnlyBlur() throws {
        let bitmap = try render(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="blur"><feGaussianBlur stdDeviation="0 5" /></filter>
            <rect x="25" y="25" width="50" height="50" fill="black" filter="url(#blur)" />
        </svg>
        """#)

        // left edge stays hard, top edge is soft
        XCTAssertEqual(bitmap.alpha(x: 24, y: 50), 0)
        XCTAssertGreaterThan(bitmap.alpha(x: 26, y: 50), 0.95)
        XCTAssertEqual(bitmap.alpha(x: 50, y: 25), 0.5, accuracy: 0.15)
    }

    func testUnfilteredDrawingAfterFilterLayer() throws {
        let bitmap = try render(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="blur"><feGaussianBlur stdDeviation="5" /></filter>
            <rect x="0" y="0" width="20" height="20" fill="red" filter="url(#blur)" />
            <rect x="60" y="60" width="40" height="40" fill="red" />
        </svg>
        """#)

        XCTAssertEqual(bitmap.alpha(x: 61, y: 61), 1)
        XCTAssertEqual(bitmap.alpha(x: 59, y: 61), 0)
    }

    func testBoxSizes() {
        XCTAssertEqual(CGContext.boxSizes(for: 0), [1, 1, 1])
        XCTAssertEqual(CGContext.boxSizes(for: 2), [5, 3, 5])
        XCTAssertEqual(CGContext.boxSizes(for: 5), [9, 9, 9])
    }
}

private struct Bitmap {
    var width: Int
    var height: Int
    var bytes: [UInt8]

    // y is measured from the top, like SVG
    func alpha(x: Int, y: Int) -> Double {
        Double(bytes[(y * width + x) * 4 + 3]) / 255
    }
}

private extension CGRendererFilterTests {

    func render(_ xml: String, scale: CGFloat = 1) throws -> Bitmap {
        let svg = try XCTUnwrap(SVG(xml: xml))
        let width = Int(svg.size.width * scale)
        let height = Int(svg.size.height * scale)
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        bytes.withUnsafeMutableBytes { buffer in
            let ctx = CGContext(data: buffer.baseAddress, width: width, height: height,
                                bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            // SVG coordinates are y-down
            ctx.translateBy(x: 0, y: CGFloat(height))
            ctx.scaleBy(x: scale, y: -scale)
            ctx.draw(svg)
        }
        return Bitmap(width: width, height: height, bytes: bytes)
    }
}
#endif
