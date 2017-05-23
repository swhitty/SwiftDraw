//
//  CodeRenderer.swift
//  SwiftVG
//
//  Created by Simon Whitty on 6/4/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

import Foundation

struct CodeProvider: RendererTypeProvider {
    typealias Color = Builder.Color
    typealias Path = CodePath
    typealias Transform = Builder.Transform
    typealias Float = Builder.Float
    typealias Point = Builder.Point
    typealias Rect = Builder.Rect
    typealias BlendMode = Builder.BlendMode
    typealias LineCap = Builder.LineCap
    typealias LineJoin = Builder.LineJoin
    typealias Image = Builder.Image
    
    func createFloat(from float: Builder.Float) -> Float {
        return float
    }
    
    func createPoint(from point: Builder.Point) -> Point {
        return point
    }
    
    func createRect(from rect: Builder.Rect) -> Rect {
        return rect
    }
    
    func createColor(from color: Builder.Color) -> Color {
        return color
    }
    
    func createBlendMode(from mode: Builder.BlendMode) -> BlendMode {
        return mode
    }
    
    func createLineCap(from cap: Builder.LineCap) -> Builder.LineCap {
        return cap
    }
    
    func createLineJoin(from join: Builder.LineJoin) -> Builder.LineJoin {
        return join
    }
    
    func createTransform(from transform: Builder.Transform) -> Transform {
        return Transform.identity
    }
    
    func createEllipse(within rect: Builder.Rect) -> Path {
        return .ellipse(within: rect)
    }
    
    func createLine(from origin: Builder.Point, to desination: Builder.Point) -> Path {
        return .lines(between: [origin, desination])
    }
    
    func createLine(between points: [Builder.Point]) -> Path {
        return .lines(between: points)
    }
    
    func createPolygon(between points: [Builder.Point]) -> Path {
        return .polygon(points: points)
    }
    
    func createRect(from rect: Builder.Rect, radii: Builder.Size) -> Path {
        return .rect(rect: rect, radii: radii)
    }
    
    func createPath(from path: Builder.Path) -> Path {
        return .path(from: path)
    }
    
    func createPath(from subPaths: [Path]) -> Path {
        return .compound(paths: subPaths)
    }
    
    func createImage(from image: Builder.Image) -> Builder.Image? {
        return image
    }
}

struct DeclarationSet<T: Equatable> {
    var baseName: String
    private(set) var declarations: [T]
    
    init(baseName: String) {
        self.baseName = baseName
        declarations = [T]()
    }
    
    mutating func declareIfRequired(_ value: T) -> String {
        guard let idx = declarations.index(of: value) else {
            let idx = declarations.count
            declarations.append(value)
            return name(for: idx)
        }
        return name(for: idx)
    }
    
    func name(for index: Int) -> String {
        guard index > 0 else {
            return baseName
        }
        
        return "\(baseName)\(index)"
    }
}

struct SwiftRenderer {
    var colors = Array<Builder.Color>()
    var paths = Array<CodePath>()
    
    var lines = [String]()
    
    var indent: String = "   "
    var indentLevel: Int = 0
    
    var currentIndent: String {
        var text = ""
        for _ in 0...indentLevel {
            text += indent
        }
        return text
    }
    
    mutating func append(_ line: String) {
        lines.append("\(currentIndent)\(line)")
    }
    
    mutating func declareIfRequired(_ color: Builder.Color) -> String {
        guard let idx = colors.index(of: color) else {
            let suffix = colors.isEmpty ? "" : "\(colors.count)"
            colors.append(color)
            let identifier = "c\(suffix)"
            append("let \(identifier) = \(render(color))")
            return identifier
        }
        return "c\(idx)"
    }
    
    mutating func declareIfRequired(_ path: CodePath) -> String {
        guard let idx = paths.index(of: path) else {
            let suffix = paths.isEmpty ? "" : "\(paths.count)"
            paths.append(path)
            let identifier = "p\(suffix)"
            append("let \(identifier) = \(render(path))")
            return identifier
        }
        return "p\(idx)"
    }
    
    func render(_ color: Builder.Color) -> String {
        switch color {
        case .none:
            return "CGColor(gray: 0, alpha: 0)"
        case .rgba(let r, let g, let b, let a):
            return "CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [\(r), \(g), \(b), \(a)])!"
        }
    }
    
    func render(_ path: CodePath) -> String {
        return "CGPath()"
    }
    
    mutating func addLines(for commands: [RendererCommand<CodeProvider>]) {
        commands.forEach {
            addLines(for: $0)
        }
    }
    
    mutating func addLines(for command: RendererCommand<CodeProvider>) {
        switch command {
        case .pushState:
            append("ctx.saveGState()")
        case .popState:
            append("ctx.restoreGState()")
        case .popState:
            append("ctx.restoreGState()")
        case .translate(let t):
            append("ctx.translateBy(x: \(t.tx), y: \(t.ty))")
        case .scale(let t):
            append("ctx.scaleBy(x: \(t.sx), y: \(t.sy))")
        case .rotate(let angle):
            append("ctx.rotate(angle: \(angle))")
        case .setFill(color: let c):
            let name = declareIfRequired(c)
            append("ctx.setFillColor(\(name))")
        case .setStroke(color: let c):
            let name = declareIfRequired(c)
            append("ctx.setStrokeColor(\(name))")
        case .fill(let p):
            let name = declareIfRequired(p)
            append("ctx.addPath(\(name))")
            append("ctx.fillPath()")
        case .stroke(let p):
            let name = declareIfRequired(p)
            append("ctx.addPath(\(name))")
            append("ctx.strokePath()")
        default: ()
        }
    }
    
}

struct CodeRenderer: Renderer {
    typealias Provider = CodeProvider
    
    func perform(_ commands: [RendererCommand<Provider>]) { }

    func render(_ commands: [RendererCommand<Provider>]) -> String {
        let indent = "   "
        var buffer = "func render(in ctx: CGContext) {\n"
        buffer += "\n"
        
        let paths = getPaths(from: commands)
        let colors = getColors(from: commands)
//        
//        print("paths: \(paths.count)")
//        print("colors: \(colors.count)")
//        
        for c in colors {
            buffer += "\(indent)\(render(c))\n"
        }
        
        for cmd in commands {
            if let line = render(cmd) {
                buffer += "\(indent)\(line)\n"
            }
        }
        buffer += "}"
        
        return buffer
    }
    
    func getColors(from commands: [RendererCommand<Provider>]) -> [Provider.Color] {
        //prefer to use OrderedSet<>
        var set = Array<Provider.Color>()
        
        for command in commands {
            switch command {
            case .setFill(color: let color):
                set.appendUnqiue(color)
            case .setStroke(color: let color):
                set.appendUnqiue(color)
            default: continue
            }
        }
        return set
    }
    
    func getPaths(from commands: [RendererCommand<Provider>]) -> [Provider.Path] {
        var set = Array<Provider.Path>()
        
        for command in commands {
            switch command {
            case .stroke(let p):
                set.appendUnqiue(p)
            case .fill(let p):
                set.appendUnqiue(p)
            default: continue
            }
        }
        
        return set
    }
    
    
    
    func render(_ command: RendererCommand<Provider>) -> String? {
        switch command {
        case .pushState: return "ctx.saveGState()"
        case .popState: return "ctx.restoreGState()"
        case .translate(let t): return "ctx.translateBy(x: \(t.tx), y: \(t.ty))"
        case .scale(let t): return "ctx.scaleBy(x: \(t.sx), y: \(t.sy))"
        case .rotate(let angle): return "ctx.rotate(angle: \(angle))"
        case .setFill(color: let c): return "ctx.setFillColor(\(render(c)))"
        case .setStroke(color: let c): return "ctx.setStrokeColor(\(render(c)))"
        case .setBlend(mode: let b): return "ctx.setBlendMode(\(render(b)))"
        default: return nil
        }
    }
    
    func render(_ color: Provider.Color) -> String {
        switch color {
            case .none:
                return "CGColor(gray: 0, alpha: 0)"
            case .rgba(let r, let g, let b, let a):
                return "CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [\(r), \(g), \(b), \(a)])!"
        }
    }
    
    func render(_ rect: Provider.Rect) -> String {
        return "CGRect(x: \(rect.x), y: \(rect.y), width: \(rect.width), height: \(rect.height))"
    }
    
    func render(_ point: Provider.Point) -> String {
        return "CGPoint(x: \(point.x), y: \(point.y))"
    }
    
    func render(_ blendMode: Provider.BlendMode) -> String {
        switch blendMode {
        case .copy: return ".copy"
        case .normal: return ".normal"
        case .sourceIn: return ".sourceIn"
        }
    }
    
//    func render(_ path: Provider.Path) -> String? {
//        switch path {
//        case .ellipse(within: let r):
//            return "CGPath(ellipseIn: \(render(r)), transform: nil)"
//        case .rect(rect: let r, radii: let s):
//            return "CGPath(roundedRect: \(render(r)), cornerWidth: \(s.width), cornerHeight: \(s.height), transform: nil)"
//        case .path(from: let p):
//            return ""
//        }
//    }

    func render(_ path: Provider.Path, identifier: String) -> [String] {
        switch path {
        case .ellipse(within: let r):
            return ["let \(identifier) = CGPath(ellipseIn: \(render(r)), transform: nil)"]
        case .rect(rect: let r, radii: let s):
            return ["let \(identifier) = CGPath(roundedRect: \(render(r)), cornerWidth: \(s.width), cornerHeight: \(s.height), transform: nil)"]
        case .lines(between: let p): return []
            //return render(lines: p)
        case .polygon(points: let p): return []
            //return render(polygon: p)
        case .path(from: let p):
            return render(p, identifier: identifier)
        case .compound(paths: let _): return []
        }
    }
    
    func render(_ path: Builder.Path, identifier: String) -> [String] {
        var lines = [String]()
        lines.append("let \(identifier) = CGMutablePath()")
        
        for s in path.segments {
            switch s {
            case .move(let p):
                lines.append("\(identifier).move(to: \(render(p))")
            case .line(let p):
                lines.append("\(identifier).line(to: \(render(p))")
            case .cubic(let p, let cp1, let cp2):
                lines.append("\(identifier).addCurve(to: \(render(p)), control1: \(render(cp1)), control2: \(render(cp2)))")
            case .close:
                lines.append("\(identifier).closeSubpath()")
            }
        }
    
        return lines
    }
    
    func render(_ points: [Provider.Point]) -> String {
        return points.map{render($0)}.joined(separator: ", ")
    }
    
    func render(lines points: [Provider.Point], identifier: String) -> [String] {
        var lines = [String]()
        lines.append("let \(identifier) = CGMutablePath()")
        lines.append("\(identifier).addLines(between: \(render(points)))")
        return lines
    }
    
    func render(polygon points: [Provider.Point], identifier: String) -> [String] {
        var lines = [String]()
        lines.append("let \(identifier) = CGMutablePath()")
        lines.append("\(identifier).addLines(between: \(render(points)))")
        lines.append("\(identifier).closeSubpath()")
        return lines
    }
    

    
//        case ellipse(within: Builder.Rect)
//        case rect(rect: Builder.Rect, radii: Builder.Size)
//        case lines(between: [Builder.Point])
//        case polygon(points: [Builder.Point])
//        case path(from: Builder.Path)
//        case compound(paths: [CodePath])
}

extension Array where Element: Equatable {
    mutating func appendUnqiue(_ element: Iterator.Element) {
        if self.contains(element) == false {
            append(element)
        }
    }
}

//        switch command {
//        case .pushState:
//            ctx.saveGState()
//        case .popState:
//            ctx.restoreGState()
//        case .concatenate(transform: let t):
//            ctx.concatenate(t)
//        case .translate(tx: let x, ty: let y):
//            ctx.translateBy(x: x, y: y)
//        case .scale(sx: let x, sy: let y):
//            ctx.scaleBy(x: x, y: y)
//        case .rotate(angle: let a):
//            ctx.rotate(by: a)
//        case .setFill(color: let c):
//            ctx.setFillColor(c)
//        case .setStroke(color: let c):
//            ctx.setStrokeColor(c)
//        case .setLine(width: let w):
//            ctx.setLineWidth(w)
//        case .setClip(path: let p):
//            ctx.addPath(p)
//            ctx.clip()
//        case .setBlend(mode: let m):
//            ctx.setBlendMode(m)
//        case .stroke(let p):
//            ctx.addPath(p)
//            ctx.strokePath()
//        case .fill(let p):
//            ctx.addPath(p)
//            ctx.fillPath()
//        case .pushTransparencyLayer:
//            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
//        case .popTransparencyLayer:
//            ctx.endTransparencyLayer()
//        }
