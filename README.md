[![Travis](https://api.travis-ci.org/swhitty/SwiftDraw.svg?branch=master)](https://travis-ci.org/swhitty/SwiftDraw)
[![CodeCov](https://codecov.io/gh/swhitty/SwiftDraw/branch/master/graphs/badge.svg)](https://codecov.io/gh/swhitty/SwiftDraw/branch/master)
[![Swift 5.0](https://img.shields.io/badge/swift-5.0-red.svg?style=flat)](https://developer.apple.com/swift)
[![License](https://img.shields.io/badge/license-zlib-lightgrey.svg)](https://opensource.org/licenses/Zlib)
[![Twitter](https://img.shields.io/badge/twitter-@simonwhitty-blue.svg)](http://twitter.com/simonwhitty)

# SwiftDraw

A Swift library for parsing and drawing SVG images to CoreGraphics contexts.

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
