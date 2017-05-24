//
//  CoreGraphicsRenderer.swift
//  SwiftVG
//
//  Created by Simon Whitty on 27/3/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

import CoreGraphics
import Foundation
import CoreText
#if os(macOS)
    import AppKit
#endif
#if os(iOS)
    import UIKit
#endif

struct CoreGraphicsProvider: RendererTypeProvider {
    typealias Color = CGColor
    typealias Path = CGPath
    typealias Transform = CGAffineTransform
    typealias Float = CGFloat
    typealias Point = CGPoint
    typealias Rect = CGRect
    typealias BlendMode = CGBlendMode
    typealias LineCap = CGLineCap
    typealias LineJoin = CGLineJoin
    typealias Image = CGImage
    
    func createFloat(from float: Builder.Float) -> Float {
        return CGFloat(float)
    }
    
    func createPoint(from point: Builder.Point) -> CGPoint {
        return CGPoint(x: CGFloat(point.x),
                       y: CGFloat(point.y))
    }
    
    func createRect(from rect: Builder.Rect) -> CGRect {
        return CGRect(x: CGFloat(rect.x),
                      y: CGFloat(rect.y),
                      width: CGFloat(rect.width),
                      height: CGFloat(rect.height))
    }
    
    func createColor(from color: Builder.Color) -> Color {
        switch color {
        case .none: return createColor(r: 0, g: 0, b: 0, a: 0)
        case .rgba(let c): return createColor(r: CGFloat(c.r),
                                              g: CGFloat(c.g),
                                              b: CGFloat(c.b),
                                              a: CGFloat(c.a))
        }
    }
    
    private func createColor(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) -> CGColor {
        return CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(),
                       components: [r, g, b, a])!
    }
    
    func createBlendMode(from mode: Builder.BlendMode) -> CGBlendMode {
        switch mode {
        case .normal: return .normal
        case .copy: return .copy
        case .sourceIn: return .sourceIn
        }
    }
    
    func createLineCap(from cap: Builder.LineCap) -> CGLineCap {
        switch cap {
        case .butt: return .butt
        case .round: return .round
        case .square: return .square
        }
    }
    
    func createLineJoin(from join: Builder.LineJoin) -> CGLineJoin {
        switch join {
        case .bevel: return .bevel
        case .round: return .round
        case .miter: return .miter
        }
    }
    
    func createTransform(from transform: Builder.Transform) -> Transform {
        return CGAffineTransform(a: CGFloat(transform.a),
                                 b: CGFloat(transform.b),
                                 c: CGFloat(transform.c),
                                 d: CGFloat(transform.d),
                                 tx: CGFloat(transform.tx),
                                 ty: CGFloat(transform.ty))
    }
    
    func createEllipse(within rect: Rect) -> Path {
        return CGPath(ellipseIn: rect, transform: nil)
    }
    
    func createLine(from origin: Point, to desination: Point) -> Path {
        return createLine(between: [origin, desination])
    }
    
    func createLine(between points: [Point]) -> Path {
        let path = CGMutablePath()
        path.addLines(between: points)
        return path
    }
    
    func createPolygon(between points: [Point]) -> Path {
        let path = CGMutablePath()
        path.addLines(between: points)
        path.closeSubpath()
        return path
    }
    
    func createRect(from rect: Rect, radii: Builder.Size) -> Path {
        return CGPath(roundedRect: rect,
                      cornerWidth: CGFloat(radii.width),
                      cornerHeight: CGFloat(radii.height),
                      transform: nil)
    }
    
    func createPath(from path: Builder.Path) -> Path {
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
    
    func createPath(from subPaths: [Path]) -> Path {
        let cgPath = CGMutablePath()
        
        for path in subPaths {
            cgPath.addPath(path)
        }
        
        return cgPath
    }
    
    func createText(from text: String, with fontName: String, at origin: Point, ofSize pt: Float) -> Path? {
        let font = CTFontCreateWithName(fontName as CFString, pt, nil)
        guard let path = text.toPath(font: font) else { return nil }
        
        var transform = CGAffineTransform(translationX: origin.x, y: origin.y)
        return path.copy(using: &transform)
    }
    
    func createImage(from image: Builder.Image) -> CGImage? {
        switch image {
        case .jpeg(data: let d):
            return CGImage.from(data: d)
        case .png(data: let d):
            return CGImage.from(data: d)
        }
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


struct CoreGraphicsRenderer: Renderer {
    typealias Provider = CoreGraphicsProvider
    
    let ctx: CGContext
    
    init(context: CGContext) {
        self.ctx = context
    }
    
    func perform(_ commands: [RendererCommand<Provider>]) {
        for cmd in commands {
            perform(cmd)
        }
    }

    
    func perform(_ command: RendererCommand<Provider>) {
        switch command {
        case .pushState:
            ctx.saveGState()
        case .popState:
            ctx.restoreGState()
        case .concatenate(transform: let t):
            ctx.concatenate(t)
        case .translate(tx: let x, ty: let y):
            ctx.translateBy(x: x, y: y)
        case .scale(sx: let x, sy: let y):
            ctx.scaleBy(x: x, y: y)
        case .rotate(angle: let a):
            ctx.rotate(by: a)
        case .setFill(color: let c):
            ctx.setFillColor(c)
        case .setStroke(color: let c):
            ctx.setStrokeColor(c)
        case .setLine(width: let w):
            ctx.setLineWidth(w)
        case .setLineCap(let c):
            ctx.setLineCap(c)
        case .setLineJoin(let j):
            ctx.setLineJoin(j)
        case .setLineMiter(limit: let l):
            ctx.setMiterLimit(l)
        case .setClip(path: let p):
            ctx.addPath(p)
            ctx.clip()
        case .setBlend(mode: let m):
            ctx.setBlendMode(m)
        case .stroke(let p):
            ctx.addPath(p)
            ctx.strokePath()
        case .fill(let p):
            ctx.addPath(p)
            ctx.fillPath()
        case .draw(image: let i):
            let rect = CGRect(x: 0, y: 0, width: i.width, height: i.height)
            ctx.draw(i, in: rect)
        case .pushTransparencyLayer:
            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        case .popTransparencyLayer:
            ctx.endTransparencyLayer()
        }
    }
}


