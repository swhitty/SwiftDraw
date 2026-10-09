//
//  CGRenderer+FilterPrimitivesTests.swift
//  SwiftDraw
//
//  Created by Misoservices on 9/10/26.
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

// SD12: filter primitive trees rendered by CoreGraphics
final class CGRendererFilterPrimitivesTests: XCTestCase {

    // Inkscape's drop shadow: a half black copy of the shape, offset, under the shape
    func testInkscapeDropShadow() throws {
        let bitmap = try render(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter style="color-interpolation-filters:sRGB" id="shadow" x="-0.5" y="-0.5" width="2" height="2">
                <feFlood flood-opacity="0.498039" flood-color="rgb(0,0,0)" result="flood" />
                <feComposite in="flood" in2="SourceGraphic" operator="in" result="composite1" />
                <feGaussianBlur in="composite1" stdDeviation="0" result="blur" />
                <feOffset dx="10" dy="10" result="offset" />
                <feComposite in="SourceGraphic" in2="offset" operator="over" result="composite2" />
            </filter>
            <rect x="20" y="20" width="40" height="40" fill="red" filter="url(#shadow)" />
        </svg>
        """#)

        XCTAssertEqual(bitmap.rgba(x: 40, y: 40), [255, 0, 0, 255])
        // the shadow alone, below and right of the shape
        XCTAssertEqual(bitmap.rgba(x: 65, y: 65), [0, 0, 0, 127])
        XCTAssertEqual(bitmap.rgba(x: 25, y: 65), [0, 0, 0, 0])
        XCTAssertEqual(bitmap.rgba(x: 75, y: 75), [0, 0, 0, 0])
    }

    // Illustrator's AI_Shadow: blurred SourceAlpha offset under SourceGraphic, in linearRGB
    func testIllustratorShadow() throws {
        let bitmap = try render(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="AI_Shadow_1" filterUnits="objectBoundingBox" x="-0.5" y="-0.5" width="2" height="2">
                <feGaussianBlur in="SourceAlpha" stdDeviation="2" result="blur" />
                <feOffset dx="10" dy="10" in="blur" result="offsetBlurredAlpha" />
                <feMerge>
                    <feMergeNode in="offsetBlurredAlpha" />
                    <feMergeNode in="SourceGraphic" />
                </feMerge>
            </filter>
            <rect x="20" y="20" width="40" height="40" fill="#0000ff" filter="url(#AI_Shadow_1)" />
        </svg>
        """#)

        XCTAssertEqual(bitmap.rgba(x: 40, y: 40), [0, 0, 255, 255])
        // the shadow alone, more than three deviations inside its edges
        XCTAssertEqual(bitmap.rgba(x: 50, y: 62), [0, 0, 0, 255])
        // the blurred edge of the shadow
        XCTAssertEqual(bitmap.alpha(x: 70, y: 62), 0.45, accuracy: 0.15)
        XCTAssertEqual(bitmap.alpha(x: 80, y: 80), 0)
    }

    // Figma's drop shadow: hard alpha, offset, blur, the shape cut out, a 25% black colour matrix
    func testFigmaDropShadow() throws {
        let bitmap = try render(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="filter0_d" x="0" y="0" width="100" height="100" filterUnits="userSpaceOnUse" color-interpolation-filters="sRGB">
                <feFlood flood-opacity="0" result="BackgroundImageFix"/>
                <feColorMatrix in="SourceAlpha" type="matrix" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0" result="hardAlpha"/>
                <feOffset dy="10"/>
                <feGaussianBlur stdDeviation="1"/>
                <feComposite in2="hardAlpha" operator="out"/>
                <feColorMatrix type="matrix" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0.25 0"/>
                <feBlend mode="normal" in2="BackgroundImageFix" result="effect1_dropShadow"/>
                <feBlend mode="normal" in="SourceGraphic" in2="effect1_dropShadow" result="shape"/>
            </filter>
            <rect x="20" y="20" width="40" height="40" fill="#00ff00" filter="url(#filter0_d)" />
        </svg>
        """#)

        XCTAssertEqual(bitmap.rgba(x: 40, y: 40), [0, 255, 0, 255])
        XCTAssertEqual(bitmap.alpha(x: 40, y: 65), 0.25, accuracy: 0.02)
        XCTAssertEqual(bitmap.rgba(x: 40, y: 65).prefix(3), [0, 0, 0])
        XCTAssertEqual(bitmap.alpha(x: 40, y: 75), 0)
        XCTAssertEqual(bitmap.alpha(x: 10, y: 40), 0)
    }

    // Filter Effects 1 §9.4 example: the flood fills its subregion only, hiding the shape
    func testFloodSubregion() throws {
        let bitmap = try render(#"""
        <svg width="200" height="200" xmlns="http://www.w3.org/2000/svg">
            <filter id="flood" x="0" y="0" width="100%" height="100%" primitiveUnits="objectBoundingBox">
                <feFlood x="25%" y="25%" width="50%" height="50%" flood-color="green" flood-opacity="0.75"/>
            </filter>
            <circle fill="red" filter="url(#flood)" cx="100" cy="100" r="90"/>
        </svg>
        """#)

        assertPixel(bitmap.rgba(x: 100, y: 100), [0, 96, 0, 191])
        assertPixel(bitmap.rgba(x: 60, y: 140), [0, 96, 0, 191])
        // the circle itself is gone
        XCTAssertEqual(bitmap.alpha(x: 30, y: 100), 0)
        XCTAssertEqual(bitmap.alpha(x: 100, y: 30), 0)
    }

    // Filter Effects 1 §10: linearRGB by default, sRGB when asked
    func testColorInterpolationFilters() throws {
        func draw(_ space: String) throws -> Bitmap {
            try render(#"""
            <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
                <filter id="f" \#(space)>
                    <feFlood flood-color="black" result="black" />
                    <feMerge><feMergeNode in="black" /><feMergeNode in="SourceGraphic" /></feMerge>
                </filter>
                <rect x="20" y="20" width="60" height="60" fill="white" fill-opacity="0.5" filter="url(#f)" />
            </svg>
            """#)
        }

        let linear = try draw("")
        let srgb = try draw(#"color-interpolation-filters="sRGB""#)
        XCTAssertEqual(Double(linear.rgba(x: 50, y: 50)[0]), 188, accuracy: 2)
        XCTAssertEqual(Double(srgb.rgba(x: 50, y: 50)[0]), 128, accuracy: 2)
        XCTAssertEqual(linear.rgba(x: 50, y: 50)[3], 255)
    }

    func testColorMatrixSaturate() throws {
        let bitmap = try render(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="grey" color-interpolation-filters="sRGB"><feColorMatrix type="saturate" values="0" /></filter>
            <filter id="hue" color-interpolation-filters="sRGB"><feColorMatrix type="hueRotate" values="180" /></filter>
            <rect x="0" y="0" width="50" height="50" fill="red" filter="url(#grey)" />
            <rect x="50" y="0" width="50" height="50" fill="#808080" filter="url(#hue)" />
        </svg>
        """#)

        XCTAssertEqual(bitmap.rgba(x: 25, y: 25), [54, 54, 54, 255])
        // a hue rotation keeps greys
        assertPixel(bitmap.rgba(x: 75, y: 25), [128, 128, 128, 255])
    }

    func testBlendMultiplyOntoFlood() throws {
        let bitmap = try render(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="f" x="0" y="0" width="1" height="1" color-interpolation-filters="sRGB">
                <feFlood flood-color="#ffff00" result="yellow" />
                <feBlend mode="multiply" in="SourceGraphic" in2="yellow" />
            </filter>
            <rect x="0" y="0" width="100" height="100" fill="#ff00ff" filter="url(#f)" />
        </svg>
        """#)

        XCTAssertEqual(bitmap.rgba(x: 50, y: 50), [255, 0, 0, 255])
    }

    // the visible area grows by the offset: content clipped away can be moved into view
    func testOffsetBringsContentIntoTheClip() throws {
        let bitmap = try render(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="f" filterUnits="userSpaceOnUse" x="0" y="0" width="100" height="100">
                <feOffset dx="50" />
            </filter>
            <clipPath id="right"><rect x="50" y="0" width="50" height="100" /></clipPath>
            <g clip-path="url(#right)">
                <rect x="0" y="0" width="40" height="40" fill="black" filter="url(#f)" />
            </g>
        </svg>
        """#)

        XCTAssertEqual(bitmap.alpha(x: 70, y: 20), 1)
        XCTAssertEqual(bitmap.alpha(x: 20, y: 20), 0)
        XCTAssertEqual(bitmap.alpha(x: 95, y: 20), 0)
    }

    // offsets are in user space: scaled to device pixels, turned with the shape
    func testOffsetFollowsScaleAndRotation() throws {
        let scaled = try render(#"""
        <svg width="50" height="50" xmlns="http://www.w3.org/2000/svg">
            <filter id="f" filterUnits="userSpaceOnUse" x="0" y="0" width="50" height="50"><feOffset dx="10" /></filter>
            <rect x="0" y="0" width="10" height="10" fill="black" filter="url(#f)" />
        </svg>
        """#, scale: 2)
        XCTAssertEqual(scaled.alpha(x: 30, y: 10), 1)
        XCTAssertEqual(scaled.alpha(x: 10, y: 10), 0)

        let rotated = try render(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="f" filterUnits="userSpaceOnUse" x="-100" y="-100" width="300" height="300"><feOffset dx="30" /></filter>
            <rect x="40" y="10" width="20" height="20" fill="black" transform="rotate(90 50 50)" filter="url(#f)" />
        </svg>
        """#)
        // rotate(90) maps the rect to x 70...90, y 40...60 and +x to +y
        XCTAssertEqual(rotated.alpha(x: 80, y: 80), 1)
        XCTAssertEqual(rotated.alpha(x: 80, y: 50), 0)
    }

    // a disconnected branch, and primitives after it, follow the primary tree only
    func testOnlyPrimaryTreeIsDrawn() throws {
        let bitmap = try render(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="f" x="0" y="0" width="1" height="1" color-interpolation-filters="sRGB">
                <feFlood flood-color="red" />
                <feFlood flood-color="blue" result="blue" />
                <feComposite in="blue" in2="SourceAlpha" operator="in" />
            </filter>
            <rect x="10" y="10" width="80" height="80" fill="black" fill-opacity="0.5" filter="url(#f)" />
        </svg>
        """#)

        assertPixel(bitmap.rgba(x: 50, y: 50), [0, 0, 128, 128])
    }

    // the pixel budget is shared by the bitmaps of the tree: still drawn, at a reduced scale
    func testOverPixelCapStillFilters() throws {
        let bitmap = try render(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="f" filterUnits="userSpaceOnUse" x="0" y="0" width="100" height="100">
                <feOffset in="SourceAlpha" dx="20" dy="20" result="o" />
                <feMerge><feMergeNode in="o" /><feMergeNode in="SourceGraphic" /></feMerge>
            </filter>
            <rect x="10" y="10" width="40" height="40" fill="white" filter="url(#f)" />
        </svg>
        """#, maxFilterLayerPixels: 2_000)

        XCTAssertGreaterThan(bitmap.alpha(x: 30, y: 30), 0.9)
        XCTAssertGreaterThan(bitmap.rgba(x: 30, y: 30)[0], 200)
        XCTAssertGreaterThan(bitmap.alpha(x: 60, y: 60), 0.9)
        XCTAssertLessThan(bitmap.rgba(x: 60, y: 60)[0], 50)
        XCTAssertEqual(bitmap.alpha(x: 90, y: 90), 0)
    }

    func testHugeOffsetDoesNotTrap() throws {
        let bitmap = try render(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="f" primitiveUnits="objectBoundingBox"><feOffset dx="1e30" dy="-1e30" /></filter>
            <rect x="10" y="10" width="40" height="40" fill="black" filter="url(#f)" />
            <rect x="60" y="60" width="20" height="20" fill="black" />
        </svg>
        """#)

        XCTAssertEqual(bitmap.alpha(x: 30, y: 30), 0)
        XCTAssertEqual(bitmap.alpha(x: 70, y: 70), 1)
    }

    // the flood colour goes through the same colour matching as a fill
    func testFloodMatchesFillColor() throws {
        let bitmap = try render(#"""
        <svg width="100" height="50" xmlns="http://www.w3.org/2000/svg">
            <filter id="f" x="0" y="0" width="1" height="1"><feFlood flood-color="#3a7bd5" /></filter>
            <rect x="0" y="0" width="50" height="50" fill="black" filter="url(#f)" />
            <rect x="50" y="0" width="50" height="50" fill="#3a7bd5" />
        </svg>
        """#)

        XCTAssertEqual(bitmap.rgba(x: 25, y: 25), bitmap.rgba(x: 75, y: 25))
    }
}

private struct Bitmap {
    var width: Int
    var height: Int
    var bytes: [UInt8]

    // premultiplied; y is measured from the top, like SVG
    func rgba(x: Int, y: Int) -> [UInt8] {
        let i = (y * width + x) * 4
        return Array(bytes[i..<i + 4])
    }

    func alpha(x: Int, y: Int) -> Double {
        Double(rgba(x: x, y: y)[3]) / 255
    }
}

private extension CGRendererFilterPrimitivesTests {

    // colours other than primaries may move by a step through colour matching and rounding
    func assertPixel(_ pixel: [UInt8], _ expected: [UInt8], accuracy: Int = 2, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(pixel.count, expected.count, file: file, line: line)
        for (value, target) in zip(pixel, expected) {
            XCTAssertEqual(Int(value), Int(target), accuracy: accuracy, "\(pixel) is not \(expected)", file: file, line: line)
        }
    }

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
