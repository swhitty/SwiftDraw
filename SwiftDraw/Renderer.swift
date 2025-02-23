//
//  Renderer.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 4/6/17.
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

protocol RendererTypes {
    associatedtype Float: Equatable
    associatedtype Point: Equatable
    associatedtype Size: Equatable
    associatedtype Rect: Equatable
    associatedtype Color: Equatable
    associatedtype Gradient: Equatable
    associatedtype Mask: Equatable
    associatedtype Path: Equatable
    associatedtype Pattern: Equatable
    associatedtype Transform: Equatable
    associatedtype BlendMode: Equatable
    associatedtype FillRule: Equatable
    associatedtype LineCap: Equatable
    associatedtype LineJoin: Equatable
    associatedtype Image: Equatable
}

protocol RendererTypeProvider {
    associatedtype Types: RendererTypes

    func createFloat(from float: LayerTree.Float) -> Types.Float
    func createPoint(from point: LayerTree.Point) -> Types.Point
    func createSize(from size: LayerTree.Size) -> Types.Size
    func createRect(from rect: LayerTree.Rect) -> Types.Rect
    func createColor(from color: LayerTree.Color) -> Types.Color
    func createGradient(from gradient: LayerTree.Gradient) -> Types.Gradient
    func createBlendMode(from mode: LayerTree.BlendMode) -> Types.BlendMode
    func createTransform(from transform: LayerTree.Transform.Matrix) -> Types.Transform
    func createPath(from shape: LayerTree.Shape) -> Types.Path
    func createPath(from subPaths: [Types.Path]) -> Types.Path
    func createPath(from text: String, at origin: LayerTree.Point, with attributes: LayerTree.TextAttributes) -> Types.Path?
    func createPattern(from pattern: LayerTree.Pattern, contents: [RendererCommand<Types>]) -> Types.Pattern
    func createFillRule(from rule: LayerTree.FillRule) -> Types.FillRule
    func createLineCap(from cap: LayerTree.LineCap) -> Types.LineCap
    func createLineJoin(from join: LayerTree.LineJoin) -> Types.LineJoin
    func createImage(from image: LayerTree.Image) -> Types.Image?
    func createSize(from image: Types.Image) -> LayerTree.Size

    func getBounds(from shape: LayerTree.Shape) -> LayerTree.Rect
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
    func setFill(pattern: Types.Pattern)
    func setStroke(color: Types.Color)
    func setLine(width: Types.Float)
    func setLine(cap: Types.LineCap)
    func setLine(join: Types.LineJoin)
    func setLine(miterLimit: Types.Float)
    func setClip(path: Types.Path, rule: Types.FillRule)
    func setClip(mask: Types.Mask, frame: Types.Rect)
    func setAlpha(_ alpha: Types.Float)
    func setBlend(mode: Types.BlendMode)

    func stroke(path: Types.Path)
    func clipStrokeOutline(path: Types.Path)
    func fill(path: Types.Path, rule: Types.FillRule)
    func draw(image: Types.Image, in rect: Types.Rect)
    func draw(linear gradient: Types.Gradient, from start: Types.Point, to end: Types.Point)
    func draw(radial gradient: Types.Gradient, startCenter: Types.Point, startRadius: Types.Float, endCenter: Types.Point, endRadius: Types.Float)
}

extension Renderer {
    func perform(_ command: RendererCommand<Types>) {
        switch command {
        case .pushState:
            pushState()
        case .popState:
            popState()
        case .pushTransparencyLayer:
            pushTransparencyLayer()
        case .popTransparencyLayer:
            popTransparencyLayer()
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
        case .setFillPattern(let p):
            setFill(pattern: p)
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
        case .setClip(path: let p, rule: let r):
            setClip(path: p, rule: r)
        case .setClipMask(let m, frame: let f):
            setClip(mask: m, frame: f)
        case .setAlpha(let a):
            setAlpha(a)
        case .setBlend(mode: let m):
            setBlend(mode: m)
        case .stroke(let p):
            stroke(path: p)
        case .clipStrokeOutline(let p):
            clipStrokeOutline(path: p)
        case .fill(let p, let r):
            fill(path: p, rule: r)
        case .draw(image: let i, in: let r):
            draw(image: i, in: r)
        case .drawLinearGradient(let g, let start, let end):
            draw(linear: g, from: start, to: end)
        case let .drawRadialGradient(g, startCenter, startRadius, endCenter, endRadius):
            draw(radial: g, startCenter: startCenter, startRadius: startRadius, endCenter: endCenter, endRadius: endRadius)
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
    case setFillPattern(Types.Pattern)
    case setStroke(color: Types.Color)
    case setLine(width: Types.Float)
    case setLineCap(Types.LineCap)
    case setLineJoin(Types.LineJoin)
    case setLineMiter(limit: Types.Float)
    case setClip(path: Types.Path, rule: Types.FillRule)
    case setClipMask(Types.Mask, frame: Types.Rect)
    case setAlpha(Types.Float)
    case setBlend(mode: Types.BlendMode)

    case stroke(Types.Path)
    case clipStrokeOutline(Types.Path)
    case fill(Types.Path, rule: Types.FillRule)

    case draw(image: Types.Image, in: Types.Rect)
    case drawLinearGradient(Types.Gradient, from: Types.Point, to: Types.Point)
    case drawRadialGradient(Types.Gradient, startCenter: Types.Point, startRadius: Types.Float, endCenter: Types.Point, endRadius: Types.Float)

    case pushTransparencyLayer
    case popTransparencyLayer
}


#if canImport(CoreGraphics)
import CoreGraphics

extension RendererCommand<CGTypes>: Equatable { }
extension RendererCommand<CGTypes>: Hashable { }
#endif
