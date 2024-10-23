//
//  UIImage+Image.swift
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
    func rasterize() -> UIImage {
        return rasterize(with: size)
    }

#if os(watchOS)
    func rasterize(with size: CGSize? = nil, scale: CGFloat = 0, insets: UIEdgeInsets = .zero) -> UIImage {
        let insets = Insets(top: insets.top, left: insets.left, bottom: insets.bottom, right: insets.right)
        let actualScale = scale <= 0 ? WKInterfaceDevice.current().screenScale : scale
        let (bounds, pixelsWide, pixelsHigh) = makeBounds(size: size, scale: actualScale, insets: insets)
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: pixelsWide, height: pixelsHigh), false, actualScale)
        defer { UIGraphicsEndImageContext() }
        
        if let context = UIGraphicsGetCurrentContext() {
            context.draw(self, in: bounds)
        }
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
#else
    private func makeFormat() -> UIGraphicsImageRendererFormat {
        guard #available(iOS 12.0, *) else {
            let f = UIGraphicsImageRendererFormat.default()
            f.prefersExtendedRange = true
            return f
        }
        let f = UIGraphicsImageRendererFormat.preferred()
        f.preferredRange = .automatic
        return f
    }

    func rasterize(with size: CGSize? = nil, scale: CGFloat = 0, insets: UIEdgeInsets = .zero) -> UIImage {
        let insets = Insets(top: insets.top, left: insets.left, bottom: insets.bottom, right: insets.right)
        let actualScale = scale <= 0 ? UIScreen.main.scale : scale
        let (bounds, pixelsWide, pixelsHigh) = makeBounds(size: size, scale: actualScale, insets: insets)

        let f = makeFormat()
        f.scale = actualScale
        f.opaque = false
        let r = UIGraphicsImageRenderer(size: CGSize(width: pixelsWide, height: pixelsHigh), format: f)
        return r.image{
            $0.cgContext.draw(self, in: bounds)
        }
    }
#endif

    func pngData(size: CGSize? = nil, scale: CGFloat = 0, insets: UIEdgeInsets = .zero) throws -> Data {
        let image = rasterize(with: size, scale: scale, insets: insets)
        guard let data = image.pngData() else {
            throw Error("Failed to create png data")
        }
        return data
    }

    func jpegData(size: CGSize? = nil, scale: CGFloat = 0, compressionQuality quality: CGFloat = 1, insets: UIEdgeInsets = .zero) throws -> Data {
        let image = rasterize(with: size, scale: scale, insets: insets)
        guard let data = image.jpegData(compressionQuality: quality) else {
            throw Error("Failed to create jpeg data")
        }
        return data
    }
}

extension SVG {

    func jpegData(size: CGSize?, scale: CGFloat, insets: Insets) throws -> Data {
        let insets = UIEdgeInsets(top: insets.top, left: insets.left, bottom: insets.bottom, right: insets.right)
        return try jpegData(size: size, scale: scale, insets: insets)
    }

    func pngData(size: CGSize?, scale: CGFloat, insets: Insets) throws -> Data {
        let insets = UIEdgeInsets(top: insets.top, left: insets.left, bottom: insets.bottom, right: insets.right)
        return try pngData(size: size, scale: scale, insets: insets)
    }

    func makeBounds(size: CGSize?, scale: CGFloat, insets: Insets) -> (bounds: CGRect, pixelsWide: Int, pixelsHigh: Int) {
        let newScale: CGFloat = {
#if os(watchOS)
            return scale <= 0 ? WKInterfaceDevice.current().screenScale : scale
#else
            return scale <= 0 ? UIScreen.main.scale : scale
#endif
        }()
        return Self.makeBounds(size: size, defaultSize: self.size, scale: newScale, insets: insets)
    }

    private struct Error: LocalizedError {
        var errorDescription: String?

        init(_ message: String) {
            self.errorDescription = message
        }
    }
}

#endif
