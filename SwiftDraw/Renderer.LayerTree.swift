//
//  Renderer.LayerTree.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 14/6/17.
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
import Foundation

struct LayerTreeTypes: RendererTypes {
  typealias Float = LayerTree.Float
  typealias Point = LayerTree.Point
  typealias Size = LayerTree.Size
  typealias Rect = LayerTree.Rect
  typealias Color = LayerTree.Color
  typealias Gradient = LayerTree.Gradient
  typealias Mask = [AnyHashable]
  typealias Path = [LayerTree.Shape]
  typealias Pattern = LayerTree.Pattern
  typealias Transform = LayerTree.Transform
  typealias BlendMode = LayerTree.BlendMode
  typealias FillRule = LayerTree.FillRule
  typealias LineCap = LayerTree.LineCap
  typealias LineJoin = LayerTree.LineJoin
  typealias Image = LayerTree.Image
}

struct LayerTreeProvider: RendererTypeProvider {
  
  typealias Types = LayerTreeTypes
  
  func createFloat(from float: LayerTree.Float) -> LayerTree.Float {
    return float
  }
  
  func createPoint(from point: LayerTree.Point) -> LayerTree.Point {
    return point
  }
  
  func createSize(from size: LayerTree.Size) -> LayerTree.Size {
    return size
  }
  
  func createRect(from rect: LayerTree.Rect) -> LayerTree.Rect {
    return rect
  }
  
  func createColor(from color: LayerTree.Color) -> LayerTree.Color {
    return color
  }
  
  func createGradient(from gradient: LayerTree.Gradient) -> LayerTree.Gradient {
    return gradient
  }
  
  func createBlendMode(from mode: LayerTree.BlendMode) -> LayerTree.BlendMode {
    return mode
  }
  
  func createTransform(from transform: LayerTree.Transform.Matrix) -> LayerTree.Transform {
    return .matrix(transform)
  }
  
  func createPath(from shape: LayerTree.Shape) -> [LayerTree.Shape] {
    return [shape]
  }
  
  func createPattern(from pattern: LayerTree.Pattern, contents: [RendererCommand<Types>]) -> LayerTreeTypes.Pattern {
    return pattern
  }
  
  func createPath(from subPaths: [[LayerTree.Shape]]) -> [LayerTree.Shape] {
    return subPaths.flatMap { $0 }
  }
  
  func createPath(from text: String, at origin: LayerTree.Point, with attributes: LayerTree.TextAttributes) -> [LayerTree.Shape]? {
    return nil
  }
  
  func createFillRule(from rule: LayerTree.FillRule) -> LayerTree.FillRule {
    return rule
  }
  
  func createLineCap(from cap: LayerTree.LineCap) -> LayerTree.LineCap {
    return cap
  }
  
  func createLineJoin(from join: LayerTree.LineJoin) -> LayerTree.LineJoin {
    return join
  }
  
  func createImage(from image: LayerTree.Image) -> LayerTree.Image? {
    return image
  }

  func createSize(from image: LayerTree.Image) -> LayerTree.Size {
      LayerTree.Size(
        image.width ?? 0,
        image.height ?? 0
      )
  }

  func getBounds(from shape: LayerTree.Shape) -> LayerTree.Rect {
    return LayerTree.Rect(x: 0, y: 0, width: 0, height: 0)
  }
}
