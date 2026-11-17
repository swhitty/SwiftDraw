//
//  CGRenderer+NestedPatternTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 17/11/26.
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

#if canImport(CoreGraphics)
@testable import SwiftDraw
import CoreGraphics
import Foundation
import Testing

/// A pattern drawn inside another pattern's tile. The inner tile is 3×4 and its green rect, from
/// x = 2 to 4, overflows the tile, so only x = 2 to 3 of every tile is green. At most scales the
/// inner tile is a fractional number of device pixels.
struct CGRendererNestedPatternTests {

    static let svg = #"""
    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24">
        <pattern id="inner" patternUnits="userSpaceOnUse" width="3" height="4">
            <rect x="2" width="2" height="4" fill="lime" />
        </pattern>
        <pattern id="outer" patternUnits="userSpaceOnUse" width="12" height="12">
            <rect width="12" height="12" fill="url(#inner)" />
        </pattern>
        <rect width="24" height="24" fill="white" />
        <rect width="24" height="24" fill="url(#outer)" />
    </svg>
    """#

    @Test(arguments: [1, 1.5, 2, 2.25, 3] as [CGFloat])
    func innerTileIsClipped(scale: CGFloat) throws {
        let bitmap = try render(Self.svg, scale: scale)

        // the middle of each 3 wide column: white, white, green
        for tile in 0..<8 {
            let x = CGFloat(tile * 3)
            #expect(bitmap.isWhite(x: x + 0.5, y: 6, scale: scale), "x = \(x + 0.5) at \(scale)x")
            #expect(bitmap.isWhite(x: x + 1.5, y: 6, scale: scale), "x = \(x + 1.5) at \(scale)x")
            #expect(bitmap.isGreen(x: x + 2.5, y: 6, scale: scale), "x = \(x + 2.5) at \(scale)x")
        }
    }

    @Test(arguments: [1, 1.5, 2, 2.25, 3] as [CGFloat])
    func innerTileCoversAThird(scale: CGFloat) throws {
        let bitmap = try render(Self.svg, scale: scale)

        let row = Int(6 * scale)
        let green = (0..<bitmap.width).reduce(0.0) { $0 + bitmap.greenness(x: $1, y: row) }
        #expect(abs(green / Double(bitmap.width) - 1.0 / 3) < 0.03, "\(green / Double(bitmap.width)) at \(scale)x")
    }
}

private struct Bitmap {
    var width: Int
    var height: Int
    var bytes: [UInt8]

    // y is measured from the top, like SVG
    func rgba(x: Int, y: Int) -> [UInt8] {
        let i = (y * width + x) * 4
        return Array(bytes[i..<i + 4])
    }

    /// 1 for lime, 0 for white
    func greenness(x: Int, y: Int) -> Double {
        let pixel = rgba(x: x, y: y)
        return 1 - Double(pixel[0]) / 255
    }

    func isWhite(x: CGFloat, y: CGFloat, scale: CGFloat) -> Bool {
        greenness(x: Int(x * scale), y: Int(y * scale)) < 0.1
    }

    func isGreen(x: CGFloat, y: CGFloat, scale: CGFloat) -> Bool {
        greenness(x: Int(x * scale), y: Int(y * scale)) > 0.9
    }
}

private extension CGRendererNestedPatternTests {

    func render(_ xml: String, scale: CGFloat) throws -> Bitmap {
        let svg = try #require(SVG(xml: xml))
        let width = Int((svg.size.width * scale).rounded(.up))
        let height = Int((svg.size.height * scale).rounded(.up))
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        bytes.withUnsafeMutableBytes { buffer in
            let ctx = CGContext(data: buffer.baseAddress, width: width, height: height,
                                bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            let base = ctx.ctm
            // SVG coordinates are y-down
            ctx.translateBy(x: 0, y: CGFloat(height))
            ctx.scaleBy(x: scale, y: -scale)
            CGRenderer(context: ctx, baseCTM: base).perform(svg.commands)
        }
        return Bitmap(width: width, height: height, bytes: bytes)
    }
}
#endif
