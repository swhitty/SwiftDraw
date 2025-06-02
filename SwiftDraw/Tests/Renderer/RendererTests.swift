//
//  CGRenderer.PathTests.swift
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

final class RendererTests: XCTestCase {
  
  func testPerformCommands() {
    let renderer = MockRenderer()
    renderer.perform([
      .pushState,
      .popState,
      .pushTransparencyLayer,
      .popTransparencyLayer,
      .concatenate(transform: .identity),
      .translate(tx: 10, ty: 20),
      .scale(sx: 1, sy: 2),
      .rotate(angle: 10),
      .setFill(color: .none),
      .setFillPattern(.mock),
      .setStroke(color: .none),
      .setLine(width: 10),
      .setLineCap(.butt),
      .setLineJoin(.bevel),
      .setLineMiter(limit: 10),
      .setClip(path: .mock, rule: .nonzero),
      .setClipMask([], frame: .zero),
      .fill(.mock, rule: .nonzero),
      .stroke(.mock),
      .clipStrokeOutline(.mock),
      .setAlpha(0.5),
      .setBlend(mode: .sourceIn),
      .draw(image: .mock, in: .zero),
      .drawLinearGradient(.mock, from: .zero, to: .zero),
      .drawRadialGradient(.mock, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 0)
    ])
    
    XCTAssertEqual(renderer.operations, [
      "pushState",
      "popState",
      "pushTransparencyLayer",
      "popTransparencyLayer",
      "concatenateTransform",
      "translate",
      "scale",
      "rotate",
      "setFillColor",
      "setFillPattern",
      "setStrokeColor",
      "setLineWidth",
      "setLineCap",
      "setLineJoin",
      "setLineMiterLimit",
      "setClip",
      "setClipMask",
      "fillPath",
      "strokePath",
      "clipStrokeOutline",
      "setAlpha",
      "setBlendMode",
      "drawImage",
      "drawLinearGradient",
      "drawRadialGradient"
    ])
  }
}

private extension LayerTree.Shape {
  
  static var mock: LayerTree.Shape {
    return .line(between: [])
  }
}

private extension Array where Element == LayerTree.Shape {
  
  static var mock: [LayerTree.Shape] {
    return [.mock]
  }
}

private extension LayerTree.Image {
  
  static var mock: LayerTree.Image {
    return .png(data: Data())
  }
}

private extension LayerTree.Pattern {
  
  static var mock: LayerTree.Pattern {
    return LayerTree.Pattern(frame: .zero)
  }
}

private extension LayerTree.Gradient {
  
  static var mock: LayerTree.Gradient {
    return LayerTree.Gradient(stops: [])
  }
}
