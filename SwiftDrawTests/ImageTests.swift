//
//  ScannerTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 19/11/18.
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

final class ImageTests: XCTestCase {

  #if SWIFT_PACKAGE
  #else
  func testValidSVGLoads() {
    XCTAssertNotNil(Image(named: "lines.svg", in: .test))
  }
  #endif

  func testInvalidSVGReturnsNil() {
    XCTAssertNil(Image(named: "invalid.svg", in: .test))
  }

  func testMissingSVGReturnsNil() {
    XCTAssertNil(Image(named: "missing.svg", in: .test))
  }

#if canImport(CoreGraphics)
  func testImageRasterizes() {
    let image = Image.makeLines()
    let rendered = image.rasterize()
    XCTAssertEqual(rendered.size, image.size)
    XCTAssertNotNil(image.pngData())
    XCTAssertNotNil(image.jpegData())
    XCTAssertNotNil(image.pdfData())
  }

  func testImageRasterizeAndScales() {
    let image = Image.makeLines()
    let doubleSize = CGSize(width: 200, height: 200)
    let rendered = image.rasterize(with: doubleSize)
    XCTAssertEqual(rendered.size, doubleSize)
    XCTAssertNotNil(image.pngData(size: doubleSize))
    XCTAssertNotNil(image.jpegData(size: doubleSize))
  }
#endif

}

private extension Image {

  static func makeLines() -> Image {
    let svg = DOM.SVG(width: 100, height: 100)
    svg.childElements.append(DOM.Line(x1: 0, y1: 0, x2: 100, y2: 100))
    svg.childElements.append(DOM.Line(x1: 100, y1: 0, x2: 0, y2: 100))
    return Image(svg: svg)
  }
}
