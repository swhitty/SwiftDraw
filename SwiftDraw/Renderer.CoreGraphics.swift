//
//  Renderer.CoreGraphics.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 4/6/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
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

import CoreGraphics
import Foundation
import CoreText
#if os(macOS)
    import AppKit
#elseif os(iOS)
    import UIKit
#endif

struct CGTypes: RendererTypes {
    typealias Float = CGFloat
    typealias Point = CGPoint
    typealias Size = CGSize
    typealias Rect = CGRect
    typealias Color = CGColor
    typealias Gradient = CGGradient
    typealias Mask = CGImage
    typealias Path = CGPath
    typealias Pattern = CGPattern
    typealias Transform = CGAffineTransform
    typealias BlendMode = CGBlendMode
    typealias FillRule = CGPathFillRule
    typealias LineCap = CGLineCap
    typealias LineJoin = CGLineJoin
    typealias Image = CGImage
}

struct CGProvider: RendererTypeProvider {
    typealias Types = CGTypes
    
    func createFloat(from float: LayerTree.Float) -> CGFloat {
        return CGFloat(float)
    }
    
    func createPoint(from point: LayerTree.Point) -> CGPoint {
        return CGPoint(x: CGFloat(point.x), y: CGFloat(point.y))
    }
    
    func createSize(from size: LayerTree.Size) -> CGSize {
     return CGSize(width: CGFloat(size.width), height: CGFloat(size.height))
    }
    
    func createRect(from rect: LayerTree.Rect) -> CGRect {
        return CGRect(x: CGFloat(rect.x),
                      y: CGFloat(rect.y),
                      width: CGFloat(rect.width),
                      height: CGFloat(rect.height))
    }
    
    func createColor(from color: LayerTree.Color) -> CGColor {
        switch color {
        case .none: return createColor(r: 0, g: 0, b: 0, a: 0)
        case .rgba(let c): return createColor(r: CGFloat(c.r),
                                              g: CGFloat(c.g),
                                              b: CGFloat(c.b),
                                              a: CGFloat(c.a))
        case .gray(white: let w, a: let a):
            return createColor(w: CGFloat(w), a: CGFloat(a))
        }
    }

    func createGradient(from gradient: LayerTree.Gradient) -> CGGradient {
        let colors = gradient.stops.map { createColor(from: $0.color) } as CFArray
        var points = gradient.stops.map { createFloat(from: $0.offset) }

        return CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: colors,
                          locations: &points)!
    }

    private func createColor(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) -> CGColor {
        return CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(),
                       components: [r, g, b, a])!
    }

    private func createColor(w: CGFloat, a: CGFloat) -> CGColor {
        let space = CGColorSpace(name: CGColorSpace.extendedGray)!
        return CGColor(colorSpace: space, components: [w, a])!
    }

    func createMask(from contents: [RendererCommand<CGTypes>], size: LayerTree.Size) -> CGImage {

        return CGImage.makeMask(size: createSize(from: size)) { ctx in
            let renderer = CGRenderer(context: ctx)
            renderer.perform(contents)
        }
    }

    func createBlendMode(from mode: LayerTree.BlendMode) -> CGBlendMode {
        switch mode {
        case .normal: return .normal
        case .copy: return .copy
        case .sourceIn: return .sourceIn
        case .destinationIn: return .destinationIn
        }
    }
    func createTransform(from transform: LayerTree.Transform.Matrix) -> CGAffineTransform {
        return CGAffineTransform(a: CGFloat(transform.a),
                                 b: CGFloat(transform.b),
                                 c: CGFloat(transform.c),
                                 d: CGFloat(transform.d),
                                 tx: CGFloat(transform.tx),
                                 ty: CGFloat(transform.ty))
    }
    
    func createPath(from shape: LayerTree.Shape) -> CGPath {
        switch shape {
        case .line(let points):
            let path = CGMutablePath()
            path.addLines(between: points.map{ createPoint(from: $0) })
            return path
        case .rect(let frame, let radii):
            return CGPath(roundedRect: createRect(from: frame),
                          cornerWidth: createFloat(from: radii.width),
                          cornerHeight: createFloat(from: radii.height),
                          transform: nil)
        case .ellipse(let frame):
            return CGPath(ellipseIn: createRect(from: frame), transform: nil)
        case .polygon(let points):
            let path = CGMutablePath()
            path.addLines(between: points.map{ createPoint(from: $0) })
            path.closeSubpath()
            return path
        case .path(let path):
            return createPath(from: path)
        }
    }
    
    private func createPath(from path: LayerTree.Path) -> CGPath {
        let cgPath = CGMutablePath()
        for s in path.segments {
            switch s {
            case .move(let p):
                cgPath.move(to: createPoint(from: p))
            case .line(let p):
                cgPath.addLine(to: createPoint(from: p))
            case .cubic(let p, let cp1, let cp2):
                cgPath.addCurve(to: createPoint(from: p),
                                control1: createPoint(from: cp1),
                                control2: createPoint(from: cp2))
            case .close:
                cgPath.closeSubpath()
            }
        }
        return cgPath
    }
    
    func createPath(from subPaths: [CGPath]) -> CGPath {
        let cgPath = CGMutablePath()
        
        for path in subPaths {
            cgPath.addPath(path)
        }
        
        return cgPath
    }

    func createPath(from text: String, at origin: LayerTree.Point, with attributes: LayerTree.TextAttributes) -> Types.Path? {
        let font = CTFontCreateWithName(attributes.fontName as CFString,
                                        createFloat(from: attributes.size),
                                        nil)
        guard let path = text.toPath(font: font) else { return nil }
        
        var transform = CGAffineTransform(translationX: createFloat(from: origin.x), y: createFloat(from: origin.y))
        return path.copy(using: &transform)
    }

    func createPattern(from pattern: LayerTree.Pattern, contents: [RendererCommand<Types>]) -> CGPattern {
        let bounds = createRect(from: pattern.frame)
        return CGPattern.make(bounds: bounds,
                              matrix: .identity,
                              step: bounds.size,
                              tiling: .constantSpacing,
                              isColored: true) { ctx in
                                let renderer = CGRenderer(context: ctx)
                                renderer.perform(contents)
        }
    }

    func createFillRule(from rule: LayerTree.FillRule) -> CGPathFillRule {
        switch rule {
        case .nonzero:
            return .winding
        case .evenodd:
            return .evenOdd
        }
    }
    
    func createLineCap(from cap: LayerTree.LineCap) -> CGLineCap {
        switch cap {
        case .butt: return .butt
        case .round: return .round
        case .square: return .square
        }
    }
    
    func createLineJoin(from join: LayerTree.LineJoin) -> CGLineJoin {
        switch join {
        case .bevel: return .bevel
        case .round: return .round
        case .miter: return .miter
        }
    }
    
    func createImage(from image: LayerTree.Image) -> CGImage? {
        switch image {
        case .jpeg(data: let d):
            return CGImage.from(data: d)
        case .png(data: let d):
            return CGImage.from(data: d)
        }
    }

    func getBounds(from path: CGPath) -> LayerTree.Rect {
        let bounds = path.boundingBoxOfPath
        return LayerTree.Rect(x: LayerTree.Float(bounds.origin.x),
                              y: LayerTree.Float(bounds.origin.y),
                              width: LayerTree.Float(bounds.width),
                              height: LayerTree.Float(bounds.height))
    }
}

//TODO: replace with CG implementation
private extension CGImage {
    static func from(data: Data) -> CGImage? {
        #if os(iOS)
            return UIImage(data: data)?.cgImage
        #elseif os(macOS)
            guard let image = NSImage(data: data) else { return nil }
            var rect = NSRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
            return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        #endif
    }
}

struct CGRenderer: Renderer {
    typealias Types = CGTypes
    
    let ctx: CGContext
    
    init(context: CGContext) {
        self.ctx = context
    }
    
    func pushState() {
        ctx.saveGState()
    }
    
    func popState() {
        ctx.restoreGState()
    }
    
    func pushTransparencyLayer() {
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    }
    
    func popTransparencyLayer() {
        ctx.endTransparencyLayer()
    }
    
    func concatenate(transform: CGAffineTransform) {
        ctx.concatenate(transform)
    }
    
    func translate(tx: CGFloat, ty: CGFloat) {
        ctx.translateBy(x: tx, y: ty)
    }
    
    func rotate(angle: CGFloat) {
        ctx.rotate(by: angle)
    }
    
    func scale(sx: CGFloat, sy: CGFloat) {
        ctx.scaleBy(x: sx, y: sy)
    }
    
    func setFill(color: CGColor) {
        ctx.setFillColor(color)
    }

    func setFill(pattern: CGPattern) {
        let patternSpace = CGColorSpace(patternBaseSpace: nil)!
        ctx.setFillColorSpace(patternSpace)
        var alpha : CGFloat = 1.0
        ctx.setFillPattern(pattern, colorComponents: &alpha)
    }

    func setStroke(color: CGColor) {
        ctx.setStrokeColor(color)
    }
    
    func setLine(width: CGFloat) {
        ctx.setLineWidth(width)
    }
    
    func setLine(cap: CGLineCap) {
        ctx.setLineCap(cap)
    }
    
    func setLine(join: CGLineJoin) {
        ctx.setLineJoin(join)
    }
    
    func setLine(miterLimit: CGFloat) {
        ctx.setMiterLimit(miterLimit)
    }
    
    func setClip(path: CGPath) {
        ctx.addPath(path)
        ctx.clip()
    }

    func setClip(mask: CGImage, frame: CGRect) {
        ctx.clip(to: frame, mask: mask)
    }

    func setAlpha(_ alpha: CGFloat) {
        ctx.setAlpha(alpha)
    }
    
    func setBlend(mode: CGBlendMode) {
        ctx.setBlendMode(mode)
    }
    
    func stroke(path: CGPath) {
        ctx.addPath(path)
        ctx.strokePath()
    }
    
    func fill(path: CGPath, rule: CGPathFillRule) {
        ctx.addPath(path)
        ctx.fillPath(using: rule)
    }
    
    func draw(image: CGImage) {
        let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        ctx.draw(image, in: rect)
    }

    func draw(gradient: CGGradient, from start: CGPoint, to end: CGPoint) {
        ctx.drawLinearGradient(gradient,
                               start: start,
                               end: end,
                               options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
    }
}
