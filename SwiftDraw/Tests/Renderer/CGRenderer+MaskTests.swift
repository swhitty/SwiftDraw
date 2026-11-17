//
//  CGRenderer+MaskTests.swift
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
import CoreGraphics
import Foundation
import Testing

/// Luminance masks rendered through CoreGraphics. Each mask is 100x100 and masks an opaque rect;
/// the rendered alpha is the mask value.
struct CGRendererMaskTests {

    @Test
    func opacityAfterEarlierMaskContent() throws {
        let bitmap = try render(
            mask: #"""
                    <rect width="100" height="100" fill="white" />
                    <rect width="50" height="100" fill="black" opacity="0.5" />
                """#
        )

        #expect(bitmap.alpha(x: 25, y: 50).isClose(to: 0.5))
        #expect(bitmap.alpha(x: 75, y: 50).isClose(to: 1))
    }

    @Test
    func alphaMaskUsesContentAlpha() throws {
        let bitmap = try render(
            #"""
            <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
                <mask id="m" style="mask-type:alpha">
                    <rect width="50" height="100" fill="black" fill-opacity="0.5" />
                    <rect x="50" width="50" height="100" fill="black" />
                </mask>
                <rect width="100" height="100" fill="green" mask="url(#m)" />
            </svg>
            """#
        )

        #expect(bitmap.alpha(x: 25, y: 50).isClose(to: 0.5))
        #expect(bitmap.alpha(x: 75, y: 50).isClose(to: 1))
    }

    @Test
    func groupOpacityFlattensOverlap() throws {
        let bitmap = try render(
            mask: #"""
                    <rect width="100" height="100" fill="white" />
                    <g opacity="0.5">
                        <rect width="60" height="50" fill="black" />
                        <rect x="40" width="60" height="50" fill="black" />
                    </g>
                """#
        )

        #expect(bitmap.alpha(x: 20, y: 25).isClose(to: 0.5))
        #expect(bitmap.alpha(x: 50, y: 25).isClose(to: 0.5))
        #expect(bitmap.alpha(x: 80, y: 25).isClose(to: 0.5))
        #expect(bitmap.alpha(x: 50, y: 75).isClose(to: 1))
    }

    @Test
    func translucentFillsComposite() throws {
        let bitmap = try render(
            mask: #"""
                    <rect width="100" height="100" fill="black" />
                    <rect width="70" height="100" fill="white" fill-opacity="0.6" />
                    <rect x="30" width="70" height="100" fill="white" fill-opacity="0.6" />
                """#
        )

        #expect(bitmap.alpha(x: 15, y: 50).isClose(to: 0.6))
        #expect(bitmap.alpha(x: 50, y: 50).isClose(to: 0.84))
        #expect(bitmap.alpha(x: 85, y: 50).isClose(to: 0.6))
    }

    @Test
    func translucentStrokeOverWhite() throws {
        let bitmap = try render(
            mask: #"""
                    <rect width="100" height="100" fill="white" />
                    <line x1="50" y1="0" x2="50" y2="100" stroke="black" stroke-width="20" stroke-opacity="0.7" />
                """#
        )

        #expect(bitmap.alpha(x: 50, y: 50).isClose(to: 0.3))
        #expect(bitmap.alpha(x: 20, y: 50).isClose(to: 1))
    }

    @Test(arguments: [
        ("white", 1.0),
        ("#808080", 0.502),
        ("red", 0.2126),
        ("lime", 0.7152),
        ("blue", 0.0722),
        ("black", 0.0),
    ])
    func luminanceOfFill(color: String, luminance: Double) throws {
        let bitmap = try render(mask: #"<rect width="100" height="100" fill="\#(color)" />"#)

        #expect(bitmap.alpha(x: 50, y: 50).isClose(to: luminance))
    }

    @Test
    func emptyMaskHidesEverything() throws {
        let bitmap = try render(mask: "")

        #expect(bitmap.alpha(x: 50, y: 50) == 0)
    }

    @Test
    func maskedContentsAreMaskedAsGroup() throws {
        let bitmap = try render(
            #"""
            <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
                <mask id="m"><rect width="100" height="100" fill="#808080" /></mask>
                <g mask="url(#m)">
                    <rect width="60" height="100" fill="black" />
                    <rect x="40" width="60" height="100" fill="black" />
                </g>
            </svg>
            """#
        )

        // the overlap is not masked twice
        #expect(bitmap.alpha(x: 50, y: 50).isClose(to: 0.502))
        #expect(bitmap.alpha(x: 20, y: 50).isClose(to: 0.502))
    }

    @Test
    func maskFollowsTransformAtDeviceScale() throws {
        let bitmap = try render(
            #"""
            <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
                <mask id="m">
                    <rect width="100" height="100" fill="white" />
                    <rect x="50" width="50" height="100" fill="black" opacity="0.5" />
                </mask>
                <rect width="100" height="100" fill="black" mask="url(#m)" transform="rotate(90 50 50)" />
            </svg>
            """#,
            scale: 2
        )

        // the element's right half is rotated to the bottom
        #expect(bitmap.alpha(x: 100, y: 40).isClose(to: 1))
        #expect(bitmap.alpha(x: 100, y: 160).isClose(to: 0.5))
    }

    @Test
    func nestedMaskInMaskContent() throws {
        let bitmap = try render(
            #"""
            <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
                <mask id="left"><rect width="50" height="100" fill="white" /></mask>
                <mask id="m">
                    <rect width="100" height="100" fill="white" opacity="0.5" />
                    <rect width="100" height="100" fill="white" mask="url(#left)" />
                </mask>
                <rect width="100" height="100" fill="black" mask="url(#m)" />
            </svg>
            """#
        )

        #expect(bitmap.alpha(x: 25, y: 50).isClose(to: 1))
        #expect(bitmap.alpha(x: 75, y: 50).isClose(to: 0.5))
    }

    @Test
    func patternInMaskContent() throws {
        let bitmap = try render(
            mask: #"""
                    <pattern id="p" width="20" height="20" patternUnits="userSpaceOnUse">
                        <rect width="10" height="20" fill="white" />
                    </pattern>
                    <rect width="100" height="100" fill="url(#p)" />
                """#,
            scale: 2
        )

        #expect(bitmap.alpha(x: 10, y: 100).isClose(to: 1))
        #expect(bitmap.alpha(x: 30, y: 100).isClose(to: 0))
        #expect(bitmap.alpha(x: 50, y: 100).isClose(to: 1))
    }

    @Test
    func maskInVectorContext() throws {
        let bitmap = try renderPDF(
            mask: #"""
                    <rect width="100" height="100" fill="white" />
                    <rect width="50" height="100" fill="black" opacity="0.5" />
                """#
        )

        #expect(bitmap.alpha(x: 25, y: 50).isClose(to: 0.5))
        #expect(bitmap.alpha(x: 75, y: 50).isClose(to: 1))
    }
}

private extension Double {
    func isClose(to other: Double) -> Bool {
        abs(self - other) <= 0.02
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

private extension CGRendererMaskTests {

    func makeSVG(mask: String) -> String {
        """
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <mask id="m">\(mask)</mask>
            <rect width="100" height="100" fill="black" mask="url(#m)" />
        </svg>
        """
    }

    func render(mask: String, scale: CGFloat = 1) throws -> Bitmap {
        try render(makeSVG(mask: mask), scale: scale)
    }

    func render(_ xml: String, scale: CGFloat = 1) throws -> Bitmap {
        let svg = try #require(SVG(xml: xml))
        return draw(width: Int(svg.size.width * scale), height: Int(svg.size.height * scale)) { ctx in
            // SVG coordinates are y-down
            ctx.translateBy(x: 0, y: svg.size.height * scale)
            ctx.scaleBy(x: scale, y: -scale)
            CGRenderer(context: ctx).perform(svg.commands)
        }
    }

    // draws into a PDF, then rasterises the page
    func renderPDF(mask: String) throws -> Bitmap {
        let svg = try #require(SVG(xml: makeSVG(mask: mask)))
        let data = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: svg.size)
        let consumer = try #require(CGDataConsumer(data: data as CFMutableData))
        let pdf = try #require(CGContext(consumer: consumer, mediaBox: &mediaBox, nil))
        pdf.beginPDFPage(nil)
        pdf.translateBy(x: 0, y: svg.size.height)
        pdf.scaleBy(x: 1, y: -1)
        CGRenderer(context: pdf).perform(svg.commands)
        pdf.endPDFPage()
        pdf.closePDF()

        let provider = try #require(CGDataProvider(data: data as CFData))
        let page = try #require(CGPDFDocument(provider)?.page(at: 1))
        return draw(width: Int(svg.size.width), height: Int(svg.size.height)) { ctx in
            ctx.drawPDFPage(page)
        }
    }

    func draw(width: Int, height: Int, _ body: (CGContext) -> Void) -> Bitmap {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        bytes.withUnsafeMutableBytes { buffer in
            let ctx = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )!
            body(ctx)
        }
        return Bitmap(width: width, height: height, bytes: bytes)
    }
}
#endif
