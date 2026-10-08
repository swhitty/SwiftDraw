//
//  CGRendererTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 18/12/18.
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

@testable import SwiftDrawDOM
@testable import SwiftDraw

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
import CoreGraphics
import XCTest

final class CGRendererTests: XCTestCase {
  
  func testDrawsRect() {
    let renderer = ImageRenderer(pixelsWide: 2, pixelsHigh: 2)
    
    renderer.renderer.setFill(color: .red)
    renderer.renderer.fill(path: CGPath.rect(), rule: .evenOdd)
    
    XCTAssertEqual(renderer.getColor(x: 0, y: 0), .red)
    XCTAssertEqual(renderer.getColor(x: 1, y: 1), .red)
  }
  
  func testLineDashLeavesGaps() {
    let renderer = ImageRenderer(pixelsWide: 20, pixelsHigh: 4)
    let path = CGMutablePath()
    path.move(to: CGPoint(x: 0, y: 2))
    path.addLine(to: CGPoint(x: 20, y: 2))

    renderer.renderer.setStroke(color: .red)
    renderer.renderer.setLine(width: 4)
    renderer.renderer.setLineDash(phase: 0, lengths: [5, 5])
    renderer.renderer.stroke(path: path)

    XCTAssertEqual(renderer.getColor(x: 2, y: 2), .red)
    XCTAssertNotEqual(renderer.getColor(x: 7, y: 2), .red)
    XCTAssertEqual(renderer.getColor(x: 12, y: 2), .red)
  }

  func testPreserveAspectRatioLetterboxesViewBox() throws {
    // 100x100 viewBox in a 200x100 viewport: xMidYMid meet centres it, leaving 50px bands either side
    let dom = try DOM.SVG.parse(xml: """
    <svg xmlns="http://www.w3.org/2000/svg" width="200" height="100" viewBox="0 0 100 100">
    <rect width="100" height="100" fill="red"/></svg>
    """)
    let svg = SVG(dom: dom, options: .default)
    let renderer = ImageRenderer(pixelsWide: 200, pixelsHigh: 100)
    renderer.renderer.perform(svg.commands)

    XCTAssertTrue(renderer.isSVGRed(x: 100, y: 50))
    XCTAssertTrue(renderer.isSVGRed(x: 55, y: 50))
    XCTAssertFalse(renderer.isSVGRed(x: 45, y: 50))
    XCTAssertFalse(renderer.isSVGRed(x: 155, y: 50))
  }

  func testPreserveAspectRatioSliceFillsViewport() throws {
    let dom = try DOM.SVG.parse(xml: """
    <svg xmlns="http://www.w3.org/2000/svg" width="200" height="100" viewBox="0 0 100 100" preserveAspectRatio="xMinYMin slice">
    <rect width="100" height="100" fill="red"/></svg>
    """)
    let svg = SVG(dom: dom, options: .default)
    let renderer = ImageRenderer(pixelsWide: 200, pixelsHigh: 100)
    renderer.renderer.perform(svg.commands)

    XCTAssertTrue(renderer.isSVGRed(x: 5, y: 5))
    XCTAssertTrue(renderer.isSVGRed(x: 195, y: 95))
  }

  func testRootSliceDoesNotBleedOutsideItsViewport() throws {
    // drawn into a larger context, the overflow of a sliced viewBox is clipped to the 200x100 viewport
    let dom = try DOM.SVG.parse(xml: """
    <svg xmlns="http://www.w3.org/2000/svg" width="200" height="100" viewBox="0 0 100 100" preserveAspectRatio="xMinYMin slice">
    <rect x="-50" y="-50" width="300" height="300" fill="red"/></svg>
    """)
    let svg = SVG(dom: dom, options: .default)
    let renderer = ImageRenderer(pixelsWide: 300, pixelsHigh: 200)
    renderer.renderer.perform(svg.commands)

    // the context is not flipped, so the 200x100 viewport is the bottom half of the 300x200 bitmap (rows 100...199)
    XCTAssertTrue(renderer.isSVGRed(x: 100, y: 150))
    XCTAssertFalse(renderer.isSVGRed(x: 250, y: 150))
    XCTAssertFalse(renderer.isSVGRed(x: 100, y: 50))
  }

  func testAlphaClips() {
    let renderer = ImageRenderer(pixelsWide: 2, pixelsHigh: 2)
    
    renderer.renderer.setFill(color: .red)
    renderer.renderer.fill(path: CGPath.rect(), rule: .evenOdd)
    
    XCTAssertEqual(renderer.getColor(x: 0, y: 0), .red)
    XCTAssertEqual(renderer.getColor(x: 1, y: 1), .red)
  }
}

final class ImageRenderer {
  
  let renderer: CGRenderer
  private let bitmap: NSBitmapImageRep
  
  init(pixelsWide: Int, pixelsHigh: Int) {
    self.bitmap = NSBitmapImageRep(pixelsWide: pixelsWide,
                                   pixelsHigh: pixelsHigh)
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!.cgContext
    self.renderer = CGRenderer(context: context)
  }
  
  /// `.red` in this file is a test colour; an SVG `red` fill reads back as pure (1, 0, 0)
  func isSVGRed(x: Int, y: Int) -> Bool {
    guard let c = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { return false }
    return c.redComponent > 0.99 && c.greenComponent < 0.01 && c.blueComponent < 0.01 && c.alphaComponent > 0.99
  }

  func getColor(x: Int, y: Int) -> CGColor? {
    return bitmap.colorAt(x: x, y: y)?.cgColor
  }
}

private extension CGPath {
  
  static func rect(x: CGFloat = 0,
                   y: CGFloat = 0,
                   width: CGFloat = 2,
                   height: CGFloat = 2) -> CGPath {
    
    let rect = CGRect(x: x, y: y, width: width, height: height)
    return CGPath(rect: rect, transform: nil)
  }
}

private extension CGColor {
  
  static var red: CGColor {
    //return CGColor(red: 1.0, green: 0, blue: 0, alpha: 1.0)
    return NSColor(deviceRed: 0.0, green: 0, blue: 1.0, alpha: 1.0).cgColor
  }
}

#endif
