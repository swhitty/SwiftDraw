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

import Foundation

extension LayerTree.Builder {

    func makeShapeContents(from shape: LayerTree.Shape, with state: State) -> LayerTree.Layer.Contents {
        let stroke = makeStrokeAttributes(with: state)
        let fill = makeFillAttributes(with: state)
        return .shape(shape, stroke, fill)
    }

    func makeUseLayerContents(from use: DOM.Use, with state: State) throws -> LayerTree.Layer.Contents {
        guard
            let id = use.href.fragmentID,
            let element = svg.firstGraphicsElement(with: id) else {
            throw LayerTree.Error.invalid("missing referenced element: \(use.href)")
        }

        let l = makeLayer(from: element, inheriting: state)
        let x = use.x ?? 0.0
        let y = use.y ?? 0.0

        if x != 0 || y != 0 {
            l.transform.insert(.translate(tx: x, ty: y), at: 0)
        }

        return .layer(l)
    }

    static func makeTextContents(from text: DOM.Text, with state: State) -> LayerTree.Layer.Contents {
        var point = Point(text.x ?? 0, text.y ?? 0)
        var att = makeTextAttributes(with: state)
        att.fontName = text.attributes.fontFamily ?? att.fontName
        att.size = text.attributes.fontSize ?? att.size
        att.anchor = text.attributes.textAnchor ?? att.anchor
        point.x += makeXOffset(for: text.value, with: att)
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

        return .image(im)
    }
}
