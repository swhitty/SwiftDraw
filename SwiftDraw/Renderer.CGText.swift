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
  typealias Gradient = String
  typealias Mask = [Any]
  typealias Path = String
  typealias Pattern = LayerTree.Pattern
  typealias Transform = String
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
    return "CGRect(x: \(rect.x), y: \(rect.y), width: \(rect.width), height: \(rect.height))"
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

  func createGradient(from gradient: LayerTree.Gradient) -> String {
    let colors = gradient.stops
      .map { "  \(createColor(from: $0.color))" }
      .joined(separator: ",\n")

    let points = gradient.stops
      .map { String($0.offset) }
      .joined(separator: ", ")

    return """
    let colors1 = [
    \(colors)
    ] as CFArray
    var locations1: [CGFloat] = [\(points)]
    let gradient1 = CGGradient(
      colorsSpace: CGColorSpaceCreateDeviceRGB(),
      colors: colors1,
      locations: &locations1
    )!
    """
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

  func createTransform(from transform: LayerTree.Transform.Matrix) -> String {
    """
    let transform1 = CGAffineTransform(
      a: \(createFloat(from: transform.a)),
      b: \(createFloat(from: transform.b)),
      c: \(createFloat(from: transform.c)),
      d: \(createFloat(from: transform.d)),
      tx: \(createFloat(from: transform.tx)),
      ty: \(createFloat(from: transform.ty))
    )
    """
  }

  func createPath(from shape: LayerTree.Shape) -> String {
    switch shape {
    case .line(let points):
      return createLinePath(between: points)
  
    case .rect(let frame, let radii):
      return createRectPath(frame: frame, radii: radii)
      
    case .ellipse(let frame):
      return createEllipsePath(frame: frame)

    case .path(let path):
      return createPath(from: path)
      
    case .polygon(let points):
      return createPolygonPath(between: points)
    }
  }

  func createLinePath(between points: [LayerTree.Point]) -> String {
    """
    let path1 = CGMutablePath()
    path1.addLines(between: [
    \(points, indent: 2)
    ])
    """
  }
  
  func createRectPath(frame: LayerTree.Rect, radii: LayerTree.Size) -> String {
    """
    let path1 = CGPath(
      roundedRect: \(createRect(from: frame)),
      cornerWidth: \(createFloat(from: radii.width)),
      cornerHeight: \(createFloat(from: radii.height)),
      transform: nil
    )
    """
  }

  func createPolygonPath(between points: [LayerTree.Point]) -> String {
    var lines: [String] = ["let path1 = CGMutablePath()"]
    lines.append("path1.addLines(between: [")
    for p in points {
      lines.append("  \(createPoint(from: p)),")
    }
    lines.append("])")
    lines.append("path1.closeSubpath()")
    return lines.joined(separator: "\n")
  }

  func createEllipsePath(frame: LayerTree.Rect) -> String {
    """
    let path1 = CGPath(
      ellipseIn: \(createRect(from: frame)),
      transform: nil
    )
    """
  }

  func createPath(from path: LayerTree.Path) -> String {
    var lines: [String] = ["let path1 = CGMutablePath()"]
    for s in path.segments {
      switch s {
      case .move(let p):
        lines.append("path1.move(to: \(createPoint(from: p)))")
      case .line(let p):
        lines.append("path1.addLine(to: \(createPoint(from: p)))")
      case .cubic(let p, let cp1, let cp2):
        lines.append("""
        path1.addCurve(to: \(createPoint(from: p)),
                       control1: \(createPoint(from: cp1)),
                       control2: \(createPoint(from: cp2)))
        """)
      case .close:
        lines.append("path1.closeSubpath()")
      }
    }
    return lines.joined(separator: "\n")
  }

  func createPattern(from pattern: LayerTree.Pattern, contents: [RendererCommand<Types>]) -> LayerTreeTypes.Pattern {
    return pattern
  }
  
  func createPath(from subPaths: [String]) -> String {
    return "subpaths"
  }
  
  func createPath(from text: String, at origin: LayerTree.Point, with attributes: LayerTree.TextAttributes) -> String? {
    return nil
  }
  
  func createFillRule(from rule: LayerTree.FillRule) -> String {
    switch rule {
    case .nonzero:
      return ".winding"
    case .evenodd:
      return ".evenOdd"
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
  
  func getBounds(from shape: LayerTree.Shape) -> LayerTree.Rect {
    return CGProvider().getBounds(from: shape)
  }
}

final class CGTextRenderer: Renderer {
  typealias Types = CGTextTypes

  private let name: String
  private let size: LayerTree.Size

  init(name: String, size: LayerTree.Size) {
    self.name = name
    self.size = size
  }

  private var lines = [String]()
  private var colors: [String: String] = [:]
  private var paths: [String: String] = [:]
  private var transforms: [String: String] = [:]
  private var gradients: [String: String] = [:]

  func createOrGetColor(_ color: String) -> String {
    if let identifier = colors[color] {
      return identifier
    }

    let identifier = "color\(colors.count + 1)"
    colors[color] = identifier
    lines.append("let \(identifier) = \(color)")
    return identifier
  }
  
  func createOrGetPath(_ path: String) -> String {
    if let identifier = paths[path] {
      return identifier
    }

    let identifier = "path\(paths.count + 1)"
    paths[path] = identifier
    let newPath = path
      .replacingOccurrences(of: "path1", with: identifier)
      .split(separator: "\n")
      .map(String.init)
    lines.append(contentsOf: newPath)
    return identifier
  }
  
  func createOrGetTransform(_ transform: String) -> String {
    if let identifier = transforms[transform] {
      return identifier
    }

    let identifier = "transform\(transforms.count + 1)"
    transforms[transform] = identifier
    let newTransform = transform
      .replacingOccurrences(of: "transform1", with: identifier)
      .split(separator: "\n")
      .map(String.init)
    lines.append(contentsOf: newTransform)
    return identifier
  }

  func createOrGetGradient(_ gradient: String) -> String {
    if let identifier = gradients[gradient] {
      return identifier
    }

    let identifier = "gradient\(gradients.count + 1)"
    let locations = "locations\(gradients.count + 1)"
    let colors = "colors\(gradients.count + 1)"
    gradients[gradient] = identifier
    let newGradient = gradient
      .replacingOccurrences(of: "gradient1", with: identifier)
      .replacingOccurrences(of: "colors1", with: colors)
      .replacingOccurrences(of: "locations1", with: locations)
      .split(separator: "\n")
      .map(String.init)
    lines.append(contentsOf: newGradient)
    return identifier
  }

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
  
  func concatenate(transform: String) {
    let identifier = createOrGetTransform(transform)
    lines.append("ctx.concatenate(\(identifier))")
  }

  func translate(tx: LayerTree.Float, ty: LayerTree.Float) {
    lines.append("ctx.translateBy(x: \(tx), y: \(ty))")
  }
  
  func rotate(angle: LayerTree.Float) {
    lines.append("ctx.rotate(by: \(angle))")
  }
  
  func scale(sx: LayerTree.Float, sy: LayerTree.Float) {
    lines.append("ctx.scaleBy(x: \(sx), y: \(sy))")
  }
  
  func setFill(color: String) {
    let identifier = createOrGetColor(color)
    lines.append("ctx.setFillColor(\(identifier))")
  }
  
  func setFill(pattern: LayerTree.Pattern) {
    lines.append("ctx.setFillColorSpace(CGColorSpace(patternBaseSpace: nil)!)")
    lines.append("var alpha : CGFloat = 1.0")
    lines.append("ctx.setFillPattern(pattern, colorComponents: &alpha)")
  }
  
  func setStroke(color: String) {
    let identifier = createOrGetColor(color)
    lines.append("ctx.setStrokeColor(\(identifier))")
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
  
  func setClip(path: String) {
    let identifier = createOrGetPath(path)
    lines.append("ctx.addPath(\(identifier))")
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

  func stroke(path: String) {
    let identifier = createOrGetPath(path)
    lines.append("ctx.addPath(\(identifier))")
    lines.append("ctx.strokePath()")
  }

  func fill(path: String, rule: String) {
    let identifier = createOrGetPath(path)
    lines.append("ctx.addPath(\(identifier))")
    lines.append("ctx.fillPath(using: \(rule))")
  }
  
  func draw(image: LayerTree.Image) {
    lines.append("ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height)")
  }

  func draw(gradient: String, from start: String, to end: String) {
    let identifier = createOrGetGradient(gradient)
    lines.append("""
    ctx.drawLinearGradient(\(identifier),
                           start: \(start),
                           end: \(end),
                           options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
    """)
  }

  private func linesOptimized() -> [String] {
    var lines = lines
    if lines.contains(where: { $0.contains("CGColorSpaceCreateExtendedGray()") }) {
      let gray = "let gray = CGColorSpace(name: CGColorSpace.extendedGray)!"
      lines = lines.map { $0.replacingOccurrences(of: "CGColorSpaceCreateExtendedGray()", with: "gray") }
      lines.insert(gray, at: 0)
    }

    if lines.contains(where: { $0.contains("CGColorSpaceCreateDeviceRGB()") }) {
      let rgb = "let rgb = CGColorSpaceCreateDeviceRGB()"
      lines = lines.map { $0.replacingOccurrences(of: "CGColorSpaceCreateDeviceRGB()", with: "rgb") }
      lines.insert(rgb, at: 0)
    }

    return lines
  }
  
  func makeText() -> String {
    let identifier = name.capitalized.replacingOccurrences(of: " ", with: "")
    var template = """
    extension UIImage {
      static func svg\(identifier)() -> UIImage {
        let f = UIGraphicsImageRendererFormat.default()
        f.opaque = false
        f.preferredRange = .standard
        return UIGraphicsImageRenderer(size: CGSize(width: \(size.width), height: \(size.height)), format: f).image {
          drawSVG(in: $0.cgContext)
        }
      }

      private static func drawSVG(in ctx: CGContext) {

    """

    let indent = String(repeating: " ", count: 4)
    let lines = linesOptimized().map { "\(indent)\($0)" }
    template.append(lines.joined(separator: "\n"))
    template.append("\n  }\n}")
    return template
  }
}

extension String.StringInterpolation {
  mutating func appendInterpolation(_ points: [LayerTree.Point], indent: Int) {
    let indentation = String(repeating: " ", count: indent)
    let provider = CGTextProvider()
    let elements = points
      .map { "\(indentation)\(provider.createPoint(from: $0))" }
      .joined(separator: ",\n")
    appendLiteral(elements)
  }
}
