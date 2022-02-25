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
  typealias Pattern = String
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
    case let .rgba(r, g, b, a, .srgb):
      return "CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [\(r), \(g), \(b), \(a)])!"
    case let .rgba(r, g, b, a, .p3):
      return "CGColor(colorSpace: CGColorSpaceCreateDisplayP3(), components: [\(r), \(g), \(b), \(a)])!"
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

  func createPattern(from pattern: LayerTree.Pattern, contents: [RendererCommand<Types>]) -> String {
    let optimizer = LayerTree.CommandOptimizer<CGTextTypes>(options: [.skipRedundantState, .skipInitialSaveState])
    let contents = optimizer.optimizeCommands(contents)

    let renderer = CGTextRenderer(name: "pattern", size: pattern.frame.size, commandSize: pattern.frame.size)
    renderer.perform(contents)
    let lines = renderer.lines
      .map { "  \($0)" }
      .joined(separator: "\n")

    return """
    let patternDraw1: CGPatternDrawPatternCallback = { _, ctx in
    \(lines)
    }
    var patternCallback1 = CGPatternCallbacks(version: 0, drawPattern: patternDraw1, releaseInfo: nil)
    let pattern1 = CGPattern(
      info: nil,
      bounds: \(createRect(from: pattern.frame)),
      matrix: ctx.ctm.concatenating(baseCTM.inverted()),
      xStep: \(pattern.frame.width),
      yStep: \(pattern.frame.height),
      tiling: .constantSpacing,
      isColored: true,
      callbacks: &patternCallback1
    )!
    """
  }

  func createPath(from shape: LayerTree.Shape) -> [LayerTree.Shape] {
    [shape]
  }

  func createPath(from subPaths: [[LayerTree.Shape]]) -> [LayerTree.Shape] {
    return subPaths.flatMap { $0 }
  }
  
  func createPath(from text: String, at origin: LayerTree.Point, with attributes: LayerTree.TextAttributes) -> [LayerTree.Shape]? {
    nil
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
#if canImport(CoreGraphics)
    return CGProvider().getBounds(from: shape)
#else
    return .zero
#endif
  }
}

public final class CGTextRenderer: Renderer {
  typealias Types = CGTextTypes

  private let name: String
  private let size: LayerTree.Size
  private let commandSize: LayerTree.Size

  init(name: String, size: LayerTree.Size, commandSize: LayerTree.Size) {
    self.name = name
    self.size = size
    self.commandSize = commandSize
  }

  private(set) var lines = [String]()
  private var colorSpaces: Set<ColorSpace> = []
  private var colors: [String: String] = [:]
  private var paths: [String: String] = [:]
  private var transforms: [String: String] = [:]
  private var gradients: [LayerTree.Gradient: String] = [:]
  private var patterns: [String: String] = [:]

  enum ColorSpace: String, Hashable {
    case rgb
    case p3
    case gray

    init?(for color: String) {
      if color.contains("CGColorSpaceCreateExtendedGray()") {
        self = .gray
      } else if color.contains("CGColorSpaceCreateDeviceRGB()")  {
        self = .rgb
      } else if color.contains("CGColorSpaceCreateDisplayP3()")  {
        self = .p3
      } else {
        return nil
      }
    }
  }

  func createOrGetColorSpace(for color: String) -> ColorSpace {
    guard let space = ColorSpace(for: color) else {
      fatalError("not a support color")
    }
    createColorSpace(space)
    return space
  }

  func createColorSpace(_ space: ColorSpace) {
    if !colorSpaces.contains(space) {
      switch space {
      case .gray:
        lines.append("let gray = CGColorSpace(name: CGColorSpace.extendedGray)!")
        colorSpaces.insert(.gray)
      case .rgb:
        lines.append("let rgb = CGColorSpaceCreateDeviceRGB()")
        colorSpaces.insert(.rgb)
      case .p3:
        lines.append("let p3 = CGColorSpace(name: CGColorSpace.displayP3)!")
        colorSpaces.insert(.p3)
      }
    }
  }

  func updateColor(_ color: String) -> String {
    let space = createOrGetColorSpace(for: color)
    switch  space {
    case .gray:
      return color.replacingOccurrences(of: "CGColorSpaceCreateExtendedGray()", with: "gray")
    case .rgb:
      return color.replacingOccurrences(of: "CGColorSpaceCreateDeviceRGB()", with: "rgb")
    case .p3:
      return color.replacingOccurrences(of: "CGColorSpaceCreateDisplayP3()", with: "p3")
    }
  }

  func createOrGetColor(_ color: String) -> String {
    let color = updateColor(color)
    if let identifier = colors[color] {
      return identifier
    }

    let identifier = "color\(colors.count + 1)"
    colors[color] = identifier
    lines.append("let \(identifier) = \(color)")
    return identifier
  }

  func createOrGetColor(_ color: LayerTree.Color) -> String {
    switch color {
    case .none:
      return createOrGetColor("CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0, 0, 0, 0])!")
    case let .rgba(r, g, b, a, .srgb):
      return createOrGetColor("CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [\(r), \(g), \(b), \(a)])!")
    case let .rgba(r, g, b, a, .p3):
      return createOrGetColor("CGColor(colorSpace: CGColorSpaceCreateDisplayP3(), components: [\(r), \(g), \(b), \(a)])!")
    case .gray(white: let w, a: let a):
      return createOrGetColor("CGColor(colorSpace: CGColorSpaceCreateExtendedGray(), components: [\(w), \(a)])!")
    }
  }
  
  func createOrGetPath(_ path: String) -> String {
    if let identifier = paths[path] {
      return identifier
    }

    let idx = paths.count
    let identifier = "path".makeIdentifier(idx)
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

    let idx = transforms.count
    let identifier = "transform".makeIdentifier(idx)
    transforms[transform] = identifier
    let newTransform = transform
      .replacingOccurrences(of: "transform1", with: identifier)
      .split(separator: "\n")
      .map(String.init)
    lines.append(contentsOf: newTransform)
    return identifier
  }

  func createOrGetColorSpace(for colorSpace: LayerTree.ColorSpace) -> ColorSpace {
    switch colorSpace {
    case .srgb:
      createColorSpace(.rgb)
      return .rgb
    case .p3:
      createColorSpace(.p3)
      return .p3
    }
  }

  func createOrGetGradient(_ gradient: LayerTree.Gradient) -> String {
    if let identifier = gradients[gradient] {
      return identifier
    }

    let idx = gradients.count
    let identifier = "gradient".makeIdentifier(idx)
    gradients[gradient] = identifier

    let colorTxt = gradient.stops
      .map { createOrGetColor($0.color) }
      .joined(separator: ", ")

    let pointsTxt = gradient.stops
      .map { String($0.offset) }
      .joined(separator: ", ")

    let space = createOrGetColorSpace(for: gradient.colorSpace)
    let locationsIdentifier = "locations".makeIdentifier(idx)
    let code = """
    var \(locationsIdentifier): [CGFloat] = [\(pointsTxt)]
    let \(identifier) = CGGradient(
      colorsSpace: \(space.rawValue),
      colors: [\(colorTxt)] as CFArray,
      locations: &\(locationsIdentifier)
    )!
    """.split(separator: "\n").map(String.init)
    lines.append(contentsOf: code)
    return identifier
  }

  func createOrGetPattern(_ pattern: String) -> String {
    if let identifier = patterns[pattern] {
      return identifier
    }

    let idx = patterns.count

    let identifier = "pattern".makeIdentifier(idx)
    let draw = "patternDraw".makeIdentifier(idx)
    let callback = "patternCallback".makeIdentifier(idx)
    patterns[pattern] = identifier
    let newPattern = pattern
      .replacingOccurrences(of: "pattern1", with: identifier)
      .replacingOccurrences(of: "patternDraw1", with: draw)
      .replacingOccurrences(of: "patternCallback1", with: callback)
      .split(separator: "\n")
      .map(String.init)
    lines.append(contentsOf: newPattern)

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
  
  func setFill(pattern: String) {
    let identifier = createOrGetPattern(pattern)
    let alpha = identifier.replacingOccurrences(of: "pattern", with: "patternAlpha")
    lines.append("ctx.setFillColorSpace(CGColorSpace(patternBaseSpace: nil)!)")
    lines.append("var \(alpha) : CGFloat = 1.0")
    lines.append("ctx.setFillPattern(\(identifier), colorComponents: &\(alpha))")
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
  
  func setClip(path: [LayerTree.Shape]) {
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

  func stroke(path: [LayerTree.Shape]) {
    if let frame = getSimpleRect(from: path) {
      lines.append("ctx.stroke(\(frame))")
    } else if let frame = getSimpleEllipse(from: path) {
      lines.append("ctx.strokeEllipse(in: \(frame))")
    } else {
      let identifier = createOrGetPath(path)
      lines.append("ctx.addPath(\(identifier))")
      lines.append("ctx.strokePath()")
    }
  }

  func fill(path: [LayerTree.Shape], rule: String) {
    
    if let frame = getSimpleRect(from: path) {
      lines.append("ctx.fill(\(frame))")
    } else if let frame = getSimpleEllipse(from: path) {
      lines.append("ctx.fillEllipse(in: \(frame))")
    } else {
      let identifier = createOrGetPath(path)
      lines.append("ctx.addPath(\(identifier))")
      lines.append("ctx.fillPath(using: \(rule))")
    }
  }
  
  func draw(image: LayerTree.Image) {
    lines.append("ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height)")
  }

  func draw(gradient: LayerTree.Gradient, from start: String, to end: String) {
    let identifier = createOrGetGradient(gradient)
    lines.append("""
    ctx.drawLinearGradient(\(identifier),
                           start: \(start),
                           end: \(end),
                           options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
    """)
  }

  func makeText() -> String {
    var template = """
    extension UIImage {
      static func \(name)(size: CGSize = CGSize(width: \(size.width), height: \(size.height))) -> UIImage {
        let f = UIGraphicsImageRendererFormat.preferred()
        f.opaque = false
        let scale = CGSize(width: size.width / \(commandSize.width), height: size.height / \(commandSize.height))
        return UIGraphicsImageRenderer(size: size, format: f).image {
          drawSVG(in: $0.cgContext, scale: scale)
        }
      }

      private static func drawSVG(in ctx: CGContext, scale: CGSize) {

    """

    lines.insert("ctx.scaleBy(x: scale.width, y: scale.height)", at: 0)
    if !patterns.isEmpty {
        lines.insert("let baseCTM = ctx.ctm", at: 0)
    }

    let indent = String(repeating: " ", count: 4)
    let lines = self.lines.map { "\(indent)\($0)" }
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

private extension String {

  func makeIdentifier(_ index: Int) -> String {
    guard index > 0 else {
      return self
    }
    return "\(self)\(index)"
  }
}
