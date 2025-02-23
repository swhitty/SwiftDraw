//
//  NSImage+SVG.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 24/5/17.
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

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
import CoreGraphics

public extension NSImage {

    convenience init?(svgNamed name: String, in bundle: Bundle = .main, options: SVG.Options = .default) {
        guard let image = SVG(named: name, in: bundle, options: options) else { return nil }
        self.init(image)
    }

    @objc(initWithSVGData:)
    convenience init?(_ data: Data) {
        guard let image = SVG(data: data) else { return nil }
        self.init(image)
    }

    @objc(initWithContentsOfSVGFile:)
    convenience init?(contentsOfSVGFile path: String) {
        guard let image = SVG(fileURL: URL(fileURLWithPath: path)) else { return nil }
        self.init(image)
    }

    @objc(svgNamed:)
    static func _svgNamed(_ name: String) -> NSImage? {
        NSImage(svgNamed: name, in: .main)
    }

    @objc(svgNamed:inBundle:)
    static func _svgNamed(_ name: String, in bundle: Bundle) -> NSImage? {
        NSImage(svgNamed: name, in: bundle)
    }

    convenience init(_ image: SVG) {
        self.init(size: image.size, flipped: true) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: rect.size.width, height: rect.size.height))
            return true
        }
    }
}

public extension SVG {

    func rasterize() -> NSImage {
        return rasterize(with: size)
    }

    func rasterize(with size: CGSize? = nil, scale: CGFloat = 0) -> NSImage {
        let scale = scale == 0 ? (NSScreen.main?.backingScaleFactor ?? 1.0) : scale
        let size = size ?? self.size
        let imageSize = NSSize(width: size.width * scale, height: size.height * scale)

        let image = NSImage(size: imageSize, flipped: true) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.draw(self, in: CGRect(x: 0, y: 0, width: rect.size.width, height: rect.size.height))
            return true
        }


        return image
    }

    func pngData(scale: CGFloat = 0) throws -> Data {
        let scale = scale == 0 ? SVG.defaultScale : scale
        let (bounds, pixelsWide, pixelsHigh) = Self.makeBounds(size: size, scale: scale)
        guard let bitmap = makeBitmap(width: pixelsWide, height: pixelsHigh, isOpaque: false),
              let ctx = NSGraphicsContext(bitmapImageRep: bitmap)?.cgContext else {
            throw Error("Failed to create CGContext")
        }

        let flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: CGFloat(bitmap.pixelsHigh))
        ctx.concatenate(flip)
        ctx.draw(self, in: bounds)

        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw Error("Failed to retrieve jpeg data")
        }
        return data
    }

    func jpegData(scale: CGFloat = 0, compressionQuality quality: CGFloat = 1) throws -> Data {
        let scale = scale == 0 ? SVG.defaultScale : scale
        let (bounds, pixelsWide, pixelsHigh) = Self.makeBounds(size: size, scale: scale)
        guard let bitmap = makeBitmap(width: pixelsWide, height: pixelsHigh, isOpaque: true),
              let ctx = NSGraphicsContext(bitmapImageRep: bitmap)?.cgContext else {
            throw Error("Failed to create CGContext")
        }

        let flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: CGFloat(bitmap.pixelsHigh))
        ctx.concatenate(flip)
        ctx.setFillColor(.white)
        ctx.fill(bounds)
        ctx.draw(self, in: bounds)

        guard let data = bitmap.representation(using: .jpeg, properties: [NSBitmapImageRep.PropertyKey.compressionFactor: quality]) else {
            throw Error("Failed to retrieve jpeg data")
        }
        return data
    }

    internal static var defaultScale: CGFloat {
        NSScreen.main?.backingScaleFactor ?? 1.0
    }

    private struct Error: LocalizedError {
        var errorDescription: String?

        init(_ message: String) {
            self.errorDescription = message
        }
    }
}

extension SVG {

    func makeBitmap(width: Int, height: Int, isOpaque: Bool) -> NSBitmapImageRep? {
        guard width > 0 && height > 0 else { return nil }
        return NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: isOpaque ? 3 : 4,
            hasAlpha: !isOpaque,
            isPlanar: false,
            colorSpaceName: NSColorSpaceName.deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 32
        )
    }
}
#endif
