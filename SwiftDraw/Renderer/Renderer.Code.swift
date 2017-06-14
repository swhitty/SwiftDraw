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
    
    func pushState() {}
    func popState() {}
    func pushTransparencyLayer() {}
    func popTransparencyLayer() {}
    
    func concatenate(transform: LayerTree.Transform) {}
    func translate(tx: LayerTree.Float, ty: LayerTree.Float) {}
    func rotate(angle: LayerTree.Float) {}
    func scale(sx: LayerTree.Float, sy: LayerTree.Float) {}
    
    func setFill(color: LayerTree.Color) {}
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
