//
//  Renderer.Code.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 14/6/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

import Foundation

struct LayerTreeTypes: RendererTypes {
    typealias Float = LayerTree.Float
    typealias Point = LayerTree.Point
    typealias Size = LayerTree.Size
    typealias Rect = LayerTree.Rect
    typealias Color = LayerTree.Color
    typealias Path = LayerTree.Shape
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
    
    func createBlendMode(from mode: LayerTree.BlendMode) -> LayerTree.BlendMode {
        return mode
    }
    
    func createTransform(from transform: LayerTree.Transform.Matrix) -> LayerTree.Transform {
        return .matrix(transform)
    }
    
    func createPath(from shape: LayerTree.Shape) -> LayerTree.Shape {
        return shape
    }
    
    func createPath(from subPaths: [LayerTree.Shape]) -> LayerTree.Shape {
        return subPaths.first ?? .path(LayerTree.Path())
    }
    
    func createPath(from text: String, at origin: LayerTree.Point, with attributes: LayerTree.TextAttributes) -> LayerTree.Shape? {
        return .path(LayerTree.Path())
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
}

final class CodeRenderer: Renderer {
    typealias Types = LayerTreeTypes
    
    var state: Stack<State>
    var colors: Defs<LayerTree.Color>
    
    init() {
        state = Stack(root: State())
        colors = Defs<LayerTree.Color>(prefix: "c")
    }
    
    func pushState() {
        state.push(state.top)
    }
    
    func popState() {
        state.pop()
    }
    
    func pushTransparencyLayer() {}
    func popTransparencyLayer() {}
    
    func concatenate(transform: LayerTree.Transform) {}
    func translate(tx: LayerTree.Float, ty: LayerTree.Float) {}
    func rotate(angle: LayerTree.Float) {}
    func scale(sx: LayerTree.Float, sy: LayerTree.Float) {}
    
    func setFill(color: LayerTree.Color) {
        guard color != state.top.fillColor else { return }
        state.top.fillColor = color
        
        let def = colors.define(color)
        
        if !def.isExisting {
             print("let \(def.identifier) = Color()")
        }
        
        print("ctx.setFillColor(\(def.identifier))")
    }
    
    func setStroke(color: LayerTree.Color) {}
    func setLine(width: LayerTree.Float) {}
    func setLine(cap: LayerTree.LineCap) {}
    func setLine(join: LayerTree.LineJoin) {}
    func setLine(miterLimit: LayerTree.Float) {}
    func setClip(path: LayerTree.Shape) {}
    func setAlpha(_ alpha: LayerTree.Float) {}
    func setBlend(mode: LayerTree.BlendMode) {}
    
    func stroke(path: LayerTree.Shape) {}
    func fill(path: LayerTree.Shape, rule: LayerTree.FillRule) {}
    func draw(image: LayerTree.Image) {}
}

extension CodeRenderer {

    struct State {
        var alpha: LayerTree.Float?
        var fillColor: LayerTree.Color?
        var strokeColor: LayerTree.Color?
        var lineWidth: LayerTree.Float?
        var lineCap: LayerTree.LineCap?
        var lineJoin: LayerTree.LineJoin?
        var lineMiterLimit: LayerTree.Float?
        var blendMode: LayerTree.BlendMode?
        var clipPath: LayerTree.Shape?
        var path: LayerTree.Shape?
    }
}

extension CodeRenderer {
    
    struct Defs<Element: Hashable> {
        private(set) var storage: [Element: Int]
        private(set) var prefix: String
        
        init(prefix: String) {
            self.prefix = prefix
            self.storage = [Element: Int]()
        }
        
        func identifier(for index: Int) -> String {
            guard index > 0 else {
                return prefix
            }
            
            return "\(prefix)\(index)"
        }
        
        mutating func define(_ element: Element) -> (identifier: String, isExisting: Bool) {
            guard let existingId = storage[element] else {
                let newId = storage.count
                storage[element] = newId
                return (identifier: identifier(for: newId), isExisting: false)
            }
            
            return (identifier: identifier(for: existingId), isExisting: true)
        }
    }
}
