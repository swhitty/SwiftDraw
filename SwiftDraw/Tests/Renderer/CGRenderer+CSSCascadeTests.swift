//
//  CGRenderer+CSSCascadeTests.swift
//  SwiftDraw
//
//  Added by Misoservices for the Backdrop fork of SwiftDraw (altered source version).
//  Copyright 2026 Misoservices
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

final class CGRendererCSSCascadeTests: XCTestCase {

    // a stylesheet transform and a descendant selector reach the pixels
    func testStyleSheetTransformAndSelectorDrawPixels() throws {
        let bitmap = try render(#"""
        <svg width="40" height="20" xmlns="http://www.w3.org/2000/svg">
            <style>
                .moved { transform: translate(20px, 0) }
                g.icon > rect:first-child { fill: #ff0000 }
                rect { fill: #0000ff }
            </style>
            <g class="icon"><rect class="moved" width="10" height="10"/><rect y="10" width="10" height="10"/></g>
        </svg>
        """#)

        // the red square moved from x 0…10 to x 20…30
        XCTAssertEqual(bitmap.rgba(x: 5, y: 5), [0, 0, 0, 0])
        XCTAssertEqual(bitmap.rgba(x: 25, y: 5), [255, 0, 0, 255])
        // the second rect keeps the type rule
        XCTAssertEqual(bitmap.rgba(x: 5, y: 15), [0, 0, 255, 255])
    }
}

private struct Bitmap {
    var width: Int
    var bytes: [UInt8]

    // y is measured from the top, like SVG
    func rgba(x: Int, y: Int) -> [UInt8] {
        let i = (y * width + x) * 4
        return Array(bytes[i..<i + 4])
    }
}

private extension CGRendererCSSCascadeTests {

    func render(_ xml: String) throws -> Bitmap {
        let svg = try XCTUnwrap(SVG(xml: xml))
        let width = Int(svg.size.width)
        let height = Int(svg.size.height)
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        bytes.withUnsafeMutableBytes { buffer in
            let ctx = CGContext(data: buffer.baseAddress, width: width, height: height,
                                bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            ctx.translateBy(x: 0, y: CGFloat(height))
            ctx.scaleBy(x: 1, y: -1)
            CGRenderer(context: ctx).perform(svg.commands)
        }
        return Bitmap(width: width, bytes: bytes)
    }
}
#endif
