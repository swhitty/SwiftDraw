[![Travis](https://api.travis-ci.org/swhitty/SwiftDraw.svg?branch=master)](https://travis-ci.org/swhitty/SwiftDraw)
[![CodeCov](https://codecov.io/gh/swhitty/SwiftDraw/branch/master/graphs/badge.svg)](https://codecov.io/gh/swhitty/SwiftDraw/branch/master)
[![Swift 5.0](https://img.shields.io/badge/swift-5.0-red.svg?style=flat)](https://developer.apple.com/swift)
[![License](https://img.shields.io/badge/license-zlib-lightgrey.svg)](https://opensource.org/licenses/Zlib)
[![Twitter](https://img.shields.io/badge/twitter-@simonwhitty-blue.svg)](http://twitter.com/simonwhitty)

# SwiftDraw

A Swift library for parsing and drawing SVG images to CoreGraphics contexts.  SwiftDraw can also convert an SVG into Swift source code.

## Usage

## iOS

```swift
import SwiftDraw
let image = UIImage(svgNamed: "sample.svg")
```

## macOS

```swift
import SwiftDraw
let image = NSImage(svgNamed: "sample.svg")
```

### Command line tool

Download the latest command line tool [here](https://github.com/swhitty/SwiftDraw/releases/latest/download/SwiftDraw.dmg).

`$ swiftdraw sample.svg --format pdf --size 48x48`


#### Source code generation

The command line tool can also convert an SVG image into Swift source code:

```xml
<?xml version="1.0" encoding="utf-8"?>
<svg version="1.1" xmlns="http://www.w3.org/2000/svg" width="160" height="160">
  <rect width="160" height="160" fill="snow" />
  <path d="m 80 20 a 50 50 0 1 0 50 50 h -50 z" fill="pink" stroke="black" stroke-width="2"/>
</svg>
```

`$ swiftdraw simple.svg --format swift`

```swift
extension UIImage {
  static func svgSimple() -> UIImage {
    let f = UIGraphicsImageRendererFormat.default()
    f.opaque = false
    f.preferredRange = .standard
    return UIGraphicsImageRenderer(size: CGSize(width: 160.0, height: 160.0), format: f).image {
      drawSVG(in: $0.cgContext)
    }
  }

  private static func drawSVG(in ctx: CGContext) {
    let rgb = CGColorSpaceCreateDeviceRGB()
    let color1 = CGColor(colorSpace: rgb, components: [1.0, 0.98039216, 0.98039216, 1.0])!
    ctx.setFillColor(color1)
    let path = CGPath(
      roundedRect: CGRect(x: 0.0, y: 0.0, width: 160.0, height: 160.0),
      cornerWidth: 0.0,
      cornerHeight: 0.0,
      transform: nil
    )
    ctx.addPath(path)
    ctx.fillPath(using: .evenOdd)
    let color2 = CGColor(colorSpace: rgb, components: [1.0, 0.7529412, 0.79607844, 1.0])!
    ctx.setFillColor(color2)
    let path1 = CGMutablePath()
    path1.move(to: CGPoint(x: 80.0, y: 20.0))
    path1.addCurve(to: CGPoint(x: 30.0, y: 69.99999),
                   control1: CGPoint(x: 52.38576, y: 20.0),
                   control2: CGPoint(x: 30.000004, y: 42.385757))
    path1.addCurve(to: CGPoint(x: 79.99998, y: 120.0),
                   control1: CGPoint(x: 29.999992, y: 97.61423),
                   control2: CGPoint(x: 52.385742, y: 119.999985))
    path1.addCurve(to: CGPoint(x: 130.0, y: 70.00004),
                   control1: CGPoint(x: 107.61421, y: 120.000015),
                   control2: CGPoint(x: 129.99998, y: 97.61427))
    path1.addLine(to: CGPoint(x: 80.0, y: 70.00004))
    path1.closeSubpath()
    ctx.addPath(path1)
    ctx.fillPath(using: .evenOdd)
    ctx.setLineCap(.butt)
    ctx.setLineJoin(.miter)
    ctx.setLineWidth(2.0)
    ctx.setMiterLimit(4.0)
    let color3 = CGColor(colorSpace: rgb, components: [0.0, 0.0, 0.0, 1.0])!
    ctx.setStrokeColor(color3)
    ctx.addPath(path1)
    ctx.strokePath()
  }
}
```

