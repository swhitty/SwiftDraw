//
//  Renderer.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 4/6/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

import Foundation

protocol RendererTypes {
    associatedtype Float
    associatedtype Point
    associatedtype Size
    associatedtype Rect
    associatedtype Color
    associatedtype Path
    associatedtype Transform
    associatedtype BlendMode
    associatedtype FillRule
    associatedtype LineCap
    associatedtype LineJoin
    associatedtype Image
}

protocol RendererTypeProvider {
    associatedtype Types: RendererTypes
    
    func createFloat(from float: LayerTree.Float) -> Types.Float
    func createPoint(from point: LayerTree.Point) -> Types.Point
    func createSize(from size: LayerTree.Size) -> Types.Size
    func createRect(from rect: LayerTree.Rect) -> Types.Rect
    func createColor(from color: LayerTree.Color) -> Types.Color
    func createBlendMode(from mode: LayerTree.BlendMode) -> Types.BlendMode
    func createTransform(from transform: LayerTree.Transform) -> Types.Transform
    func createPath(from shape: LayerTree.Shape) -> Types.Path
    func createPath(from subPaths: [Types.Path]) -> Types.Path
    func createPath(from text: String, at origin: LayerTree.Point, with attributes: LayerTree.TextAttributes) -> Types.Path?
    func createFillRule(from rule: LayerTree.FillRule) -> Types.FillRule
    func createLineCap(from cap: LayerTree.LineCap) -> Types.LineCap
    func createLineJoin(from join: LayerTree.LineJoin) -> Types.LineJoin
    func createImage(from image: LayerTree.Image) -> Types.Image?
}

protocol Renderer {
    associatedtype Types: RendererTypes
    
    func pushState()
    func popState()
    func pushTransparencyLayer()
    func popTransparencyLayer()
    
    func concatenate(transform: Types.Transform)
    func translate(tx: Types.Float, ty: Types.Float)
    func rotate(angle: Types.Float)
    func scale(sx: Types.Float, sy: Types.Float)
    
    func setFill(color: Types.Color)
    func setStroke(color: Types.Color)
    func setLine(width: Types.Float)
    func setLine(cap: Types.LineCap)
    func setLine(join: Types.LineJoin)
    func setLine(miterLimit: Types.Float)
    func setClip(path: Types.Path)
    func setAlpha(_ alpha: Types.Float)
    func setBlend(mode: Types.BlendMode)
    
    func stroke(path: Types.Path)
    func fill(path: Types.Path, rule: Types.FillRule)
    func draw(image: Types.Image)
}

extension Renderer {
    func perform(_ command: RendererCommand<Types>) {
        switch command {
        case .pushState:
            pushState()
        case .popState:
            popState()
        case .concatenate(transform: let t):
            concatenate(transform: t)
        case .translate(tx: let x, ty: let y):
            translate(tx: x, ty: y)
        case .scale(sx: let x, sy: let y):
            scale(sx: x, sy: y)
        case .rotate(angle: let a):
            rotate(angle: a)
        case .setFill(color: let c):
            setFill(color: c)
        case .setStroke(color: let c):
            setStroke(color: c)
        case .setLine(width: let w):
            setLine(width: w)
        case .setLineCap(let c):
            setLine(cap: c)
        case .setLineJoin(let j):
            setLine(join: j)
        case .setLineMiter(limit: let l):
            setLine(miterLimit: l)
        case .setClip(path: let p):
            setClip(path: p)
        case .setAlpha(let a):
            setAlpha(a)
        case .setBlend(mode: let m):
            setBlend(mode: m)
        case .stroke(let p):
            stroke(path: p)
        case .fill(let p, let r):
            fill(path: p, rule: r)
        case .draw(image: let i):
            draw(image: i)
        case .pushTransparencyLayer:
            pushTransparencyLayer()
        case .popTransparencyLayer:
            popTransparencyLayer()
        }
    }
    
    func perform(_ commands: [RendererCommand<Types>]) {
        for cmd in commands {
            perform(cmd)
        }
    }
}

enum RendererCommand<Types: RendererTypes> {
    case pushState
    case popState
    
    case concatenate(transform: Types.Transform)
    case translate(tx: Types.Float, ty: Types.Float)
    case rotate(angle: Types.Float)
    case scale(sx: Types.Float, sy: Types.Float)
    
    case setFill(color: Types.Color)
    case setStroke(color: Types.Color)
    case setLine(width: Types.Float)
    case setLineCap(Types.LineCap)
    case setLineJoin(Types.LineJoin)
    case setLineMiter(limit: Types.Float)
    case setClip(path: Types.Path)
    case setAlpha(Types.Float)
    case setBlend(mode: Types.BlendMode)
    
    case stroke(Types.Path)
    case fill(Types.Path, rule: Types.FillRule)
    
    case draw(image: Types.Image)
    
    case pushTransparencyLayer
    case popTransparencyLayer
}
