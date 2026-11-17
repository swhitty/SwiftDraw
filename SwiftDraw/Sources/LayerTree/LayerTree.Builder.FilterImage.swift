//
//  LayerTree.Builder.FilterImage.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 17/11/26.
//  Copyright 2026 Simon Whitty
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

    /// The key of an element being drawn by `<feImage>`: reaching it again while it is built is a cycle.
    struct FilterImageKey: Hashable {
        var element: ObjectIdentifier
    }

    /// Filter Effects 1 §9.15: the elements the `<feImage>` primitives of a filter reference, keyed by the
    /// index of the primitive. Each is built as a `<use>` would draw it, in the user space of the element the
    /// filter applies to; the layer tree places it in the primitive subregion. An image `href`, a missing or
    /// non-graphics element, and a reference back to an element being built (the filtered element itself, or
    /// an ancestor) have no entry: the primitive is then an image or transparent black.
    func makeFilterImages(for primitives: [LayerTree.FilterPrimitive]) -> [Int: LayerTree.Layer] {
        var images = [Int: LayerTree.Layer]()
        for (index, primitive) in primitives.enumerated() {
            guard case .image(let image) = primitive.effect,
                let element = referencedElement(of: image)
            else { continue }
            let layer = building(FilterImageKey(element: ObjectIdentifier(element)), cycle: nil) {
                () -> LayerTree.Layer? in
                buildingContents {
                    makeLayer(from: element, inheriting: makeInheritedState(from: ancestors(of: element)))
                }
            }
            images[index] = layer
        }
        return images
    }

    /// The element an `href` of the form `#id` references; nil for an image or a missing element.
    func referencedElement(of image: DOM.Filter.Image) -> DOM.GraphicsElement? {
        guard let href = image.href,
            href.absoluteString.hasPrefix("#"),
            let id = href.fragmentID, !id.isEmpty
        else { return nil }
        return svg.firstGraphicsElement(with: id)
    }

    /// The containers of `element` within the document, outermost first, whose presentation attributes it
    /// inherits: from the root `<svg>`, through the top-level elements of `<defs>` with an id for an element
    /// within one (the DOM keeps no others there); the root alone when it is not found.
    func ancestors(of element: DOM.GraphicsElement) -> [DOM.GraphicsElement] {
        let key = ObjectIdentifier(element)
        if let cached = recursion.ancestors[key] { return cached }
        var path = [DOM.GraphicsElement]()
        func find(in container: any ContainerElement) -> Bool {
            for child in container.childElements {
                if child === element { return true }
                if let inner = child as? any ContainerElement {
                    path.append(child)
                    if find(in: inner) { return true }
                    path.removeLast()
                }
            }
            return false
        }
        var result: [DOM.GraphicsElement] = [svg]
        if find(in: svg) {
            result += path
        } else {
            for root in svg.defs.elements.values where root !== element {
                guard let container = root as? any ContainerElement else { continue }
                path = [root]
                if find(in: container) {
                    result += path
                    break
                }
            }
        }
        recursion.ancestors[key] = result
        return result
    }
}
