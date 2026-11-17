//
//  CGImage+Mask.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 31/3/19.
//  Copyright 2020 Simon Whitty
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
import CoreGraphics
import Foundation

func CGColorSpaceCreateExtendedGray() -> CGColorSpace {
    return CGColorSpace.extendedGraySpace
}

extension CGColorSpace {
    // SVG and CSS colours are sRGB; color(display-p3 …) stays Display P3. DeviceRGB is never used,
    // so the destination context alone decides the output space.
    static let sRGBSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    static let displayP3Space = CGColorSpace(name: CGColorSpace.displayP3)!
    // Extended gray uses the sRGB transfer function, so its greys match sRGB greys pixel for pixel.
    static let extendedGraySpace = CGColorSpace(name: CGColorSpace.extendedGray)!
}

extension CGImage {

    static func makeMask(size: CGSize, draw: (CGContext) -> ()) -> CGImage {

        let width = Int(size.width)
        let height = Int(size.height)

        var data = Data(repeating: 0xff, count: width * height)
        data.withUnsafeMutableBytes {
            let ctx = CGContext(
                data: $0.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: 0
            )!
            draw(ctx)
        }

        return CGImage(
            maskWidth: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: width,
            provider: CGDataProvider(data: data as CFData)!,
            decode: nil,
            shouldInterpolate: true
        )!
    }
}

extension CGContext {

    // A DeviceGray bitmap covering deviceRect, filled black, with its CTM mapping device space onto it.
    // Rendered at up to oversample pixels per device pixel, scaled down to stay within maxPixels.
    static func makeLuminanceMask(deviceRect: CGRect, oversample: CGFloat, maxPixels: Int) -> CGContext? {
        guard !deviceRect.isNull, !deviceRect.isInfinite,
            deviceRect.minX.isFinite, deviceRect.minY.isFinite,
            deviceRect.width >= 1, deviceRect.height >= 1,
            deviceRect.width.isFinite, deviceRect.height.isFinite
        else { return nil }

        let pixels = deviceRect.width * deviceRect.height
        let scale = min(oversample, (CGFloat(maxPixels) / pixels).squareRoot())
        let width = max(1, Int((deviceRect.width * scale).rounded(.up)))
        let height = max(1, Int((deviceRect.height * scale).rounded(.up)))
        guard
            let ctx = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            )
        else { return nil }

        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: -deviceRect.minX, y: -deviceRect.minY)
        return ctx
    }
}

#endif
