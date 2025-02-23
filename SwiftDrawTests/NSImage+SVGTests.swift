//
//  NSImage+SVGTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 27/11/18.
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

import XCTest
@testable import SwiftDraw
#if canImport(AppKit) && !targetEnvironment(macCatalyst)

final class NSImageSVGTests: XCTestCase {

  func testImageLoads() {
    let image = NSImage(svgNamed: "lines.svg", in: .test)
    XCTAssertNotNil(image)
  }

  func testMissingImageDoesNotLoad() {
    let image = NSImage(svgNamed: "missing.svg", in: .test)
    XCTAssertNil(image)
  }

  func testNSImageDraws() {
    let canvas = NSBitmapImageRep(pixelsWide: 2, pixelsHigh: 2)

    canvas.lockFocus()
    NSImage(svgNamed: "lines.svg", in: .test)?.draw(in: NSRect(x: 0, y: 0, width: 2, height: 2))
    canvas.unlockFocus()
  }

  func testImageDraws() {
    let canvas = NSBitmapImageRep(pixelsWide: 2, pixelsHigh: 2)
    let image = SVG.makeQuad().rasterize(with: CGSize(width: 2, height: 2))

    canvas.lockFocus()
    image.draw(in: NSRect(x: 0, y: 0, width: 2, height: 2))
    canvas.unlockFocus()

    XCTAssertEqual(canvas.colorAt(x: 0, y: 0), NSColor(deviceRed: 1.0, green: 0, blue: 0, alpha: 1.0))
    XCTAssertEqual(canvas.colorAt(x: 1, y: 1), NSColor(deviceRed: 0.0, green: 0, blue: 1.0, alpha: 1.0))
  }
}

private extension SVG {

  static func makeQuad() -> SVG {
    let svg = DOM.SVG(width: 2, height: 2)
    svg.childElements.append(DOM.Rect(x: 0, y: 0, width: 1, height: 1))
    svg.childElements.append(DOM.Rect(x: 1, y: 1, width: 1, height: 1))
    svg.childElements[0].attributes.fill = .color(DOM.Color.rgbi(255, 0, 0, 1.0))
    svg.childElements[1].attributes.fill = .color(DOM.Color.rgbi(0, 0, 255, 1.0))
    return SVG(dom: svg, options: .default)
  }
}

#endif
