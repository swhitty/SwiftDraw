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

public extension UIImage {

  convenience init?(svgNamed name: String, in bundle: Bundle = Bundle.main) {
    guard let image = Image(named: name, in: bundle)?.rasterize(),
      let cgImage = image.cgImage else {
        return nil
    }

    self.init(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
  }

  @objc
  static func svgNamed(_ name: String, inBundle: Bundle) -> UIImage? {
    UIImage(svgNamed: name, in: inBundle)
  }

  @objc
  static func svgNamed(_ name: String) -> UIImage? {
      UIImage(svgNamed: name, in: .main)
  }
}

public extension Image {
  func rasterize() -> UIImage {
    return rasterize(with: size)
  }
  
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

  func rasterize(with size: CGSize) -> UIImage {
    let f = makeFormat()
    f.opaque = false
    let r = UIGraphicsImageRenderer(size: size, format: f)
    return r.image{
      $0.cgContext.draw(self, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
    }
  }

  func pngData(size: CGSize? = nil, scale: CGFloat = 1) -> Data? {
    let pngSize = size ?? self.size
    return rasterize(with: pngSize).pngData()
  }

  func jpegData(size: CGSize? = nil, scale: CGFloat = 1, compressionQuality quality: CGFloat = 1) -> Data? {
    let jpgSize = size ?? self.size
    return rasterize(with: jpgSize).jpegData(compressionQuality: quality)
  }
}

#endif
