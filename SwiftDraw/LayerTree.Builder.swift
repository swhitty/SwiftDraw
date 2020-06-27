//
//  LayerTree.Builder.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 4/6/17.
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

// Convert a DOM.SVG into a layer tree

extension LayerTree {

  struct Builder {

    let svg: DOM.SVG

    init(svg: DOM.SVG) {
      self.svg = svg
    }

    func makeLayer() -> Layer {
      let l = makeLayer(from: svg, inheriting: State())
      l.transform = Builder.makeTransform(for: svg.viewBox,
                                          width: svg.width,
                                          height: svg.height)
      return l
    }

    static func makeTransform(for viewBox: DOM.SVG.ViewBox?, width: DOM.Length, height: DOM.Length) -> [LayerTree.Transform] {
      guard let viewBox = viewBox else {
        return []
      }

      let sx = LayerTree.Float(width) / viewBox.width
      let sy = LayerTree.Float(height) / viewBox.height
      let scale = LayerTree.Transform.scale(sx: sx, sy: sy)
      let translate = LayerTree.Transform.translate(tx: -viewBox.x, ty: -viewBox.y)

      var transform = [LayerTree.Transform]()

      if scale != .scale(sx: 1, sy: 1) {
        transform.append(scale)
      }

      if translate != .translate(tx: 0, ty: 0) {
        transform.append(translate)
      }

      return transform
    }

    func makeLayer(from element: DOM.GraphicsElement, inheriting previousState: State) -> Layer {
      let state = Builder.createState(for: element, inheriting: previousState)
      let l = Layer()

      guard state.display == .inline else { return l }

      l.transform = Builder.createTransforms(from: element.transform ?? [])
      l.clip = createClipShapes(for: element)
      l.mask = createMaskLayer(for: element)
      l.opacity = state.opacity
      l.contents = makeAllContents(from: element, with: state)

      //            // clips the mask to the content
      //            l.mask?.clip = l.contents.compactMap { (contents: Layer.Contents) -> LayerTree.Shape? in
      //                switch(contents) {
      //                case .shape(let s, _, _): return s
      //                default: return nil
      //                }
      //            }

      return l
    }

    func makeAllContents(from element: DOM.GraphicsElement, with state: State) -> [Layer.Contents] {
      var all = [Layer.Contents]()
      if let contents = makeContents(from: element, with: state) {
        all.append(contents)
      }
      else if let container = element as? ContainerElement {
        container.childElements.forEach{
          let contents = Layer.Contents.layer(makeLayer(from: $0, inheriting: state))
          all.append(contents)
        }
      }
      return all
    }

    func makeContents(from element: DOM.GraphicsElement, with state: State) -> Layer.Contents? {
      if let shape = Builder.makeShape(from: element) {
        return makeShapeContents(from: shape, with: state)
      } else if let text = element as? DOM.Text {
        return Builder.makeTextContents(from: text, with: state)
      } else if let image = element as? DOM.Image {
        return try? Builder.makeImageContents(from: image)
      } else if let use = element as? DOM.Use {
        return try? makeUseLayerContents(from: use, with: state)
      } else if let sw = element as? DOM.Switch,
        let e = sw.childElements.first {
        //TODO: select first element that creates non empty Layer
        return .layer(makeLayer(from: e, inheriting: state))
      }

      return nil
    }

    func createClipShapes(for element: DOM.GraphicsElement) -> [Shape] {
      guard let clipId = element.clipPath?.fragment,
        let clip = svg.defs.clipPaths.first(where: { $0.id == clipId }) else { return [] }

      return clip.childElements.compactMap{ Builder.makeShape(from: $0) }
    }

    func createMaskLayer(for element: DOM.GraphicsElement) -> Layer? {
      guard let maskId = element.mask?.fragment,
        let mask = svg.defs.masks.first(where: { $0.id == maskId }) else { return nil }

      let l = Layer()

      mask.childElements.forEach {
        let contents = Layer.Contents.layer(makeLayer(from: $0, inheriting: State()))
        l.appendContents(contents)
      }

      return l
    }
  }
}


extension LayerTree.Builder {

  static func makeStrokeAttributes(with state: State) -> LayerTree.StrokeAttributes {
    let stroke: LayerTree.Color

    if state.strokeWidth > 0.0 {
      stroke = LayerTree.Color.create(from: state.stroke).withAlpha(state.strokeOpacity).maybeNone()
    } else {
      stroke = .none
    }

    return LayerTree.StrokeAttributes(color: stroke,
                                      width: state.strokeWidth,
                                      cap: state.strokeLineCap,
                                      join: state.strokeLineJoin,
                                      miterLimit: state.strokeLineMiterLimit)
  }

  func makeFillAttributes(with state: State) -> LayerTree.FillAttributes {
    let fill = LayerTree.Color.create(from: state.fill.makeColor()).withAlpha(state.fillOpacity).maybeNone()

    if case .url(let patternId) = state.fill,
      let element = svg.defs.patterns.first(where: { $0.id == patternId.fragment }) {
      let pattern = makePattern(for: element)
      return LayerTree.FillAttributes(pattern: pattern, rule: state.fillRule, opacity: state.fillOpacity)
    } else if case .url(let gradientId) = state.fill,
      let element = svg.defs.linearGradients.first(where: { $0.id == gradientId.fragment }) {
      let gradient = makeGradient(for: element)!
      return LayerTree.FillAttributes(gradient: gradient, rule: state.fillRule, opacity: state.fillOpacity)
    } else {
      return LayerTree.FillAttributes(color: fill, rule: state.fillRule)
    }
  }

  static func makeTextAttributes(with state: State) -> LayerTree.TextAttributes {
    return .normal
  }

  func makePattern(for element: DOM.Pattern) -> LayerTree.Pattern {
    let frame = LayerTree.Rect(x: 0, y: 0, width: element.width, height: element.height)
    let pattern = LayerTree.Pattern(frame: frame)
    pattern.contents = element.childElements.compactMap { .layer(makeLayer(from: $0, inheriting: .init())) }
    return pattern
  }

  func makeGradient(for element: DOM.LinearGradient) -> LayerTree.Gradient? {
    guard
      let x1 = element.x1,
      let y1 = element.y1,
      let x2 = element.x2,
      let y2 = element.y2 else {
        return nil
    }

    let gradient = LayerTree.Gradient(start: Point(x1, y1), end: Point(x2, y2))
    if let id = element.href?.fragment,
       let reference = svg.defs.linearGradients.first(where: { $0.id == id }) {
      gradient.stops = makeGradientStops(for: reference)
    } else {
      gradient.stops = makeGradientStops(for: element)
    }

    return gradient
  }

  func makeGradientStops(for element: DOM.LinearGradient) -> [LayerTree.Gradient.Stop] {
    return element.stops.map {
      LayerTree.Gradient.Stop(offset: $0.offset,
                              color: LayerTree.Color($0.color),
                              opacity: $0.opacity)
    }
  }

  //current state of the render tree, updated as builder traverses child nodes
  struct State {
    var opacity: DOM.Float
    var display: DOM.DisplayMode

    var stroke: DOM.Color
    var strokeWidth: DOM.Float
    var strokeOpacity: DOM.Float
    var strokeLineCap: DOM.LineCap
    var strokeLineJoin: DOM.LineJoin
    var strokeLineMiterLimit: DOM.Float
    var strokeDashArray: [DOM.Float]

    var fill: DOM.Fill
    var fillOpacity: DOM.Float
    var fillRule: DOM.FillRule

    init() {
      //default root SVG element state
      opacity = 1.0
      display = .inline

      stroke = .none
      strokeWidth = 1.0
      strokeOpacity = 1.0
      strokeLineCap = .butt
      strokeLineJoin = .miter
      strokeLineMiterLimit = 4.0
      strokeDashArray = []

      fill = .color(.keyword(.black))
      fillOpacity = 1.0
      fillRule = .evenodd
    }
  }

  static func createState(for attributes: PresentationAttributes, inheriting existing: State) -> State {
    var state = State()

    state.opacity = attributes.opacity ?? 1.0
    state.display = attributes.display ?? existing.display

    state.stroke = attributes.stroke ?? existing.stroke
    state.strokeWidth = attributes.strokeWidth ?? existing.strokeWidth
    state.strokeOpacity = attributes.strokeOpacity ?? existing.strokeOpacity
    state.strokeLineCap = attributes.strokeLineCap ?? existing.strokeLineCap
    state.strokeLineJoin = attributes.strokeLineJoin ?? existing.strokeLineJoin
    state.strokeDashArray = attributes.strokeDashArray ?? existing.strokeDashArray

    state.fill = attributes.fill ?? existing.fill
    state.fillOpacity = attributes.fillOpacity ?? existing.fillOpacity
    state.fillRule = attributes.fillRule ?? existing.fillRule

    return state
  }
}

extension LayerTree.Builder {
  static func createTransform(for dom: DOM.Transform) -> [LayerTree.Transform] {
    switch dom {
    case let .matrix(a, b, c, d, e, f):
      let matrix = LayerTree.Transform.Matrix(a: Float(a),
                                              b: Float(b),
                                              c: Float(c),
                                              d: Float(d),
                                              tx: Float(e),
                                              ty: Float(f))
      return [.matrix(matrix)]

    case let .translate(tx, ty):
      return [.translate(tx: Float(tx), ty: Float(ty))]

    case let .scale(sx, sy):
      return [.scale(sx: Float(sx), sy: Float(sy))]

    case .rotate(let angle):
      let radians = Float(angle)*Float.pi/180.0
      return [.rotate(radians: radians)]

    case let .rotatePoint(angle, cx, cy):
      let radians = Float(angle)*Float.pi/180.0
      let t1 = LayerTree.Transform.translate(tx: cx, ty: cy)
      let t2 = LayerTree.Transform.rotate(radians: radians)
      let t3 = LayerTree.Transform.translate(tx: -cx, ty: -cy)
      return [t1, t2, t3]

    case let .skewX(angle):
      let radians = Float(angle)*Float.pi/180.0
      return [.skewX(angle: radians)]
    case let .skewY(angle):
      let radians = Float(angle)*Float.pi/180.0
      return [.skewY(angle: radians)]
    }
  }

  static func createTransforms(from transforms: [DOM.Transform]) -> [LayerTree.Transform] {
    return transforms.flatMap{ createTransform(for: $0) }
  }
}



private extension DOM.Fill {

  func makeColor() -> DOM.Color {
    switch self {
    case .color(let c):
      return c
    case .url:
      return .keyword(.black)
    }
  }
}
