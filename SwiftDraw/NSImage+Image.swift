//
//  NSImage+Image.swift
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

#if canImport(AppKit)
import AppKit
import CoreGraphics

public extension NSImage {

  convenience init?(svgNamed name: String, in bundle: Bundle = Bundle.main) {
    guard let image = Image(named: name, in: bundle) else { return nil }

    self.init(size: image.size, flipped: true) { rect in
      guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
      ctx.draw(image, in: CGRect(x: 0, y: 0, width: rect.size.width, height: rect.size.height))
      return true
    }
  }

  @objc
  static func svgNamed(_ name: String, inBundle: Bundle) -> NSImage? {
    NSImage(svgNamed: name, in: inBundle)
  }

  @objc
  static func svgNamed(_ name: String) -> NSImage? {
      NSImage(svgNamed: name, in: .main)
  }
}

public extension Image {
  func rasterize() -> NSImage {
    return rasterize(with: size)
  }

  func rasterize(with size: CGSize) -> NSImage {
    let imageSize = NSSize(width: size.width, height: size.height)

    let image = NSImage(size: imageSize, flipped: true) { rect in
      guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
      ctx.draw(self, in: CGRect(x: 0, y: 0, width: rect.size.width, height: rect.size.height))
      return true
    }

    return image
  }

  func createBitmap(size: CGSize? = nil, scale: CGFloat = 1, isOpaque: Bool = false) -> NSBitmapImageRep? {

    let defaultScale = NSScreen.main?.backingScaleFactor ?? 1.0
    let renderScale = scale == 0 ? defaultScale : scale
    let renderSize = size ?? self.size

    let width = Int(ceil(renderSize.width * renderScale))
    let height = Int(ceil(renderSize.height * renderScale))

    return NSBitmapImageRep(bitmapDataPlanes: nil,
                            pixelsWide: max(width, 0),
                            pixelsHigh: max(height, 0),
                            bitsPerSample: 8,
                            samplesPerPixel: isOpaque ? 3 : 4,
                            hasAlpha: !isOpaque,
                            isPlanar: false,
                            colorSpaceName: NSColorSpaceName.deviceRGB,
                            bytesPerRow: 0,
                            bitsPerPixel: 32)
  }

  func pngData(size: CGSize? = nil, scale: CGFloat = 1) -> Data? {
    guard let bitmap = createBitmap(size: size, scale: scale, isOpaque: false),
      let ctx = NSGraphicsContext(bitmapImageRep: bitmap)?.cgContext else { return nil }

    let rect = CGRect(x: 0, y: 0, width: CGFloat(bitmap.pixelsWide), height: CGFloat(bitmap.pixelsHigh))
    let flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: rect.size.height)
    ctx.concatenate(flip)
    ctx.draw(self, in: rect)

    return bitmap.representation(using: .png, properties: [:])
  }

  func jpegData(size: CGSize? = nil, scale: CGFloat = 1, compressionQuality quality: CGFloat = 1) -> Data? {
    guard let bitmap = createBitmap(size: size, scale: scale, isOpaque: true),
      let ctx = NSGraphicsContext(bitmapImageRep: bitmap)?.cgContext else { return nil }

    let rect = CGRect(x: 0, y: 0, width: CGFloat(bitmap.pixelsWide), height: CGFloat(bitmap.pixelsHigh))

    let flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: rect.size.height)
    ctx.concatenate(flip)
    ctx.setFillColor(.white)
    ctx.fill(rect)
    ctx.draw(self, in: rect)

    return bitmap.representation(using: .jpeg, properties: [NSBitmapImageRep.PropertyKey.compressionFactor: quality])
  }
}

#endif
