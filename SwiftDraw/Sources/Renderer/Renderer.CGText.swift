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
  typealias Mask = [AnyHashable]
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
  
  let formatter: CoordinateFormatter

  init(formatter: CoordinateFormatter) {
    self.formatter = formatter
  }

  func createFloat(from float: LayerTree.Float) -> LayerTree.Float {
    return float
  }

  func createPoint(from point: LayerTree.Point) -> String {
    let x = formatter.format(point.x)
    let y = formatter.format(point.y)
    return "CGPoint(x: \(x), y: \(y))"
  }
  
  func createSize(from size: LayerTree.Size) -> String {
    let width = formatter.format(size.width)
    let height = formatter.format(size.height)
    return "CGSize(width: \(width), height: \(height))"
  }
  
  func createRect(from rect: LayerTree.Rect) -> String {
    let x = formatter.format(rect.x)
    let y = formatter.format(rect.y)
    let width = formatter.format(rect.width)
    let height = formatter.format(rect.height)
    return "CGRect(x: \(x), y: \(y), width: \(width), height: \(height))"
  }

  func createColor(from color: LayerTree.Color) -> String {
    let d3 = CoordinateFormatter.Precision.capped(max: 3)
    switch color {
    case .none:
      return "CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0, 0, 0, 0])!"
    case let .rgba(r, g, b, a, .srgb):
      let comps = formatter.format(r, g, b, a, precision: d3)
      return "CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [\(comps)])!"
    case let .rgba(r, g, b, a, .p3):
      let comps = formatter.format(r, g, b, a, precision: d3)
      return "CGColor(colorSpace: CGColorSpaceCreateDisplayP3(), components: [\(comps)])!"
    case .gray(white: let w, a: let a):
      let comps = formatter.format(w, a, precision: d3)
      return "CGColor(colorSpace: CGColorSpaceCreateExtendedGray(), components: [\(comps)])!"
    }
  }

  func createGradient(from gradient: LayerTree.Gradient) -> LayerTree.Gradient {
    return gradient
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

    let formatter = CoordinateFormatter(delimeter: .commaSpace,
                                        precision: .capped(max: 3))

    let renderer = CGTextRenderer(api: .appKit,
                                  name: "pattern",
                                  size: pattern.frame.size,
                                  commandSize: pattern.frame.size,
                                  formatter: formatter)
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
      xStep: \(formatter.format(pattern.frame.width)),
      yStep: \(formatter.format(pattern.frame.height)),
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

  func createSize(from image: LayerTree.Image) -> LayerTree.Size {
    LayerTree.Size(image.width ?? 0, image.height ?? 0)
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

  private let api: API
  private let name: String
  private let size: LayerTree.Size
  private let commandSize: LayerTree.Size
  let formatter: CoordinateFormatter

  public enum API {
    case uiKit
    case appKit
  }

  init(api: API,
       name: String,
       size: LayerTree.Size,
       commandSize: LayerTree.Size,
       formatter: CoordinateFormatter) {
    self.api = api
    self.name = name
    self.size = size
    self.commandSize = commandSize
    self.formatter = formatter
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
    let d3 = CoordinateFormatter.Precision.capped(max: 3)
    switch color {
    case .none:
      return createOrGetColor("CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0, 0, 0, 0])!")
    case let .rgba(r, g, b, a, .srgb):
      let comps = formatter.format(r, g, b, a, precision: d3)
      return createOrGetColor("CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [\(comps)])!")
    case let .rgba(r, g, b, a, .p3):
      let comps = formatter.format(r, g, b, a, precision: d3)
      return createOrGetColor("CGColor(colorSpace: CGColorSpaceCreateDisplayP3(), components: [\(comps)])!")
    case .gray(white: let w, a: let a):
      let comps = formatter.format(w, a, precision: d3)
      return createOrGetColor("CGColor(colorSpace: CGColorSpaceCreateExtendedGray(), components: [\(comps)])!")
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
    lines.append("ctx.translateBy(x: \(formatter.format(tx)), y: \(formatter.format(ty)))")
  }

  func rotate(angle: LayerTree.Float) {
    lines.append("ctx.rotate(by: \(formatter.format(angle)))")
  }
  
  func scale(sx: LayerTree.Float, sy: LayerTree.Float) {
    lines.append("ctx.scaleBy(x: \(formatter.format(sx)), y: \(formatter.format(sy)))")
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
    lines.append("ctx.setLineWidth(\(formatter.format(width)))")
  }
  
  func setLine(cap: String) {
    lines.append("ctx.setLineCap(\(cap))")
  }
  
  func setLine(join: String) {
    lines.append("ctx.setLineJoin(\(join))")
  }
  
  func setLine(miterLimit: LayerTree.Float) {
    lines.append("ctx.setMiterLimit(\(formatter.format(miterLimit)))")
  }

  func setClip(path: [LayerTree.Shape], rule: String) {
    let identifier = createOrGetPath(path)
    lines.append("ctx.addPath(\(identifier))")
    if rule == ".winding" {
      lines.append("ctx.clip()")
    } else {
      lines.append("ctx.clip(using: \(rule))")
    }
  }

  func setClip(mask: [AnyHashable], frame: String) {
    lines.append("ctx.clip(to: \(frame), mask: \(mask))")
  }
  
  func setAlpha(_ alpha: LayerTree.Float) {
    lines.append("ctx.setAlpha(\(formatter.format(alpha)))")
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

  func clipStrokeOutline(path: [LayerTree.Shape]) {
      let identifier = createOrGetPath(path)
      lines.append("ctx.addPath(\(identifier))")
      lines.append("ctx.replacePathWithStrokedPath()")
      lines.append("ctx.clip()")
  }

  func fill(path: [LayerTree.Shape], rule: String) {
    if let frame = getSimpleRect(from: path) {
      lines.append("ctx.fill(\(frame))")
    } else if let frame = getSimpleEllipse(from: path) {
      lines.append("ctx.fillEllipse(in: \(frame))")
    } else {
      let identifier = createOrGetPath(path)
      lines.append("ctx.addPath(\(identifier))")
      if rule == ".winding" {
        lines.append("ctx.fillPath()")
      } else {
        lines.append("ctx.fillPath(using: \(rule))")
      }
    }
  }
  
  func draw(image: LayerTree.Image, in rect: String) {
    lines.append("ctx.saveGState()")
    lines.append("ctx.translateBy(x: 0, y: image.height)")
    lines.append("ctx.scaleBy(x: 1, y: -1)")
    lines.append("ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height)")
    lines.append("ctx.restoreGState()")
  }

  func draw(linear gradient: LayerTree.Gradient, from start: String, to end: String) {
    let identifier = createOrGetGradient(gradient)
    lines.append("""
    ctx.drawLinearGradient(\(identifier),
                           start: \(start),
                           end: \(end),
                           options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
    """)
  }

  func draw(radial gradient: LayerTree.Gradient, startCenter: String, startRadius: LayerTree.Float, endCenter: String, endRadius: LayerTree.Float) {
    let identifier = createOrGetGradient(gradient)
    lines.append("""
    ctx.drawRadialGradient(\(identifier),
                           startCenter: \(startCenter),
                           startRadius: \(formatter.format(startRadius)),
                           endCenter: \(endCenter),
                           endRadius: \(formatter.format(endRadius)),
                           options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
    """)
  }

  func makeUIKit() -> String {
    """
    import CoreGraphics
    import UIKit

    extension UIImage {
      static func svg\(name)(size: CGSize = CGSize(width: \(size.width), height: \(size.height))) -> UIImage {
        let f = UIGraphicsImageRendererFormat.preferred()
        f.opaque = false
        let scale = CGSize(width: size.width / \(commandSize.width), height: size.height / \(commandSize.height))
        return UIGraphicsImageRenderer(size: size, format: f).image {
          draw\(name)(in: $0.cgContext, scale: scale)
        }
      }

      private static func draw\(name)(in ctx: CGContext, scale: CGSize) {

    """
  }

  func makeAppKit() -> String {
    """
    import Cocoa
    import CoreGraphics

    
    extension NSImage {
      static func svgKey(size: NSSize = NSSize(width: \(size.width), height: \(size.height))) -> NSImage {
        NSImage(size: size, flipped: true) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let scale = CGSize(width: rect.width / \(commandSize.width), height: rect.height / \(commandSize.height))
            draw\(name)(in: ctx, scale: scale)
            return true
        }
      }

    private static func draw\(name)(in ctx: CGContext, scale: CGSize) {

    """
  }

  func makeTemplate() -> String {
    switch api {
    case .appKit:
      return makeAppKit()
    case .uiKit:
      return makeUIKit()
    }
  }

  func makeText() -> String {
    var template = makeTemplate()

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
    let provider = CGTextProvider(formatter: .init(delimeter: .commaSpace, precision: .capped(max: 3)))
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
