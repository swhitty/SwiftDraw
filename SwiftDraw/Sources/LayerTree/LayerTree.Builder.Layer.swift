//
//  LayerTree.Builder.Layer.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 21/11/18.
//  Copyright 2020 WhileLoop Pty Ltd. All rights reserved.
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

import SwiftDrawDOM
import Foundation

extension LayerTree.Builder {

    /// - Parameter boundingBox: the box objectBoundingBox paint servers resolve against, when it is not
    ///   the shape's own (each run of a text uses the whole text's)
    func makeShapeContents(
        from shape: LayerTree.Shape,
        with state: State,
        boundingBox: LayerTree.Rect? = nil
    ) -> LayerTree.Layer.Contents {
        let bounds = boundingBox ?? shape.bounds
        var stroke = makeStrokeAttributes(with: state, bounds: bounds)
        var fill = makeFillAttributes(with: state, bounds: bounds)
        stroke.boundingBox = boundingBox
        fill.boundingBox = boundingBox
        return .shape(shape, stroke, fill)
    }

    func makeUseLayerContents(from use: DOM.Use, with state: State) throws -> LayerTree.Layer.Contents {
        guard
            let id = use.href.fragmentID,
            let element = svg.firstGraphicsElement(with: id)
        else {
            throw LayerTree.Error.invalid("missing referenced element: \(use.href)")
        }

        // A use that draws itself again, directly or through other uses, draws nothing (as Chrome and resvg)
        guard !isRecursive(use) else { return .layer(LayerTree.Layer()) }

        // and the guard bounds uses reached again through masks, patterns and markers
        let l = building(ObjectIdentifier(use), cycle: LayerTree.Layer()) {
            expanding(use) { makeLayer(from: element, inheriting: state) }
        }

        if let symbol = element as? DOM.Symbol {
            return .layer(makeSymbolLayer(l, symbol: symbol, use: use))
        }

        let x = use.x ?? 0.0
        let y = use.y ?? 0.0

        if let nested = element as? DOM.SVG {
            return .layer(makeNestedSVGLayer(l, svg: nested, use: use))
        }

        if x != 0 || y != 0 {
            l.transform.insert(.translate(tx: x, ty: y), at: 0)
        }

        return .layer(l)
    }

    /// Places an `<svg>` drawn by a `<use>` in its viewport (SVG 2 §5.6): the `<use>`'s width and
    /// height replace the `<svg>`'s own when set, with its x, y, viewBox and preserveAspectRatio,
    /// clipped to the viewport as any nested `<svg>`, and offset by the `<use>`'s x, y.
    func makeNestedSVGLayer(_ contents: LayerTree.Layer, svg nested: DOM.SVG, use: DOM.Use) -> LayerTree.Layer {
        let width = use.width ?? nested.width
        let height = use.height ?? nested.height
        guard width > 0, height > 0, width.isFinite, height.isFinite else {
            return LayerTree.Layer()
        }

        var transform = [LayerTree.Transform]()
        if (use.x ?? 0) != 0 || (use.y ?? 0) != 0 {
            transform.append(.translate(tx: use.x ?? 0, ty: use.y ?? 0))
        }
        // as a nested <svg> in the document, its own transform is replaced by the viewport mapping
        transform += Self.makeTransform(
            x: nested.x,
            y: nested.y,
            viewBox: nested.viewBox,
            width: width,
            height: height,
            preserveAspectRatio: nested.preserveAspectRatio
        )
        let bounds = Self.makeViewportClip(
            viewBox: nested.viewBox,
            width: width,
            height: height,
            preserveAspectRatio: nested.preserveAspectRatio
        )
        let clip = [LayerTree.ClipShape(shape: .rect(within: bounds, radii: .zero), transform: .identity)]

        // layer.clip applies after layer.transform; an <svg>'s own clip-path stays on an inner layer
        guard contents.clip.isEmpty else {
            contents.transform = []
            let outer = LayerTree.Layer()
            outer.transform = transform
            outer.clip = clip
            outer.contents = [.layer(contents)]
            return outer
        }
        contents.transform = transform
        contents.clip = clip
        return contents
    }

    /// Places the contents of a `<symbol>` in the viewport its `<use>` establishes (SVG 2 §5.6),
    /// mapped through the symbol's viewBox and preserveAspectRatio.
    func makeSymbolLayer(_ contents: LayerTree.Layer, symbol: DOM.Symbol, use: DOM.Use) -> LayerTree.Layer {
        let viewport = makeSymbolViewport(for: use, symbol: symbol)
        // SVG 2 §5.6: a zero (or negative) width or height disables rendering
        guard viewport.width > 0, viewport.height > 0,
            viewport.width.isFinite, viewport.height.isFinite
        else {
            return LayerTree.Layer()
        }

        // SVG 1.1 has no transform on <symbol>; WebKit and resvg ignore it, so it is dropped here too
        contents.transform = []
        let transform = Self.makeSymbolTransform(
            symbol,
            x: viewport.x,
            y: viewport.y,
            width: viewport.width,
            height: viewport.height
        )
        var clip = [LayerTree.ClipShape]()
        if symbol.clipsToViewport {
            let bounds = Self.makeSymbolViewportClip(symbol, width: viewport.width, height: viewport.height)
            clip = [LayerTree.ClipShape(shape: .rect(within: bounds, radii: .zero), transform: .identity)]
        }

        // layer.clip applies after layer.transform, in the viewBox space of the contents.
        // The symbol's own clip-path would mix with the viewport's: keep it on an inner layer.
        guard contents.clip.isEmpty else {
            let outer = LayerTree.Layer()
            outer.transform = transform
            outer.clip = clip
            outer.contents = [.layer(contents)]
            return outer
        }
        contents.transform = transform
        contents.clip = clip
        return contents
    }

    /// The viewport a `<use>` gives a symbol (SVG 2 §5.6): positioned at the `<use>`'s x, y plus the
    /// symbol's own, sized by the `<use>`'s width and height, else the symbol's, else 100% of the
    /// viewport containing the `<use>` (the root viewport for a `<use>` built without one).
    func makeSymbolViewport(
        for use: DOM.Use,
        symbol: DOM.Symbol
    ) -> (x: DOM.Coordinate, y: DOM.Coordinate, width: DOM.Coordinate, height: DOM.Coordinate) {
        let root = svg.viewBox.map { (width: $0.width, height: $0.height) } ?? (width: svg.width, height: svg.height)
        let enclosing = use.viewport.map { (width: $0.width, height: $0.height) } ?? root
        return (
            (use.x ?? 0) + (symbol.x ?? 0),
            (use.y ?? 0) + (symbol.y ?? 0),
            use.width ?? symbol.width ?? enclosing.width,
            use.height ?? symbol.height ?? enclosing.height
        )
    }

    /// The viewport mapping of a symbol. With `refX` / `refY` (SVG 2) that point of the viewBox
    /// lands on x, y and the alignment of `preserveAspectRatio` no longer applies.
    static func makeSymbolTransform(
        _ symbol: DOM.Symbol,
        x: DOM.Coordinate?,
        y: DOM.Coordinate?,
        width: DOM.Coordinate,
        height: DOM.Coordinate
    ) -> [LayerTree.Transform] {
        guard symbol.refX != nil || symbol.refY != nil else {
            return makeTransform(
                x: x,
                y: y,
                viewBox: symbol.viewBox,
                width: width,
                height: height,
                preserveAspectRatio: symbol.preserveAspectRatio
            )
        }
        let fit = makeViewBoxFit(
            viewBox: symbol.viewBox,
            width: width,
            height: height,
            preserveAspectRatio: symbol.preserveAspectRatio
        )
        var transform: [LayerTree.Transform] = [.translate(tx: x ?? 0, ty: y ?? 0)]
        if fit.sx != 1 || fit.sy != 1 {
            transform.append(.scale(sx: fit.sx, sy: fit.sy))
        }
        transform.append(.translate(tx: -(symbol.refX ?? 0), ty: -(symbol.refY ?? 0)))
        return transform.filter { $0 != .translate(tx: 0, ty: 0) }
    }

    /// The viewport of a symbol in the viewBox space of its contents, where `overflow: hidden` clips.
    static func makeSymbolViewportClip(
        _ symbol: DOM.Symbol,
        width: DOM.Coordinate,
        height: DOM.Coordinate
    ) -> LayerTree.Rect {
        guard symbol.refX != nil || symbol.refY != nil else {
            return makeViewportClip(
                viewBox: symbol.viewBox,
                width: width,
                height: height,
                preserveAspectRatio: symbol.preserveAspectRatio
            )
        }
        let fit = makeViewBoxFit(
            viewBox: symbol.viewBox,
            width: width,
            height: height,
            preserveAspectRatio: symbol.preserveAspectRatio
        )
        return LayerTree.Rect(
            x: symbol.refX ?? 0,
            y: symbol.refY ?? 0,
            width: LayerTree.Float(width) / fit.sx,
            height: LayerTree.Float(height) / fit.sy
        )
    }

    /// Whether text with `state` paints more than a solid fill: a paint server fill, or any stroke.
    func needsOutlines(for state: State) -> Bool {
        if case .url = resolveFallback(state.fill) {
            return true
        }
        guard state.strokeWidth > 0 else { return false }
        switch resolveFallback(state.stroke) {
        case .url:
            return true
        case .color(let color):
            return LayerTree.Color.create(from: color, current: state.color)
                .withAlpha(state.strokeOpacity).maybeNone() != .none
        case .urlWithFallback:
            return false
        }
    }

    static func makeImageContents(from image: DOM.Image) throws -> LayerTree.Layer.Contents {
        guard
            let decoded = image.href.decodedData,
            var im = LayerTree.Image(mimeType: decoded.mimeType, data: decoded.data)
        else {
            throw LayerTree.Error.invalid("Cannot decode image")
        }

        im.origin.x = LayerTree.Float(image.x ?? 0)
        im.origin.y = LayerTree.Float(image.y ?? 0)
        im.width = image.width.map { LayerTree.Float($0) }
        im.height = image.height.map { LayerTree.Float($0) }
        im.preserveAspectRatio = image.preserveAspectRatio ?? .default

        return .image(im)
    }
}
