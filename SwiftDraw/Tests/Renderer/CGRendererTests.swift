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

@testable import SwiftDraw
import SwiftDrawDOM

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

  func testRepeatGradientRepeats() throws {
    // red→blue every 10 units: pad would leave x ≥ 10 blue, repeat restarts red at x = 10 and 20
    func redness(_ spread: String, x: Int) throws -> CGFloat {
      let renderer = ImageRenderer(pixelsWide: 40, pixelsHigh: 4)
      let svg = try DOM.SVG.parse(xml: """
      <svg xmlns="http://www.w3.org/2000/svg" width="40" height="4">
        <defs><linearGradient id="g" gradientUnits="userSpaceOnUse" x1="0" x2="10" spreadMethod="\(spread)">
          <stop offset="0" stop-color="red"/><stop offset="1" stop-color="blue"/>
        </linearGradient></defs>
        <rect width="40" height="4" fill="url(#g)"/>
      </svg>
      """)
      let layer = LayerTree.Builder(svg: svg).makeLayer()
      let generator = LayerTree.CommandGenerator(provider: CGProvider(), size: LayerTree.Size(40, 4), options: .default)
      renderer.renderer.perform(generator.renderCommands(for: layer, colorConverter: .default))
      let color = try XCTUnwrap(renderer.getColor(x: x, y: 2)?.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil))
      let c = try XCTUnwrap(color.components)
      return c[0] - c[2]
    }
    XCTAssertGreaterThan(try redness("repeat", x: 1), 0.5)
    XCTAssertGreaterThan(try redness("repeat", x: 21), 0.5)
    XCTAssertLessThan(try redness("pad", x: 21), -0.5)
    // reflect: x = 11 mirrors x = 9 (blue)
    XCTAssertLessThan(try redness("reflect", x: 11), -0.5)
    XCTAssertGreaterThan(try redness("reflect", x: 19), 0.5)
  }

  func testRadialReflectGradientMirrors() throws {
    // red at the centre, blue at r = 10, mirrored back to red at r = 20 (pad stays blue)
    func redness(_ spread: String, x: Int) throws -> CGFloat {
      let renderer = ImageRenderer(pixelsWide: 40, pixelsHigh: 40)
      let svg = try DOM.SVG.parse(xml: """
      <svg xmlns="http://www.w3.org/2000/svg" width="40" height="40">
        <defs><radialGradient id="g" gradientUnits="userSpaceOnUse" cx="20" cy="20" r="10" spreadMethod="\(spread)">
          <stop offset="0" stop-color="red"/><stop offset="1" stop-color="blue"/>
        </radialGradient></defs>
        <rect width="40" height="40" fill="url(#g)"/>
      </svg>
      """)
      let layer = LayerTree.Builder(svg: svg).makeLayer()
      let generator = LayerTree.CommandGenerator(provider: CGProvider(), size: LayerTree.Size(40, 40), options: .default)
      renderer.renderer.perform(generator.renderCommands(for: layer, colorConverter: .default))
      let color = try XCTUnwrap(renderer.getColor(x: x, y: 20)?.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil))
      let c = try XCTUnwrap(color.components)
      return c[0] - c[2]
    }
    XCTAssertGreaterThan(try redness("reflect", x: 20), 0.5)
    XCTAssertLessThan(try redness("reflect", x: 30), -0.5)
    XCTAssertGreaterThan(try redness("reflect", x: 39), 0.5)
    XCTAssertLessThan(try redness("pad", x: 39), -0.5)
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
