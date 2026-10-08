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

/// Pixel checks of `<pattern>` through the CoreGraphics renderer (SVG 1.1 §13.3).
/// Every drawing is 16×16 and uses full-height stripes, so only the x position matters.
final class CGPatternTests: XCTestCase {

    func testPatternXOffsetsTiles() throws {
        // tiles at x = 4 + 8k, red in the first half of each tile
        let colors = try render(pattern: #"<pattern id="p" x="4" width="8" height="16" patternUnits="userSpaceOnUse">\#(stripe)</pattern>"#)
        XCTAssertEqual(colors(1), .white)
        XCTAssertEqual(colors(5), .red)
        XCTAssertEqual(colors(9), .white)
        XCTAssertEqual(colors(13), .red)
    }

    func testPatternTransformMovesTiles() throws {
        let colors = try render(pattern: #"<pattern id="p" width="8" height="16" patternUnits="userSpaceOnUse" patternTransform="translate(2, 0)">\#(stripe)</pattern>"#)
        XCTAssertEqual(colors(1), .white)
        XCTAssertEqual(colors(3), .red)
        XCTAssertEqual(colors(7), .white)
        XCTAssertEqual(colors(11), .red)
    }

    func testPatternHrefInheritsAttributesAndContent() throws {
        let colors = try render(pattern: #"""
            <pattern id="base" x="4" width="8" height="16" patternUnits="userSpaceOnUse">\#(stripe)</pattern>
            <pattern id="p" xlink:href="#base" patternTransform="translate(-2, 0)" />
            """#)
        XCTAssertEqual(colors(1), .white)
        XCTAssertEqual(colors(3), .red)
        XCTAssertEqual(colors(7), .white)
        XCTAssertEqual(colors(11), .red)
    }

    func testPatternUnitsDefaultToObjectBoundingBox() throws {
        // width 0.5 of the 16 wide bounding box: tiles of 8
        let colors = try render(pattern: #"<pattern id="p" width="0.5" height="1">\#(stripe)</pattern>"#)
        XCTAssertEqual(colors(1), .red)
        XCTAssertEqual(colors(5), .white)
        XCTAssertEqual(colors(9), .red)
        XCTAssertEqual(colors(13), .white)
    }

    func testPatternViewBoxScalesContent() throws {
        // viewBox 0 0 8 16 into a 16×16 tile: meet scale 1, content centred at x = 4
        let colors = try render(pattern: #"<pattern id="p" width="16" height="16" viewBox="0 0 8 16" patternUnits="userSpaceOnUse">\#(stripe)</pattern>"#)
        XCTAssertEqual(colors(1), .white)
        XCTAssertEqual(colors(5), .red)
        XCTAssertEqual(colors(9), .white)
    }

    func testPatternWithoutSizePaintsNothingAndKeepsDocument() throws {
        let colors = try render(pattern: #"<pattern id="p">\#(stripe)</pattern>"#)
        XCTAssertEqual(colors(1), .white)
        XCTAssertEqual(colors(5), .white)
    }
}

private extension CGPatternTests {

    enum Pixel: Equatable {
        case red
        case white
        case other
    }

    var stripe: String { #"<rect width="4" height="16" fill="red" />"# }

    func render(pattern: String) throws -> (Int) -> Pixel {
        let xml = """
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="16" height="16">
            <defs>\(pattern)</defs>
            <rect width="16" height="16" fill="white" />
            <rect width="16" height="16" fill="url(#p)" />
        </svg>
        """
        let svg = try XCTUnwrap(SVG(xml: xml))
        let image = svg.rasterize(with: CGSize(width: 16, height: 16), scale: 1)
        let canvas = NSBitmapImageRep(pixelsWide: 16, pixelsHigh: 16)
        canvas.lockFocus()
        image.draw(in: NSRect(x: 0, y: 0, width: 16, height: 16))
        canvas.unlockFocus()

        return { x in
            guard let color = canvas.colorAt(x: x, y: 8)?.usingColorSpace(.deviceRGB) else { return .other }
            let (r, g, b) = (color.redComponent, color.greenComponent, color.blueComponent)
            if r > 0.9, g < 0.1, b < 0.1 { return .red }
            if r > 0.9, g > 0.9, b > 0.9 { return .white }
            return .other
        }
    }
}

#endif
