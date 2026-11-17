//
//  CGContext+BitmapTests.swift
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

struct CGContextBitmapTests {

    @Test(arguments: [8, 32] as [Int])
    func bitmapContextIsBitmap(bitsPerPixel: Int) throws {
        let space = bitsPerPixel == 8 ? CGColorSpaceCreateDeviceGray() : CGColorSpaceCreateDeviceRGB()
        let info = bitsPerPixel == 8 ? CGImageAlphaInfo.none : .premultipliedLast
        let ctx = try #require(
            CGContext(
                data: nil,
                width: 4,
                height: 4,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: space,
                bitmapInfo: info.rawValue
            )
        )
        #expect(ctx.isBitmapContext)
    }

    @Test
    func pdfContextIsNotBitmap() throws {
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 10, height: 10)
        let consumer = try #require(CGDataConsumer(data: data as CFMutableData))
        let pdf = try #require(CGContext(consumer: consumer, mediaBox: &mediaBox, nil))
        pdf.beginPDFPage(nil)
        #expect(!pdf.isBitmapContext)
        pdf.endPDFPage()
        pdf.closePDF()
    }

    @Test
    func layerContextIsNotBitmap() throws {
        let bitmap = try #require(
            CGContext(
                data: nil,
                width: 4,
                height: 4,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: 0
            )
        )
        let layer = try #require(CGLayer(bitmap, size: CGSize(width: 4, height: 4), auxiliaryInfo: nil))
        let ctx = try #require(layer.context)
        #expect(!ctx.isBitmapContext)
    }
}
#endif
