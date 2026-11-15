//
//  CGRenderer.GradientSpreadTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 15/11/26.
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
import SwiftDrawDOM
import CoreGraphics
import Foundation
import Testing

/// spreadMethod drawn by CoreGraphics, which only pads natively.
/// Ported from SD6 in PR #142 by Michel Donais.
struct CGRendererGradientSpreadTests {

    // red→blue every 10 units: pad leaves x ≥ 10 blue, repeat restarts red at x = 10 and 20,
    // reflect mirrors x = 9 at x = 11
    @Test(arguments: [
        ("repeat", 1, true),
        ("repeat", 21, true),
        ("pad", 21, false),
        ("reflect", 11, false),
        ("reflect", 19, true)
    ])
    func linearSpread(spread: String, x: Int, isRed: Bool) throws {
        let redness = try renderRedness(spread: spread, x: x)
        if isRed {
            #expect(redness > 0.5)
        } else {
            #expect(redness < -0.5)
        }
    }

    @Test
    func objectBoundingBoxReflectStroke() throws {
        // x2 = 0.25 of a 40 wide box: reflect is red again at x = 20, pad stays blue
        #expect(try renderRedness(spread: "reflect", x: 20, units: "objectBoundingBox", x2: "0.25", stroke: true) > 0.5)
        #expect(try renderRedness(spread: "pad", x: 20, units: "objectBoundingBox", x2: "0.25", stroke: true) < -0.5)
    }

    func renderRedness(spread: String, x: Int,
                       units: String = "userSpaceOnUse", x2: String = "10",
                       stroke: Bool = false) throws -> CGFloat {
        let shape = stroke
            ? #"<rect y="2" width="40" height="0.5" fill="none" stroke="url(#g)" stroke-width="8"/>"#
            : #"<rect width="40" height="4" fill="url(#g)"/>"#
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="40" height="4">
          <defs><linearGradient id="g" gradientUnits="\(units)" x1="0" x2="\(x2)" spreadMethod="\(spread)">
            <stop offset="0" stop-color="red"/><stop offset="1" stop-color="blue"/>
          </linearGradient></defs>
          \(shape)
        </svg>
        """)
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let ctx = try #require(CGContext(data: nil, width: 40, height: 4, bitsPerComponent: 8, bytesPerRow: 160,
                                         space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let generator = LayerTree.CommandGenerator(provider: CGProvider(), size: LayerTree.Size(40, 4), options: .default)
        CGRenderer(context: ctx).perform(generator.renderCommands(for: layer, colorConverter: .default))
        let data = try #require(ctx.data).assumingMemoryBound(to: UInt8.self)
        let i = (2 * 40 + x) * 4
        return (CGFloat(data[i]) - CGFloat(data[i + 2])) / 255
    }
}
#endif
