[![Build](https://github.com/swhitty/SwiftDraw/actions/workflows/build.yml/badge.svg)](https://github.com/swhitty/SwiftDraw/actions/workflows/build.yml)
[![CodeCov](https://codecov.io/gh/swhitty/SwiftDraw/graphs/badge.svg)](https://codecov.io/gh/swhitty/SwiftDraw)
[![Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fswhitty%2FSwiftDraw%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/swhitty/SwiftDraw)
[![Swift 6.0](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fswhitty%2FSwiftDraw%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/swhitty/SwiftDraw)

# Introduction
**SwiftDraw** is Swift library for parsing and drawing SVG images and includes a command line tool to convert SVGs into SFSymbol, PNG, PDF and Swift source code.

- [Usage](#usage)
  - [SwiftUI](#swiftui)
  - [UIKit](#uikit)
  - [AppKit](#appkit)
- [Command Line Tool](#command-line-tool)
  - [Installation](#installation)
  - [SF Symbol](#sf-symbol)
    - [Alignment](#alignment)
  - [Swift Code Generation](#swift-code-generation)
- [Credits](#credits)

## Usage

Vector images can be easily loaded and rasterized to `UIImage` or `NSImage`:

```swift
let svg = SVG(named: "sample.svg", in: .main)!
imageView.image = svg.rasterize()
```

Transformations can be added before rasterizing: 

```swift
let svg = SVG(named: "fish.svg")!   // 100x100 
    .expanded(left: 10, right: 10) // 120x100
    .scaled(2)                     // 240x200

imageView.image = svg.rasterize()  // 240x200
```

### SwiftUI

Display an image within `SVGView`:

```swift
var body: some View {
    SVGView(named: "sample.svg")
        .aspectRatio(contentMode: .fit)
        .padding()
}
```

Pass an `SVG` instance for better performance:

```swift
var image: SVG

var body: some View {
    SVGView(svg: image)
}
```

### UIKit

Create a `UIImage` directly from an SVG within a bundle, `Data` or file `URL`:

```swift
import SwiftDraw
let image = UIImage(svgNamed: "sample.svg")
```

### AppKit

Create an `NSImage` directly from an SVG within a bundle, `Data` or file `URL`:

```swift
import SwiftDraw
let image = NSImage(svgNamed: "sample.svg")
```

## Command line tool

The command line tool converts SVGs to other formats: PNG, JPEG, SFSymbol and Swift source code.

```
copyright (c) 2025 Simon Whitty

usage: swiftdraw <file.svg> [--format png | pdf | jpeg | swift | sfsymbol] [--size wxh] [--scale 1x | 2x | 3x]

<file> svg file to be processed

Options:
 --format      format to output image: png | pdf | jpeg | swift | sfsymbol
 --size        size of output image: 100x200
 --scale       scale of output image: 1x | 2x | 3x
 --insets      crop inset of output image: top,left,bottom,right
 --precision   maximum number of decimal places
 --output      optional path of output file

 --hideUnsupportedFilters   hide elements with unsupported filters.

Available keys for --format swift:
 --api                api of generated code:  appkit | uikit

Available keys for --format sfsymbol:
 --insets             alignment of regular variant: top,left,bottom,right | auto
 --ultralight         svg file of ultralight variant
 --ultralightInsets   alignment of ultralight variant: top,left,bottom,right | auto
 --black              svg file of black variant
 --blackInsets        alignment of black variant: top,left,bottom,right | auto
```

```bash
$ swiftdraw simple.svg --format png --scale 3x
```

```bash
$ swiftdraw simple.svg --format pdf
```

### Installation

You can install the `swiftdraw` command-line tool on macOS using [Homebrew](http://brew.sh/). Assuming you already have Homebrew installed, just type:

```bash
$ brew install swiftdraw
```

To update to the latest version once installed:

```bash
$ brew upgrade swiftdraw
```

Alternatively download the latest command line tool [here](https://github.com/swhitty/SwiftDraw/releases/latest/download/SwiftDraw.dmg.zip).

### SF Symbol

Custom SF Symbols can be created from a single SVG.  SwiftDraw expands strokes, winds paths using the [non-zero rule](https://en.wikipedia.org/wiki/Nonzero-rule) and aligns elements generating a symbol that can be imported directly into Xcode.

<big><pre>
$ swiftdraw [key.svg](https://github.com/swhitty/SwiftDraw/blob/main/Samples.bundle/key/key.svg) --format sfsymbol
</pre></big>
<img src="https://github.com/swhitty/SwiftDraw/blob/main/Samples.bundle/key/key-single.svg" width="400" />

Optional variants `--ultralight` and `--black` can also be provided:

<big><pre>
$ swiftdraw [key.svg](https://github.com/swhitty/SwiftDraw/blob/main/Samples.bundle/key/key.svg) --format sfsymbol --ultralight [key-ultralight.svg](https://github.com/swhitty/SwiftDraw/blob/main/Samples.bundle/key/key-ultralight.svg) --black [key-black.svg](https://github.com/swhitty/SwiftDraw/blob/main/Samples.bundle/key/key-black.svg)
</pre></big>
<img src="https://github.com/swhitty/SwiftDraw/blob/main/Samples.bundle/key/key-symbol.svg" width="400" />

#### Alignment

By default, SwiftDraw automatically sizes and aligns the content to the template guides.  The auto alignment insets are output by the tool:

```bash
$ swiftdraw simple.svg --format sfsymbol --insets auto
Alignment: --insets 30,30,30,30
```

Insets can be provided in the form `--insets top,left,bottom,right` specifying a `Double` or `auto` for each edge:

```bash
$ swiftdraw simple.svg --format sfsymbol --insets 40,auto,40,auto
Alignment: --insets 40,30,40,30
```

Variants can also be aligned using `--ultralightInsets` and `--blackInsets`.

### Swift Code Generation

Swift source code can also be generated from an SVG using the tool:

```bash
$ swiftdraw simple.svg --format swift
```

```xml
<?xml version="1.0" encoding="utf-8"?>
<svg version="1.1" xmlns="http://www.w3.org/2000/svg" width="160" height="160">
  <rect width="160" height="160" fill="snow" />
  <path d="m 80 30 a 50 50 0 1 0 50 50 h -50 z" fill="pink" stroke="black" stroke-width="2"/>
</svg>
```

```swift
extension UIImage {
  static func svgSimple(size: CGSize = CGSize(width: 160.0, height: 160.0)) -> UIImage {
    let f = UIGraphicsImageRendererFormat.preferred()
    f.opaque = false
    let scale = CGSize(width: size.width / 160.0, height: size.height / 160.0)
    return UIGraphicsImageRenderer(size: size, format: f).image {
      drawSimple(in: $0.cgContext, scale: scale)
    }
  }

  private static func drawSimple(in ctx: CGContext, scale: CGSize) {
    ctx.scaleBy(x: scale.width, y: scale.height)
    let rgb = CGColorSpaceCreateDeviceRGB()
    let color1 = CGColor(colorSpace: rgb, components: [1, 0.98, 0.98, 1])!
    ctx.setFillColor(color1)
    ctx.fill(CGRect(x: 0, y: 0, width: 160, height: 160))
    let color2 = CGColor(colorSpace: rgb, components: [1, 0.753, 0.796, 1])!
    ctx.setFillColor(color2)
    let path = CGMutablePath()
    path.move(to: CGPoint(x: 80, y: 30))
    path.addCurve(to: CGPoint(x: 30, y: 80),
                   control1: CGPoint(x: 52.39, y: 30),
                   control2: CGPoint(x: 30, y: 52.39))
    path.addCurve(to: CGPoint(x: 80, y: 130),
                   control1: CGPoint(x: 30, y: 107.61),
                   control2: CGPoint(x: 52.39, y: 130))
    path.addCurve(to: CGPoint(x: 130, y: 80),
                   control1: CGPoint(x: 107.61, y: 130),
                   control2: CGPoint(x: 130, y: 107.61))
    path.addLine(to: CGPoint(x: 80, y: 80))
    path.closeSubpath()
    ctx.addPath(path)
    ctx.fillPath()
    ctx.setLineCap(.butt)
    ctx.setLineJoin(.miter)
    ctx.setLineWidth(2)
    ctx.setMiterLimit(4)
    let color3 = CGColor(colorSpace: rgb, components: [0, 0, 0, 1])!
    ctx.setStrokeColor(color3)
    ctx.addPath(path)
    ctx.strokePath()
  }
}
```

Source code can be generated using [www.whileloop.com/swiftdraw](https://www.whileloop.com/swiftdraw).


# Credits

SwiftDraw is primarily the work of [Simon Whitty](https://github.com/swhitty).

([Full list of contributors](https://github.com/swhitty/SwiftDraw/graphs/contributors))
