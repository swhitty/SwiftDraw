//
//  UIImage+SVG.swift
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

#if canImport(UIKit)
import UIKit
#if canImport(WatchKit)
import WatchKit
#endif

public extension UIImage {

    convenience init?(svgNamed name: String, in bundle: Bundle = .main, options: SVG.Options = .default) {
        guard let image = SVG(named: name, in: bundle, options: options) else { return nil }
        self.init(image)
    }

    @objc(initWithSVGData:)
    convenience init?(svgData: Data) {
        guard let image = SVG(data: svgData) else { return nil }
        self.init(image)
    }

    @objc(initWithContentsOfSVGFile:)
    convenience init?(contentsOfSVGFile path: String) {
        guard let image = SVG(fileURL: URL(fileURLWithPath: path)) else { return nil }
        self.init(image)
    }

    @objc(svgNamed:)
    static func _svgNamed(_ name: String) -> UIImage? {
        UIImage(svgNamed: name, in: .main)
    }

    @objc(svgNamed:inBundle:)
    static func _svgNamed(_ name: String, in bundle: Bundle) -> UIImage? {
        UIImage(svgNamed: name, in: bundle)
    }

    convenience init(_ image: SVG) {
        let image = image.rasterize()
        self.init(cgImage: image.cgImage!, scale: image.scale, orientation: image.imageOrientation)
    }
}

public extension SVG {

#if os(watchOS)
    func rasterize(scale: CGFloat = 0) -> UIImage {
        let (bounds, pixelsWide, pixelsHigh) = SVG.makeBounds(size: size, scale: 1)
        let actualScale = scale <= 0 ? SVG.defaultScale : scale
        UIGraphicsBeginImageContextWithOptions(CGSize(width: pixelsWide, height: pixelsHigh), false, actualScale)
        defer { UIGraphicsEndImageContext() }
        
        if let context = UIGraphicsGetCurrentContext() {
            context.draw(self, in: bounds)
        }
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
#else
    func rasterize(scale: CGFloat = 0) -> UIImage {
        let (bounds, pixelsWide, pixelsHigh) = SVG.makeBounds(size: size, scale: 1)
        let f = UIGraphicsImageRendererFormat.preferred()
        f.preferredRange = .automatic
        f.scale = scale <= 0 ? SVG.defaultScale : scale
        f.opaque = false
        let r = UIGraphicsImageRenderer(size: CGSize(width: pixelsWide, height: pixelsHigh), format: f)
        return r.image {
            $0.cgContext.draw(self, in: bounds)
        }
    }
#endif

    func rasterize(size: CGSize, scale: CGFloat = 0) -> UIImage {
        self.sized(size).rasterize(scale: scale)
    }

    func pngData(scale: CGFloat = 0) throws -> Data {
        let image = rasterize(scale: scale)
        guard let data = image.pngData() else {
            throw Error("Failed to create png data")
        }
        return data
    }

    func jpegData(scale: CGFloat = 0, compressionQuality quality: CGFloat = 1) throws -> Data {
        let image = rasterize(scale: scale)
        guard let data = image.jpegData(compressionQuality: quality) else {
            throw Error("Failed to create jpeg data")
        }
        return data
    }
}

extension SVG {

    static var defaultScale: CGFloat {
#if os(watchOS)
        WKInterfaceDevice.current().screenScale
#else
        UIScreen.main.scale
#endif
    }

    private struct Error: LocalizedError {
        var errorDescription: String?

        init(_ message: String) {
            self.errorDescription = message
        }
    }
}

#endif
