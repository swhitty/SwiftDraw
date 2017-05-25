//
//  Renderer.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 25/3/17.
//  Copyright 2017 Simon Whitty
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

protocol RendererTypeProvider {
    associatedtype Color
    associatedtype Path
    associatedtype Transform
    associatedtype Float
    associatedtype Point
    associatedtype Rect
    associatedtype BlendMode
    associatedtype FillRule
    associatedtype LineCap
    associatedtype LineJoin
    associatedtype Image
    
    func createFloat(from float: Builder.Float) -> Float
    func createPoint(from point: Builder.Point) -> Point
    func createRect(from rect: Builder.Rect) -> Rect
    func createColor(from color: Builder.Color) -> Color
    func createBlendMode(from mode: Builder.BlendMode) -> BlendMode
    func createTransform(from transform: Builder.Transform) -> Transform
    func createPath(from path: Builder.Path) -> Path
    func createPath(from subPaths: [Path]) -> Path
    func createFillRule(from rule: Builder.FillRule) -> FillRule
    func createLineCap(from cap: Builder.LineCap) -> LineCap
    func createLineJoin(from join: Builder.LineJoin) -> LineJoin
    func createImage(from image: Builder.Image) -> Image?
    
    func createEllipse(within rect: Rect) -> Path
    func createLine(from origin: Point, to desination: Point) -> Path
    func createLine(between points: [Point]) -> Path
    func createPolygon(between points: [Point]) -> Path
    func createText(from text: String, with font: String, at origin: Point, ofSize pt: Float) -> Path?
    
    func createRect(from rect: Rect, radii: Builder.Size) -> Path
}

protocol Renderer {
    associatedtype Provider: RendererTypeProvider
    
    func perform(_ commands: [RendererCommand<Provider>])
}

enum RendererCommand<T: RendererTypeProvider> {
    case pushState
    case popState
    
    case concatenate(transform: T.Transform)
    case translate(tx: T.Float, ty: T.Float)
    case rotate(angle: T.Float)
    case scale(sx: T.Float, sy: T.Float)

    case setFill(color: T.Color)
    case setStroke(color: T.Color)
    case setLine(width: T.Float)
    case setLineCap(T.LineCap)
    case setLineJoin(T.LineJoin)
    case setLineMiter(limit: T.Float)
    case setClip(path: T.Path)
    case setBlend(mode: T.BlendMode)
    
    case stroke(T.Path)
    case fill(T.Path, rule: T.FillRule)
    
    case draw(image: T.Image)
    
    case pushTransparencyLayer
    case popTransparencyLayer
}
