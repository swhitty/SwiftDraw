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
        XCTAssertEqual(CGContext.boxSizes(for: .infinity), [1, 1, 1])
        XCTAssertEqual(CGContext.boxSizes(for: .nan), [1, 1, 1])
        XCTAssertEqual(CGContext.boxSizes(for: 1e300, limit: 201), [201, 201, 201])
        XCTAssertEqual(CGContext.boxSizes(for: 1e6, limit: 1024 | 1), [1025, 1025, 1025])
        XCTAssertFalse(CGContext.isVisibleBlur(CGSize(width: 0.3, height: 0.3), scale: 1))
        XCTAssertTrue(CGContext.isVisibleBlur(CGSize(width: 0, height: 2), scale: 1))
    }

    // the clip-path applies to the blurred result: a hard edge at the clip, the blur kept inside it
    func testBlurThenClip() throws {
        let bitmap = try render(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="blur" x="-1" y="-1" width="3" height="3"><feGaussianBlur stdDeviation="2" /></filter>
            <clipPath id="left"><rect x="0" y="0" width="50" height="100" /></clipPath>
            <rect x="10" y="10" width="41" height="30" fill="black" clip-path="url(#left)" filter="url(#blur)" />
            <rect x="10" y="60" width="39" height="30" fill="black" clip-path="url(#left)" filter="url(#blur)" />
        </svg>
        """#)

        // edge at x=51 (outside the clip): blurred first, so x=49 stays dark and x=50 is cut
        XCTAssertGreaterThan(bitmap.alpha(x: 49, y: 25), 0.65)
        XCTAssertEqual(bitmap.alpha(x: 50, y: 25), 0)
        // edge at x=49 (inside the clip): the blur falls off before the clip
        XCTAssertEqual(bitmap.alpha(x: 49, y: 75), 0.4, accuracy: 0.15)
        XCTAssertEqual(bitmap.alpha(x: 50, y: 75), 0)
    }

    // blurred groups are rasterized at 2x in PDF contexts
    func testPDFContextSmoke() throws {
        let svg = try XCTUnwrap(SVG(xml: #"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="blur"><feGaussianBlur stdDeviation="5" /></filter>
            <rect x="25" y="25" width="50" height="50" fill="black" filter="url(#blur)" />
        </svg>
        """#))
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 100, height: 100)
        let consumer = try XCTUnwrap(CGDataConsumer(data: data as CFMutableData))
        let ctx = try XCTUnwrap(CGContext(consumer: consumer, mediaBox: &box, nil))
        ctx.beginPDFPage(nil)
        ctx.draw(svg)
        ctx.endPDFPage()
        ctx.closePDF()

        XCTAssertGreaterThan(data.length, 1000)
    }

    // shape near the top: catches a vertically flipped composite
    func testOffCentreBlurIsNotFlipped() throws {
        let bitmap = try render(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="blur"><feGaussianBlur stdDeviation="3" /></filter>
            <rect x="20" y="10" width="60" height="20" fill="black" filter="url(#blur)" />
        </svg>
        """#)

        XCTAssertGreaterThan(bitmap.alpha(x: 50, y: 20), 0.9)
        XCTAssertEqual(bitmap.alpha(x: 50, y: 10), 0.5, accuracy: 0.15)
        XCTAssertEqual(bitmap.alpha(x: 50, y: 30), 0.5, accuracy: 0.15)
        XCTAssertEqual(bitmap.alpha(x: 50, y: 80), 0)
    }

    func testBlurWithOpacityAndClip() throws {
        let bitmap = try render(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="blur"><feGaussianBlur stdDeviation="2" /></filter>
            <clipPath id="left"><rect x="0" y="0" width="50" height="100" /></clipPath>
            <rect x="20" y="20" width="60" height="60" fill="black" opacity="0.5"
                  clip-path="url(#left)" filter="url(#blur)" />
        </svg>
        """#)

        XCTAssertEqual(bitmap.alpha(x: 40, y: 50), 0.5, accuracy: 0.05)
        XCTAssertEqual(bitmap.alpha(x: 60, y: 50), 0)
        XCTAssertEqual(bitmap.alpha(x: 20, y: 50), 0.25, accuracy: 0.1)
    }

    func testBlurWithMask() throws {
        let bitmap = try render(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="blur"><feGaussianBlur stdDeviation="2" /></filter>
            <mask id="top"><rect x="0" y="0" width="100" height="50" fill="white" /></mask>
            <rect x="20" y="20" width="60" height="60" fill="black" mask="url(#top)" filter="url(#blur)" />
        </svg>
        """#)

        XCTAssertGreaterThan(bitmap.alpha(x: 50, y: 40), 0.9)
        XCTAssertEqual(bitmap.alpha(x: 50, y: 60), 0)
        XCTAssertEqual(bitmap.alpha(x: 20, y: 40), 0.5, accuracy: 0.15)
    }

    // stdDeviation "0 5" is vertical in user space, horizontal after rotate(90)
    func testBlurFollowsRotation() throws {
        let bitmap = try render(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="blur"><feGaussianBlur stdDeviation="0 5" /></filter>
            <rect x="25" y="25" width="50" height="50" fill="black" transform="rotate(90 50 50)" filter="url(#blur)" />
        </svg>
        """#)

        XCTAssertEqual(bitmap.alpha(x: 25, y: 50), 0.5, accuracy: 0.15)
        XCTAssertEqual(bitmap.alpha(x: 50, y: 24), 0)
        XCTAssertGreaterThan(bitmap.alpha(x: 50, y: 26), 0.95)
    }

    func testNestedBlurs() throws {
        let bitmap = try render(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="blur" x="-0.5" y="-0.5" width="2" height="2"><feGaussianBlur stdDeviation="2" /></filter>
            <g filter="url(#blur)">
                <rect x="20" y="20" width="20" height="20" fill="black" filter="url(#blur)" />
                <rect x="60" y="60" width="20" height="20" fill="black" />
            </g>
            <rect x="0" y="90" width="10" height="10" fill="black" />
        </svg>
        """#)

        // the inner rect is blurred twice, so softer than the outer one at the same edge offset
        XCTAssertLessThan(bitmap.alpha(x: 21, y: 30), bitmap.alpha(x: 61, y: 70))
        XCTAssertGreaterThan(bitmap.alpha(x: 30, y: 30), 0.9)
        XCTAssertGreaterThan(bitmap.alpha(x: 70, y: 70), 0.9)
        XCTAssertEqual(bitmap.alpha(x: 5, y: 95), 1)
    }

    // over the pixel cap the layer is rendered at a reduced scale, still blurred
    func testOverPixelCapStillBlurs() throws {
        let bitmap = try render(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="blur"><feGaussianBlur stdDeviation="5" /></filter>
            <rect x="25" y="25" width="50" height="50" fill="black" filter="url(#blur)" />
        </svg>
        """#, maxFilterLayerPixels: 900)

        XCTAssertGreaterThan(bitmap.alpha(x: 50, y: 50), 0.9)
        XCTAssertEqual(bitmap.alpha(x: 25, y: 50), 0.5, accuracy: 0.2)
        XCTAssertEqual(bitmap.alpha(x: 10, y: 50), 0)
        XCTAssertEqual(CGFilterLayer.makeScale(size: CGSize(width: 60, height: 60), maxPixels: 900, oversample: 1), 0.5)
    }

    func testHugeValuesDoNotTrap() throws {
        let bitmap = try render(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="a"><feGaussianBlur stdDeviation="1e30" /></filter>
            <filter id="b" filterUnits="userSpaceOnUse" x="-1e30" y="-1e30" width="1e31" height="1e31">
                <feGaussianBlur stdDeviation="3" />
            </filter>
            <rect x="10" y="10" width="20" height="20" fill="black" filter="url(#a)" />
            <rect x="50" y="50" width="20" height="20" fill="black" filter="url(#b)" />
        </svg>
        """#)

        XCTAssertGreaterThan(bitmap.alpha(x: 60, y: 60), 0.9)
    }

    func testEmptyClipDrawsNothing() throws {
        let bitmap = try render(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="blur"><feGaussianBlur stdDeviation="2" /></filter>
            <clipPath id="none"><rect x="0" y="0" width="0" height="0" /></clipPath>
            <g clip-path="url(#none)">
                <rect x="20" y="20" width="60" height="60" fill="black" filter="url(#blur)" />
            </g>
        </svg>
        """#)

        XCTAssertEqual(bitmap.alpha(x: 50, y: 50), 0)
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

    func render(_ xml: String, scale: CGFloat = 1, maxFilterLayerPixels: Int = CGRenderer.defaultMaxFilterLayerPixels) throws -> Bitmap {
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
            CGRenderer(context: ctx, maxFilterLayerPixels: maxFilterLayerPixels).perform(svg.commands)
        }
        return Bitmap(width: width, height: height, bytes: bytes)
    }
}
#endif
