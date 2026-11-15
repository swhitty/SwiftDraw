//
//  CGPatternTests.swift
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

/// Pixel checks for the pattern-fill state leak and the paint fallback (SVG 1.1 §11.2) through CoreGraphics.
final class CGPaintFallbackTests: XCTestCase {

    // a solid colour A, a pattern, then colour A again: the last shape must be solid A, not the pattern
    func testSolidColourAfterPatternIsNotPatterned() throws {
        let pixels = try render(defs: #"<pattern id="p" width="4" height="4" patternUnits="userSpaceOnUse"><rect width="4" height="4" fill="blue" /></pattern>"#,
                                body: #"""
            <rect width="8" height="16" fill="red" />
            <rect x="8" width="4" height="16" fill="url(#p)" />
            <rect x="12" width="4" height="16" fill="red" />
        """#)
        XCTAssertEqual(pixels(2), .red)
        XCTAssertEqual(pixels(10), .blue)
        XCTAssertEqual(pixels(14), .red)
    }

    func testMissingServerPaintsFallbackColour() throws {
        let pixels = try render(defs: "", body: #"<rect width="16" height="16" fill="url(#missing) #ff0000" />"#)
        XCTAssertEqual(pixels(8), .red)
    }

    func testResolvingServerWinsOverFallback() throws {
        let pixels = try render(defs: #"<linearGradient id="g"><stop offset="0" stop-color="blue" /><stop offset="1" stop-color="blue" /></linearGradient>"#,
                                body: #"<rect width="16" height="16" fill="url(#g) #ff0000" />"#)
        XCTAssertEqual(pixels(8), .blue)
    }

    func testNoneFallbackPaintsNothing() throws {
        let pixels = try render(defs: "", body: #"<rect width="16" height="16" fill="url(#missing) none" />"#)
        XCTAssertEqual(pixels(8), .white)
    }
}

private extension CGPaintFallbackTests {

    enum Pixel: Equatable { case red, blue, white, other }

    /// Draws on white and samples the middle row.
    func render(defs: String, body: String) throws -> (Int) -> Pixel {
        let xml = """
        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16">
            <defs>\(defs)</defs>
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
            if r < 0.1, g < 0.1, b > 0.9 { return .blue }
            if r > 0.9, g > 0.9, b > 0.9 { return .white }
            return .other
        }
    }
}

#endif
