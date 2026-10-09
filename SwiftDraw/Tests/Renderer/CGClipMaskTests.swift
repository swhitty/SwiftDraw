//
//  CGClipMaskTests.swift
//  SwiftDraw
//
//  Created by Misoservices on 8/10/26.
//  Copyright 2026 Simon Whitty
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


@testable import SwiftDraw

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
import XCTest

/// Pixel checks of clip paths and masks through the CoreGraphics renderer (SVG 1.1 §14.3.5, §14.4).
/// Every drawing is 16×16 on white, with a red element whose clip or mask leaves only some columns red.
final class CGClipMaskTests: XCTestCase {

    func testClipPathUnitsObjectBoundingBox() throws {
        // bbox (0,0,16,16): clip to x in 8...16
        let colors = try render(#"""
            <clipPath id="c" clipPathUnits="objectBoundingBox"><rect x="0.5" width="0.5" height="1" /></clipPath>
            <rect width="16" height="16" fill="red" clip-path="url(#c)" />
            """#)
        XCTAssertEqual(colors(4), .white)
        XCTAssertEqual(colors(12), .red)
    }

    func testClipRuleFromClipPathContents() throws {
        // outer 0...16, hole 4...12; evenodd on the path cuts the hole
        let colors = try render(#"""
            <clipPath id="c"><path clip-rule="evenodd" d="M0 0h16v16h-16z M4 0h8v16h-8z" /></clipPath>
            <rect width="16" height="16" fill="red" clip-path="url(#c)" />
            """#)
        XCTAssertEqual(colors(2), .red)
        XCTAssertEqual(colors(8), .white)
        XCTAssertEqual(colors(14), .red)
    }

    func testMixedClipRulesUnion() throws {
        let colors = try render(#"""
            <clipPath id="c">
              <rect width="4" height="16" clip-rule="evenodd" />
              <rect x="12" width="4" height="16" />
            </clipPath>
            <rect width="16" height="16" fill="red" clip-path="url(#c)" />
            """#)
        XCTAssertEqual(colors(2), .red)
        XCTAssertEqual(colors(8), .white)
        XCTAssertEqual(colors(14), .red)
    }

    func testUseInsideClipPath() throws {
        let colors = try render(#"""
            <defs><rect id="r" width="4" height="16" /></defs>
            <clipPath id="c"><use xlink:href="#r" x="8" /></clipPath>
            <rect width="16" height="16" fill="red" clip-path="url(#c)" />
            """#)
        XCTAssertEqual(colors(4), .white)
        XCTAssertEqual(colors(10), .red)
        XCTAssertEqual(colors(14), .white)
    }

    func testClipPathOnClipPath() throws {
        let colors = try render(#"""
            <clipPath id="inner"><rect x="4" width="12" height="16" /></clipPath>
            <clipPath id="c" clip-path="url(#inner)"><rect width="10" height="16" /></clipPath>
            <rect width="16" height="16" fill="red" clip-path="url(#c)" />
            """#)
        XCTAssertEqual(colors(2), .white)
        XCTAssertEqual(colors(6), .red)
        XCTAssertEqual(colors(12), .white)
    }

    func testMaskContentUnitsObjectBoundingBox() throws {
        let colors = try render(#"""
            <mask id="m" maskContentUnits="objectBoundingBox"><rect width="0.5" height="1" fill="white" /></mask>
            <rect x="8" width="8" height="16" fill="red" mask="url(#m)" />
            """#)
        XCTAssertEqual(colors(4), .white)
        XCTAssertEqual(colors(10), .red)
        XCTAssertEqual(colors(14), .white)
    }

    func testMaskRegionClipsMask() throws {
        let colors = try render(#"""
            <mask id="m" x="0" y="0" width="0.25" height="1"><rect width="16" height="16" fill="white" /></mask>
            <rect width="16" height="16" fill="red" mask="url(#m)" />
            """#)
        XCTAssertEqual(colors(2), .red)
        XCTAssertEqual(colors(8), .white)
    }

    func testMaskZeroRegionHidesElement() throws {
        let colors = try render(#"""
            <mask id="m" width="0"><rect width="16" height="16" fill="white" /></mask>
            <rect width="16" height="16" fill="red" mask="url(#m)" />
            """#)
        XCTAssertEqual(colors(2), .white)
        XCTAssertEqual(colors(8), .white)
        XCTAssertEqual(colors(14), .white)
    }

    func testFilterWithMaskTypeClip() throws {
        // mixed clip-rules make the clip a mask; the flood fills the filter region, so it only shows
        // where the mask lets it through, and it is blue: with the filter ignored these pixels stay red
        let colors = try render(#"""
            <filter id="f" x="0" y="0" width="1" height="1"><feFlood flood-color="blue" /></filter>
            <clipPath id="c">
              <rect width="6" height="16" clip-rule="evenodd" />
              <rect x="10" width="6" height="16" />
            </clipPath>
            <rect width="16" height="16" fill="red" filter="url(#f)" clip-path="url(#c)" />
            """#)
        XCTAssertEqual(colors(2), .other)
        XCTAssertNotEqual(colors(2), .red)
        XCTAssertEqual(colors(8), .white)
        XCTAssertNotEqual(colors(13), .red)
        XCTAssertEqual(colors(13), .other)
    }

    func testClipPathWithoutShapesClipsEverything() throws {
        let colors = try render(#"""
            <clipPath id="c"><rect width="0" height="0" /></clipPath>
            <clipPath id="empty" />
            <rect width="16" height="16" fill="red" clip-path="url(#c)" />
            <rect width="16" height="16" fill="red" clip-path="url(#empty)" />
            """#)
        XCTAssertEqual(colors(2), .white)
        XCTAssertEqual(colors(8), .white)
        XCTAssertEqual(colors(13), .white)
    }

    enum Pixel: Equatable {
        case red
        case white
        case other
    }

    func render(_ body: String) throws -> (Int) -> Pixel {
        let xml = """
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="16" height="16">
            <rect width="16" height="16" fill="white" />
            \(body)
        </svg>
        """
        let svg = try XCTUnwrap(SVG(xml: xml))
        let image = svg.rasterize(with: CGSize(width: 16, height: 16), scale: 1)
        let canvas = NSBitmapImageRep(pixelsWide: 16, pixelsHigh: 16)
        canvas.lockFocus()
        image.draw(in: NSRect(x: 0, y: 0, width: 16, height: 16))
        canvas.unlockFocus()

        return { i in
            guard let color = canvas.colorAt(x: i, y: 8)?.usingColorSpace(.deviceRGB) else { return .other }
            let (r, g, b) = (color.redComponent, color.greenComponent, color.blueComponent)
            if r > 0.9, g < 0.1, b < 0.1 { return .red }
            if r > 0.9, g > 0.9, b > 0.9 { return .white }
            return .other
        }
    }
}

#endif
