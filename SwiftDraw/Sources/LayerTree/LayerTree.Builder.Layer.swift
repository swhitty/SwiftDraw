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

    func makeShapeContents(from shape: LayerTree.Shape, with state: State) -> LayerTree.Layer.Contents {
        let bounds = shape.bounds
        let stroke = makeStrokeAttributes(with: state, bounds: bounds)
        let fill = makeFillAttributes(with: state, bounds: bounds)
        return .shape(shape, stroke, fill)
    }

    func makeUseLayerContents(from use: DOM.Use, with state: State) throws -> LayerTree.Layer.Contents {
        guard
            let id = use.href.fragmentID,
            let element = svg.firstGraphicsElement(with: id) else {
            throw LayerTree.Error.invalid("missing referenced element: \(use.href)")
        }

        // A use inside itself draws nothing
        let l = building(ObjectIdentifier(element), cycle: LayerTree.Layer()) {
            makeLayer(from: element, inheriting: state)
        }

        if let symbol = element as? DOM.Symbol {
            return .layer(makeSymbolLayer(l, symbol: symbol, use: use))
        }

        let x = use.x ?? 0.0
        let y = use.y ?? 0.0

        if x != 0 || y != 0 {
            l.transform.insert(.translate(tx: x, ty: y), at: 0)
        }

        return .layer(l)
    }

    /// Places the contents of a `<symbol>` in the viewport its `<use>` establishes (SVG 2 §5.6):
    /// the `<use>`'s x, y, width and height, mapped through the symbol's viewBox and preserveAspectRatio.
    func makeSymbolLayer(_ contents: LayerTree.Layer, symbol: DOM.Symbol, use: DOM.Use) -> LayerTree.Layer {
        let viewport = makeSymbolViewport(for: use)
        // SVG 2 §5.6: a zero (or negative) width or height disables rendering
        guard viewport.width > 0, viewport.height > 0,
              viewport.width.isFinite, viewport.height.isFinite else {
            return LayerTree.Layer()
        }

        let transform = Self.makeSymbolTransform(symbol, x: use.x, y: use.y,
                                                 width: viewport.width, height: viewport.height)
        var clip = [LayerTree.ClipShape]()
        if symbol.clipsToViewport {
            let bounds = Self.makeSymbolViewportClip(symbol, width: viewport.width, height: viewport.height)
            clip = [LayerTree.ClipShape(shape: .rect(within: bounds, radii: .zero), transform: .identity)]
        }

        // layer.clip applies after layer.transform, in the viewBox space of the contents.
        // The symbol's own transform or clip-path would mix with the viewport's: keep them on an inner layer.
        guard contents.transform.isEmpty, contents.clip.isEmpty else {
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

    /// The width and height of the viewport a `<use>` gives a symbol. The parser defaults them to 100%
    /// of the enclosing viewport; a `<use>` built without one falls back to the root viewport.
    func makeSymbolViewport(for use: DOM.Use) -> (width: DOM.Coordinate, height: DOM.Coordinate) {
        let root = svg.viewBox.map { (width: $0.width, height: $0.height) } ?? (width: svg.width, height: svg.height)
        return (use.width ?? root.width, use.height ?? root.height)
    }

    /// The viewport mapping of a symbol. With `refX` / `refY` (SVG 2) that point of the viewBox
    /// lands on x, y and the alignment of `preserveAspectRatio` no longer applies.
    static func makeSymbolTransform(_ symbol: DOM.Symbol, x: DOM.Coordinate?, y: DOM.Coordinate?,
                                    width: DOM.Coordinate, height: DOM.Coordinate) -> [LayerTree.Transform] {
        guard symbol.refX != nil || symbol.refY != nil else {
            return makeTransform(x: x, y: y, viewBox: symbol.viewBox, width: width, height: height,
                                 preserveAspectRatio: symbol.preserveAspectRatio)
        }
        let fit = makeViewBoxFit(viewBox: symbol.viewBox, width: width, height: height,
                                 preserveAspectRatio: symbol.preserveAspectRatio)
        var transform: [LayerTree.Transform] = [.translate(tx: x ?? 0, ty: y ?? 0)]
        if fit.sx != 1 || fit.sy != 1 {
            transform.append(.scale(sx: fit.sx, sy: fit.sy))
        }
        transform.append(.translate(tx: -(symbol.refX ?? 0), ty: -(symbol.refY ?? 0)))
        return transform.filter { $0 != .translate(tx: 0, ty: 0) }
    }

    /// The viewport of a symbol in the viewBox space of its contents, where `overflow: hidden` clips.
    static func makeSymbolViewportClip(_ symbol: DOM.Symbol, width: DOM.Coordinate, height: DOM.Coordinate) -> LayerTree.Rect {
        guard symbol.refX != nil || symbol.refY != nil else {
            return makeViewportClip(viewBox: symbol.viewBox, width: width, height: height,
                                    preserveAspectRatio: symbol.preserveAspectRatio)
        }
        let fit = makeViewBoxFit(viewBox: symbol.viewBox, width: width, height: height,
                                 preserveAspectRatio: symbol.preserveAspectRatio)
        return LayerTree.Rect(x: symbol.refX ?? 0, y: symbol.refY ?? 0,
                              width: LayerTree.Float(width) / fit.sx,
                              height: LayerTree.Float(height) / fit.sy)
    }

    func makeTextContents(from text: DOM.Text, with state: State) -> LayerTree.Layer.Contents {
        var point = Point(text.x ?? 0, text.y ?? 0)
        // state already holds the cascaded font-family, font-size, font-weight, font-style and text-anchor
        let att = makeTextAttributes(with: state)
        let offset = Self.makeOffset(for: text.value, with: att)
        point.x += offset.width
        point.y += offset.height

        return .text(text.value, point, att)
    }

    static func makeImageContents(from image: DOM.Image) throws -> LayerTree.Layer.Contents {
        guard
            let decoded = image.href.decodedData,
            var im = LayerTree.Image(mimeType: decoded.mimeType, data: decoded.data) else {
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
