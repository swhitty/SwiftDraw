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
        guard let contentMode = imageViewIfLoaded?.contentMode else { return }
        switch contentMode {
        case .center:
            imageViewIfLoaded?.contentMode = .scaleAspectFit
        case .scaleAspectFit:
            imageViewIfLoaded?.contentMode = .scaleAspectFill
        case .scaleAspectFill:
            imageViewIfLoaded?.contentMode = .center
        default:
            imageViewIfLoaded?.contentMode = .center
        }
    }

    var imageViewIfLoaded: UIImageView? {
        return viewIfLoaded as? UIImageView
    }

    override func loadView() {
        let imageView = UIImageView(frame: UIScreen.main.bounds)
        imageView.image = .svgGradientGratificationP3()
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .white
        self.view = imageView
      
        print(CGTextRenderer.render(named: "gradient-gratification-p3.svg")!)
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
  static func svgGradientGratificationP3() -> UIImage {
    let f = UIGraphicsImageRendererFormat.preferred()
    f.opaque = false
    return UIGraphicsImageRenderer(size: CGSize(width: 480.0, height: 352.0), format: f).image {
      drawSVG(in: $0.cgContext)
    }
  }

  private static func drawSVG(in ctx: CGContext) {
    let patternDraw: CGPatternDrawPatternCallback = { _, ctx in
      let rgb = CGColorSpaceCreateDeviceRGB()
      let color1 = CGColor(colorSpace: rgb, components: [0.2509804, 0.2509804, 0.2509804, 1.0])!
      ctx.setFillColor(color1)
      let path = CGPath(
        roundedRect: CGRect(x: 0.0, y: 0.0, width: 32.0, height: 32.0),
        cornerWidth: 0.0,
        cornerHeight: 0.0,
        transform: nil
      )
      ctx.addPath(path)
      ctx.fillPath(using: .evenOdd)
      let color2 = CGColor(colorSpace: rgb, components: [0.16078432, 0.16078432, 0.16078432, 1.0])!
      ctx.setFillColor(color2)
      let path1 = CGPath(
        roundedRect: CGRect(x: 32.0, y: 0.0, width: 32.0, height: 32.0),
        cornerWidth: 0.0,
        cornerHeight: 0.0,
        transform: nil
      )
      ctx.addPath(path1)
      ctx.fillPath(using: .evenOdd)
      let path2 = CGPath(
        roundedRect: CGRect(x: 0.0, y: 32.0, width: 32.0, height: 32.0),
        cornerWidth: 0.0,
        cornerHeight: 0.0,
        transform: nil
      )
      ctx.addPath(path2)
      ctx.fillPath(using: .evenOdd)
      ctx.setFillColor(color1)
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
      matrix: .identity,
      xStep: 64.0,
      yStep: 64.0,
      tiling: .constantSpacing,
      isColored: true,
      callbacks: &patternCallback
    )!
    ctx.setFillColorSpace(CGColorSpace(patternBaseSpace: nil)!)
    var patternAlpha : CGFloat = 1.0
    ctx.setFillPattern(pattern, colorComponents: &patternAlpha)
    let path = CGPath(
      roundedRect: CGRect(x: 0.0, y: 0.0, width: 480.0, height: 352.0),
      cornerWidth: 0.0,
      cornerHeight: 0.0,
      transform: nil
    )
    ctx.addPath(path)
    ctx.fillPath(using: .evenOdd)
    ctx.saveGState()
    let path1 = CGPath(
      roundedRect: CGRect(x: 112.0, y: 48.0, width: 256.0, height: 256.0),
      cornerWidth: 0.0,
      cornerHeight: 0.0,
      transform: nil
    )
    ctx.addPath(path1)
    ctx.clip()
    ctx.setAlpha(1.0)
    let p3 = CGColorSpace(name: CGColorSpace.displayP3)!
    let color1 = CGColor(colorSpace: p3, components: [1.0, 0.93, 0.19, 1.0])!
    let color2 = CGColor(colorSpace: p3, components: [1.0, 0.2, 0.3, 1.0])!
    var locations: [CGFloat] = [0.0, 1.0]
    let gradient = CGGradient(
      colorsSpace: p3,
      colors: [color1, color2] as CFArray,
      locations: &locations
    )!
    ctx.drawLinearGradient(gradient,
                       start: CGPoint(x: 112.0, y: 304.0),
                       end: CGPoint(x: 368.0, y: 304.0),
                       options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
    ctx.restoreGState()
    ctx.saveGState()
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    ctx.saveGState()
    ctx.addPath(path1)
    ctx.clip()
    ctx.setAlpha(1.0)
    let color3 = CGColor(colorSpace: p3, components: [0.0, 1.0, 1.0, 1.0])!
    let color4 = CGColor(colorSpace: p3, components: [0.2, 0.1, 0.5, 1.0])!
    var locations1: [CGFloat] = [0.0, 1.0]
    let gradient1 = CGGradient(
      colorsSpace: p3,
      colors: [color3, color4] as CFArray,
      locations: &locations1
    )!
    ctx.drawLinearGradient(gradient1,
                       start: CGPoint(x: 112.0, y: 304.0),
                       end: CGPoint(x: 368.0, y: 304.0),
                       options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
    ctx.restoreGState()
    ctx.setBlendMode(.destinationIn)
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    ctx.setBlendMode(.copy)
    ctx.saveGState()
    ctx.addPath(path1)
    ctx.clip()
    ctx.setAlpha(1.0)
    let gray = CGColorSpace(name: CGColorSpace.extendedGray)!
    let color5 = CGColor(colorSpace: gray, components: [0.0, 0.0])!
    let color6 = CGColor(colorSpace: gray, components: [0.0, 1.0])!
    let rgb = CGColorSpaceCreateDeviceRGB()
    var locations2: [CGFloat] = [0.0, 1.0]
    let gradient2 = CGGradient(
      colorsSpace: rgb,
      colors: [color5, color6] as CFArray,
      locations: &locations2
    )!
    ctx.drawLinearGradient(gradient2,
                       start: CGPoint(x: 112.0, y: 48.0),
                       end: CGPoint(x: 112.0, y: 304.0),
                       options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
    ctx.restoreGState()
    ctx.endTransparencyLayer()
    ctx.endTransparencyLayer()
    ctx.restoreGState()
  }
}
