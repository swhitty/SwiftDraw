//
//  Renderer.Types.swift
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

struct CGTextTypes: RendererTypes {
  typealias Float = LayerTree.Float
  typealias Point = String
  typealias Size = String
  typealias Rect = String
  typealias Color = String
  typealias Gradient = LayerTree.Gradient
  typealias Mask = [Any]
  typealias Path = [LayerTree.Shape]
  typealias Pattern = LayerTree.Pattern
  typealias Transform = LayerTree.Transform
  typealias BlendMode = String
  typealias FillRule = String
  typealias LineCap = String
  typealias LineJoin = String
  typealias Image = LayerTree.Image
}

struct CGTextProvider: RendererTypeProvider {
  typealias Types = CGTextTypes
  
  var supportsTransparencyLayers: Bool = true
  
  func createFloat(from float: LayerTree.Float) -> LayerTree.Float {
    return float
  }
  
  func createPoint(from point: LayerTree.Point) -> String {
    return "CGPoint(x: \(point.x), y: \(point.y))"
  }
  
  func createSize(from size: LayerTree.Size) -> String {
    return "CGSize(width: \(size.width), height: \(size.height))"
  }
  
  func createRect(from rect: LayerTree.Rect) -> String {
    return "CGRect(x: \(rect.x), y: x: \(rect.y), width: \(rect.width), height: \(rect.height))"
  }

  func createColor(from color: LayerTree.Color) -> String {
    switch color {
    case .none:
      return "CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0, 0, 0, 0])!"
    case let .rgba(r, g, b, a):
      return "CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [\(r), \(g), \(b), \(a)])!"
    case .gray(white: let w, a: let a):
      return "CGColor(colorSpace: CGColorSpaceCreateExtendedGray(), components: [\(w), \(a)])!"
    }
  }

  func createGradient(from gradient: LayerTree.Gradient) -> LayerTree.Gradient {
    return gradient
  }
  
  func createMask(from contents: [RendererCommand<CGTextTypes>], size: LayerTree.Size) -> [Any] {
    return []
  }
  
  func createBlendMode(from mode: LayerTree.BlendMode) -> String {
    switch mode {
    case .normal:
      return ".normal"
    case .copy:
      return ".copy"
    case .sourceIn:
      return ".sourceIn"
    case .destinationIn:
      return ".destinationIn"
    }
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
  
  func createFillRule(from rule: LayerTree.FillRule) -> String {
    switch rule {
    case .nonzero:
      return ".winding"
    case .evenodd:
      return ".evenodd"
    }
  }

  func createLineCap(from cap: LayerTree.LineCap) -> String {
    switch cap {
    case .butt:
      return ".butt"
    case .round:
      return ".round"
    case .square:
      return ".square"
    }
  }

  func createLineJoin(from join: LayerTree.LineJoin) -> String {
    switch join {
    case .bevel:
      return ".bevel"
    case .round:
      return ".round"
    case .miter:
      return ".miter"
    }
  }
  
  func createImage(from image: LayerTree.Image) -> LayerTree.Image? {
    return image
  }
  
  func getBounds(from path: Types.Path) -> LayerTree.Rect {
    return LayerTree.Rect(x: 0, y: 0, width: 0, height: 0)
  }
}

final class CGTextRenderer: Renderer {
  typealias Types = CGTextTypes
  
  private var lines = [String]()

  func pushState() {
    lines.append("ctx.saveGState()")
  }

  func popState() {
    lines.append("ctx.restoreGState()")
  }
  
  func pushTransparencyLayer() {
    lines.append("ctx.beginTransparencyLayer(auxiliaryInfo: nil)")
  }
  
  func popTransparencyLayer() {
    lines.append("ctx.endTransparencyLayer()")
  }
  
  func concatenate(transform: LayerTree.Transform) {
    lines.append("ctx.concatenate(transform)")
  }
  
  func translate(tx: LayerTree.Float, ty: LayerTree.Float) {
    lines.append("ctx.translateBy(x: \(tx), y: \(ty))")
  }
  
  func rotate(angle: LayerTree.Float) {
    lines.append("ctx.rotate(by: \(angle))")
  }
  
  func scale(sx: LayerTree.Float, sy: LayerTree.Float) {
    lines.append("ctx.scaleBy(x: \(sx), y: \(sy)")
  }
  
  func setFill(color: String) {
    lines.append("ctx.setFillColor(\(color))")
  }
  
  func setFill(pattern: LayerTree.Pattern) {
    lines.append("let patternSpace = CGColorSpace(patternBaseSpace: nil)!")
    lines.append("ctx.setFillColorSpace(patternSpace)")
    lines.append("var alpha : CGFloat = 1.0")
    lines.append("ctx.setFillPattern(pattern, colorComponents: &alpha)")
  }
  
  func setStroke(color: String) {
    lines.append("ctx.setStrokeColor(\(color)")
  }
  
  func setLine(width: LayerTree.Float) {
    lines.append("ctx.setLineWidth(\(width))")
  }
  
  func setLine(cap: String) {
    lines.append("ctx.setLineCap(\(cap))")
  }
  
  func setLine(join: String) {
    lines.append("ctx.setLineJoin(\(join))")
  }
  
  func setLine(miterLimit: LayerTree.Float) {
    lines.append("ctx.setMiterLimit(\(miterLimit))")
  }
  
  func setClip(path: [LayerTree.Shape]) {
    lines.append("ctx.addPath(\(path))")
    lines.append("ctx.clip()")
  }
  
  func setClip(mask: [Any], frame: String) {
    lines.append("ctx.clip(to: \(frame), mask: \(mask))")
  }
  
  func setAlpha(_ alpha: LayerTree.Float) {
    lines.append("ctx.setAlpha(\(alpha))")
  }
  
  func setBlend(mode: String) {
    lines.append("ctx.setBlendMode(\(mode))")
  }
  
  func stroke(path: [LayerTree.Shape]) {
    lines.append("ctx.addPath(\(path))")
    lines.append("ctx.strokePath()")
  }
  
  func fill(path: [LayerTree.Shape], rule: String) {
    lines.append("ctx.addPath(\(path))")
    lines.append("ctx.fillPath(using: \(rule))")
  }
  
  func draw(image: LayerTree.Image) {
    lines.append("ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height)")
  }
  
  func draw(gradient: LayerTree.Gradient, from start: String, to end: String) {
    lines.append("""
    ctx.drawLinearGradient(gradient,
                           start: \(start),
                           end: \(end),
                           options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
    """)
  }
  
  func makeText(spaces: Int = 2) -> String {
    let indent = String(repeating: " ", count: spaces)
    var lines = self.lines.map { "\(indent)\($0)" }
    
    lines.insert("func drawImage(in ctx: CGContext) {", at: 0)
    lines.append("}")
    return lines.joined(separator: "\n")
  }
}
