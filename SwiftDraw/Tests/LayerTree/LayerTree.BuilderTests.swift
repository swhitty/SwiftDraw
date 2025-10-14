//
//  LayerTree.BuilderTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 21/11/18.
//  Copyright 2020 WhileLoop Pty Ltd. All rights reserved.
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
import XCTest
@testable import SwiftDraw

final class LayerTreeBuilderTests: XCTestCase {
  
  typealias Shape = LayerTree.Shape
  typealias Contents = LayerTree.Layer.Contents
  
  func testMakeViewBoxTransform() {
    var transform = LayerTree.Builder.makeTransform(viewBox: nil, width: 100, height: 200)
    XCTAssertEqual(transform, [])
    
    let viewbox = DOM.SVG.ViewBox(x: 0, y: 0, width: 200, height: 200)
    transform = LayerTree.Builder.makeTransform(viewBox: viewbox, width: 100, height: 100)
    XCTAssertEqual(transform, [.scale(sx: 0.5, sy: 0.5)])
    
    let viewbox1 = DOM.SVG.ViewBox(x: 10, y: -10, width: 100, height: 100)
    transform = LayerTree.Builder.makeTransform(viewBox: viewbox1, width: 100, height: 100)
    XCTAssertEqual(transform, [.translate(tx: -10, ty: 10)])
  }
  
  func testDOMMaskMakesLayer() {
    let circle = DOM.Circle(cx: 5, cy: 5, r: 5)
    let line = DOM.Line(x1: 0, y1: 0, x2: 10, y2: 0)
    let mask = DOM.Mask(id: "mask1", childElements: [circle, line])
    mask.attributes.fill = .color(.keyword(.white))

    let svg = DOM.SVG(width: 10, height: 10)
    svg.defs.masks.append(mask)

    let builder = LayerTree.Builder(svg: svg)
    
    let element = DOM.GraphicsElement()
    element.attributes.mask = URL(string: "#mask1")
    
    let layer = builder.createMaskLayer(for: element)
    XCTAssertEqual(layer?.contents.count, 2)
    XCTAssertEqual(layer?.contents[0].shape?.fill.fill, .color(.white))
  }
  
  func testDOMClipMakesShape() {
    let circle = DOM.Circle(cx: 5, cy: 5, r: 5)
    let svg = DOM.SVG(width: 10, height: 10)
    svg.defs.clipPaths.append(DOM.ClipPath(id: "clip1", childElements: [circle]))

    var attributes = DOM.PresentationAttributes()
    attributes.clipPath = URL(string: "#clip1")
    svg.styles = [DOM.StyleSheet(attributes: [.class("a"): attributes])]

    let builder = LayerTree.Builder(svg: svg)
    
    var element = DOM.GraphicsElement()
    element.attributes.clipPath = URL(string: "#clip1")
    
    XCTAssertEqual(
        builder.createClipShapes(for: element),
        [.ellipse(within: LayerTree.Rect(x: 0, y: 0, width: 10, height: 10))]
    )

    element = DOM.GraphicsElement()
    element.class = "a"
      XCTAssertEqual(
          builder.createClipShapes(for: element),
          [.ellipse(within: LayerTree.Rect(x: 0, y: 0, width: 10, height: 10))]
      )
  }

  func testDOMGroupMakesChildContents() {
    let builder = LayerTree.Builder(svg: DOM.SVG(width: 10, height: 10))
    
    let group = DOM.Group()
    group.childElements = [DOM.Circle(cx: 0, cy: 0, r: 5),
                           DOM.Line(x1: 0, y1: 0, x2: 10, y2: 10)]
    
    let layer = builder.makeLayer(from: group, inheriting: .init())
    XCTAssertEqual(layer.contents.count, 2)
  }
  
  func testDOMPatternMakesPattern() {
    let builder = LayerTree.Builder(svg: DOM.SVG(width: 10, height: 10))
    
    var element = DOM.Pattern(id: "hi", width: 5, height: 5)
    element.childElements = [DOM.Circle(cx: 10, cy: 10, r: 5)]
    
    let pattern = builder.makePattern(for: element)
    
    let ellipse = Shape.ellipse(within: LayerTree.Rect(x: 5, y: 5, width: 10, height: 10))
    let expected = LayerTree.Layer()
    expected.contents = [Contents.shape(ellipse, .default, .default)]
    XCTAssertEqual(pattern.contents, [.layer(expected)])
  }
  
  func testStrokeAttributes() {
    var state = LayerTree.Builder.State()
    state.stroke = .color(.rgbf(1.0, 0.0, 0.0, 1.0))
    state.strokeOpacity = 0.5
    state.strokeWidth = 5.0
    state.strokeLineCap = .square
    state.strokeLineJoin = .round
    state.strokeLineMiterLimit = 10.0
    
    let att = LayerTree.Builder.makeStrokeAttributes(with: state)
    XCTAssertEqual(att.color, .color(.srgb(r: 1.0, g: 0, b: 0, a: 0.5)))
    XCTAssertEqual(att.width, 5.0)
    XCTAssertEqual(att.cap, .square)
    XCTAssertEqual(att.join, .round)
    XCTAssertEqual(att.miterLimit, 10.0)
    
    state.strokeWidth = 0
    let att2 = LayerTree.Builder.makeStrokeAttributes(with: state)
    XCTAssertEqual(att2.color, .none)
  }

  func testDeepNestedSVGBuildLayers() async {
    let circle = DOM.Circle(cx: 50, cy: 50, r: 10)
    let svg = DOM.SVG(width: 50, height: 50)
    svg.childElements.append(DOM.Group.make(child: circle, nestedLevels: 500))

    let _ = LayerTree.Builder(svg: svg).makeLayer()
  }
}

private extension LayerTree.StrokeAttributes {
  
  static var `default`: LayerTree.StrokeAttributes {
    return LayerTree.Builder.makeStrokeAttributes(with: LayerTree.Builder.State())
  }
}

private extension LayerTree.FillAttributes {
  
  static var `default`: LayerTree.FillAttributes {
    let builder = LayerTree.Builder(svg: DOM.SVG(width: 10, height: 10))
    return builder.makeFillAttributes(with: LayerTree.Builder.State())
  }
}

extension LayerTree.Builder {

    static func makeStrokeAttributes(with state: State) -> LayerTree.StrokeAttributes {
        let builder = LayerTree.Builder(svg: DOM.SVG(width: 10, height: 10))
        return builder.makeStrokeAttributes(with: state)
    }

    func createClipShapes(for element: DOM.GraphicsElement) -> [LayerTree.Shape] {
        makeClipShapes(for: element).map(\.shape)
    }

    static func makeTransform(
        viewBox: DOM.SVG.ViewBox?,
        width: DOM.Length,
        height: DOM.Length
    ) -> [LayerTree.Transform] {
        makeTransform(
            x: nil,
            y: nil,
            viewBox: viewBox,
            width: width,
            height: height
        )
    }
}

extension DOM.Group {

    static func make(child: DOM.GraphicsElement, nestedLevels: Int) -> DOM.Group {
        var group = DOM.Group()
        group.childElements.append(child)

        for _ in 0..<nestedLevels {
            let outerGroup = DOM.Group()
            outerGroup.childElements.append(group)
            group = outerGroup
        }

        return group
    }
}

private extension LayerTree.Layer.Contents {
    var shape: (shape: LayerTree.Shape, stroke: LayerTree.StrokeAttributes, fill: LayerTree.FillAttributes)? {
        guard case let .shape(shape, stroke, fill) = self else { return nil }
        return (shape, stroke, fill)
    }
}
