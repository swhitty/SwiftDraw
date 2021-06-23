//
//  ViewController.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 10/2/19.
//  Copyright 2019 Simon Whitty
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

import SwiftDraw
import UIKit

class ViewController: UIViewController {

    init() {
        super.init(nibName: nil, bundle: nil)
        self.title = "SVG"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Mode", style: .plain, target: self, action: #selector(didTap))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc
    func didTap() {
        guard let size = imageViewIfLoaded?.image?.size else { return }

        switch size {
        case CGSize(width: 480, height: 352):
            imageViewIfLoaded?.image = Image(named: "gradient-gratification-p3.svg")?.rasterize(with: CGSize(width: 960, height: 704))
        default:
            imageViewIfLoaded?.image = Image(named: "gradient-gratification-p3.svg")?.rasterize(with: CGSize(width: 480, height: 352))
        }
//        guard let contentMode = imageViewIfLoaded?.contentMode else { return }
//        switch contentMode {
//        case .center:
//            imageViewIfLoaded?.contentMode = .scaleAspectFit
//        case .scaleAspectFit:
//            imageViewIfLoaded?.contentMode = .scaleAspectFill
//        case .scaleAspectFill:
//            imageViewIfLoaded?.contentMode = .center
//        default:
//            imageViewIfLoaded?.contentMode = .center
//        }
    }

    var imageViewIfLoaded: UIImageView? {
        return viewIfLoaded as? UIImageView
    }

    override func loadView() {
        let imageView = UIImageView(frame: UIScreen.main.bounds)
        imageView.image = .svgPatternRotate()
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .white
        self.view = imageView
      
        print(CGTextRenderer.render(named: "pattern-rotate.svg")!)
    }
}

private extension Image {

  // UIImage backed with PDF preserves vector data.

  func pdfImage() -> UIImage? {
    guard
      let data = pdfData(),
      let provider = CGDataProvider(data: data as CFData),
      let pdf = CGPDFDocument(provider),
      let page = pdf.page(at: 1) else {
        return nil
    }

    return UIImage
      .perform(NSSelectorFromString("_imageWithCGPDFPage:"), with: page)?
      .takeUnretainedValue() as? UIImage
  }
}

extension UIImage {
  static func svgPatternRotate(size: CGSize = CGSize(width: 256.0, height: 256.0)) -> UIImage {
    let f = UIGraphicsImageRendererFormat.preferred()
    f.opaque = false
    let scale = CGSize(width: size.width / 256.0, height: size.height / 256.0)
    return UIGraphicsImageRenderer(size: size, format: f).image {
      drawSVG(in: $0.cgContext, scale: scale)
    }
  }

  private static func drawSVG(in ctx: CGContext, scale: CGSize) {
    let baseCTM = ctx.ctm
    ctx.scaleBy(x: scale.width, y: scale.height)
    let rgb = CGColorSpaceCreateDeviceRGB()
    let color1 = CGColor(colorSpace: rgb, components: [1.0, 0.98039216, 0.98039216, 1.0])!
    ctx.setFillColor(color1)
    let path = CGPath(
      roundedRect: CGRect(x: 0.0, y: 0.0, width: 256.0, height: 256.0),
      cornerWidth: 0.0,
      cornerHeight: 0.0,
      transform: nil
    )
    ctx.addPath(path)
    ctx.fillPath(using: .evenOdd)
    ctx.saveGState()
    ctx.translateBy(x: 128.0, y: 128.0)
    ctx.rotate(by: 0.7853981)
    let patternDraw: CGPatternDrawPatternCallback = { _, ctx in
      let rgb = CGColorSpaceCreateDeviceRGB()
      let color1 = CGColor(colorSpace: rgb, components: [0.0, 0.5019608, 0.0, 1.0])!
      ctx.setFillColor(color1)
      let path = CGPath(
        roundedRect: CGRect(x: 0.0, y: 0.0, width: 32.0, height: 32.0),
        cornerWidth: 0.0,
        cornerHeight: 0.0,
        transform: nil
      )
      ctx.addPath(path)
      ctx.fillPath(using: .evenOdd)
      let color2 = CGColor(colorSpace: rgb, components: [1.0, 0.0, 0.0, 1.0])!
      ctx.setFillColor(color2)
      let path1 = CGPath(
        roundedRect: CGRect(x: 32.0, y: 0.0, width: 32.0, height: 32.0),
        cornerWidth: 0.0,
        cornerHeight: 0.0,
        transform: nil
      )
      ctx.addPath(path1)
      ctx.fillPath(using: .evenOdd)
      let color3 = CGColor(colorSpace: rgb, components: [0.0, 0.0, 1.0, 1.0])!
      ctx.setFillColor(color3)
      let path2 = CGPath(
        roundedRect: CGRect(x: 0.0, y: 32.0, width: 32.0, height: 32.0),
        cornerWidth: 0.0,
        cornerHeight: 0.0,
        transform: nil
      )
      ctx.addPath(path2)
      ctx.fillPath(using: .evenOdd)
      let color4 = CGColor(colorSpace: rgb, components: [1.0, 0.7529412, 0.79607844, 1.0])!
      ctx.setFillColor(color4)
      let path3 = CGPath(
        roundedRect: CGRect(x: 32.0, y: 32.0, width: 32.0, height: 32.0),
        cornerWidth: 0.0,
        cornerHeight: 0.0,
        transform: nil
      )
      ctx.addPath(path3)
      ctx.fillPath(using: .evenOdd)
    }
    var patternCallback = CGPatternCallbacks(version: 0, drawPattern: patternDraw, releaseInfo: nil)
    let pattern = CGPattern(
      info: nil,
      bounds: CGRect(x: 0.0, y: 0.0, width: 64.0, height: 64.0),
      matrix: ctx.ctm.concatenating(baseCTM.inverted()),
      xStep: 64.0,
      yStep: 64.0,
      tiling: .constantSpacing,
      isColored: true,
      callbacks: &patternCallback
    )!
    ctx.setFillColorSpace(CGColorSpace(patternBaseSpace: nil)!)
    var patternAlpha : CGFloat = 1.0
    ctx.setFillPattern(pattern, colorComponents: &patternAlpha)
    let path1 = CGPath(
      roundedRect: CGRect(x: -64.0, y: -64.0, width: 128.0, height: 128.0),
      cornerWidth: 0.0,
      cornerHeight: 0.0,
      transform: nil
    )
    ctx.addPath(path1)
    ctx.fillPath(using: .evenOdd)
    ctx.restoreGState()
  }
}
