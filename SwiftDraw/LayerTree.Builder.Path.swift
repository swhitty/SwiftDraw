//
//  LayerTree.Builder.Path.swift
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

import Foundation

//converts DOM.Path -> LayerTree.Path

extension LayerTree.Builder {
  
  typealias Path = LayerTree.Path
  typealias Point = LayerTree.Point
  
  static func createPath(from element: DOM.Path) throws -> LayerTree.Path {
    let path = Path()
    
    for s in element.segments {
      let segments = try makeSegments(from: s,
                                      last: path.location ?? Point.zero,
                                      previous: path.lastControl)
      path.segments.append(contentsOf: segments)
    }
    
    return path
  }
  
  static func makeSegment(from segment: DOM.Path.Segment, last point: Point, previous control: Point?) -> Path.Segment? {
    if let s = createMove(from: segment, last: point) {
      return s
    } else if let s = createLine(from: segment, last: point) {
      return s
    } else if let s = createHorizontal(from: segment, last: point) {
      return s
    } else if let s = createVertical(from: segment, last: point) {
      return s
    } else if let s = createCubic(from: segment, last: point) {
      return s
    } else if let s = createCubicSmooth(from: segment, last: point, previous: control ?? point) {
      return s
    } else if let s = createQuadratic(from: segment, last: point) {
      return s
    } else if let s = createQuadraticSmooth(from: segment, last: point, previous: control ?? point) {
      return s
    } else if let s = createClose(from: segment) {
      return s
    }
    
    return nil
  }
  
  static func makeSegments(from segment: DOM.Path.Segment, last point: Point, previous control: Point?) throws -> [Path.Segment] {
    if let s = createArc(from: segment, last: point) {
      return s
    } else if let s = makeSegment(from: segment, last: point, previous: control) {
      return [s]
    }
    
    throw LayerTree.Error.unsupported(segment)
  }
  
  static func createMove(from segment: DOM.Path.Segment, last point: Point) -> Path.Segment? {
    guard case .move(to: let m) = segment else { return nil }
    
    let p = Point(m.x, m.y)
    
    switch m.space {
    case .relative: return .move(to: p.absolute(from: point))
    case .absolute: return .move(to: p)
    }
  }
  
  static func createLine(from segment: DOM.Path.Segment, last point: Point) -> Path.Segment? {
    guard case let .line(x, y, space) = segment else { return nil }
    
    let p = Point(x, y)
    
    switch space {
    case .relative: return .line(to: p.absolute(from: point))
    case .absolute: return .line(to: p)
    }
  }
  
  static func createHorizontal(from segment: DOM.Path.Segment, last point: Point) -> Path.Segment? {
    guard case let .horizontal(x, space) = segment else { return nil }
    
    switch space {
    case .relative: return .line(to: Point(x + point.x , point.y))
    case .absolute: return .line(to: Point(x, point.y))
    }
  }
  
  static func createVertical(from segment: DOM.Path.Segment, last point: Point) -> Path.Segment? {
    guard case let .vertical(y, space) = segment else { return nil }
    
    switch space {
    case .relative: return .line(to: Point(point.x , y + point.y))
    case .absolute: return .line(to: Point(point.x, y))
    }
  }
  
  static func createCubic(from segment: DOM.Path.Segment, last point: Point) -> Path.Segment? {
    guard case let .cubic(x1, y1, x2, y2, x, y, space) = segment else { return nil }
    
    let p = Point(x, y)
    let cp1 = Point(x1, y1)
    let cp2 = Point(x2, y2)
    
    switch space {
    case .relative: return .cubic(to: p.absolute(from: point),
                                  control1: cp1.absolute(from: point),
                                  control2: cp2.absolute(from: point))
    case .absolute: return .cubic(to: p, control1: cp1, control2: cp2)
    }
  }
  
  static func createCubicSmooth(from segment: DOM.Path.Segment, last point: Point, previous control: Point) -> Path.Segment? {
    guard case let .cubicSmooth(x2, y2, x, y, space) = segment else { return nil }
    
    let delta = Point(point.x - control.x,
                      point.y - control.y)
    
    let p = Point(x, y)
    let cp1 = Point(point.x + delta.x,
                    point.y + delta.y)
    let cp2 = Point(x2, y2)
    
    switch space {
    case .relative: return .cubic(to: p.absolute(from: point),
                                  control1: cp1,
                                  control2: cp2.absolute(from: point))
    case .absolute: return .cubic(to: p, control1: cp1, control2: cp2)
    }
  }
  
  static func createQuadratic(from segment: DOM.Path.Segment, last point: Point) -> Path.Segment? {
    guard case let .quadratic(x1, y1, x, y, space) = segment else { return nil }
    
    var p = Point(x, y)
    var cp1 = Point(x1, y1)
    
    if space == .relative {
      p = p.absolute(from: point)
      cp1 = cp1.absolute(from: point)
    }
    
    return createCubic(from: point, to: p, quadratic: cp1)
  }
  
  static func createCubic(from origin: Point, to final: Point, quadratic controlPoint: Point) -> Path.Segment {
    //Approximate a quadratic curve using cubic curve.
    //Converting the quadratic control point into 2 cubic control points
    
    let ratio = Float(2.0/3.0)
    
    let cp1 = Point(origin.x + (controlPoint.x - origin.x) * ratio,
                    origin.y + (controlPoint.y - origin.y) * ratio)
    
    let cpX = (final.x - origin.x)*Float(1.0/3.0)
    
    let cp2 = Point(cp1.x + cpX,
                    cp1.y)
    
    return .cubic(to: final, control1: cp1, control2: cp2)
  }
  
  static func createQuadraticSmooth(from segment: DOM.Path.Segment, last point: Point, previous control: Point) -> Path.Segment? {
    guard case let .quadraticSmooth(x, y, space) = segment else { return nil }
    
    let delta = Point(point.x - control.x,
                      point.y - control.y)
    
    let cp1 = Point(point.x + delta.x,
                    point.y + delta.y)

    let final = space == .absolute ? Point(x, y) : Point(x, y).absolute(from: point)
    let cpX = (final.x - point.x)*Float(1.0/3.0)
    let cp2 = Point(cp1.x + cpX,
                    cp1.y)
    
    return .cubic(to: final, control1: cp1, control2: cp2)
  }
  
  static func createArc(from segment: DOM.Path.Segment, last point: Point) -> [Path.Segment]? {
    guard case let .arc(rx, ry, rotate, large, sweep, x, y, space) = segment else { return nil }
    
    let p: Point
    
    switch space {
    case .relative: p = Point(x, y).absolute(from: point)
    case .absolute: p = Point(x, y)
    }
    
    let curves = makeCubic(from: point, to: p,
                           large: large, sweep: sweep,
                           rx: LayerTree.Float(rx),
                           ry: LayerTree.Float(ry),
                           rotation: LayerTree.Float(rotate))
    
    return curves.map { .cubic(to: $0.p, control1: $0.cp1, control2: $0.cp2) }
  }

  static func createClose(from segment: DOM.Path.Segment) -> Path.Segment? {
    guard case .close = segment else { return nil }
    return .close
  }
  
}

extension LayerTree.Point {
  func absolute(from base: LayerTree.Point) -> LayerTree.Point {
    return LayerTree.Point(base.x + x, base.y + y)
  }
}
