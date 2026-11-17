//
//  Parser.XML.ReferencedContainers.swift
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

import Foundation

extension XMLParser {

    /// Every `<mask>`, `<pattern>` and `<marker>` in the document, wherever it is, including
    /// inside one another, in document order.
    struct ReferencedContainers {
        var masks = [DOM.Mask]()
        var patterns = [DOM.Pattern]()
        var markers = [DOM.Marker]()
        var documentOrder = [String: Int]()
    }

    /// The XML ancestors of the element being walked, innermost first. A linked list, so the walk
    /// shares it between siblings, and the ancestors are only parsed for the elements that inherit.
    final class Ancestry {
        let element: XML.Element
        let parent: Ancestry?

        init(element: XML.Element, parent: Ancestry?) {
            self.element = element
            self.parent = parent
        }
    }

    func parseReferencedContainers(
        _ e: XML.Element,
        ancestry: Ancestry,
        into containers: inout ReferencedContainers
    ) throws {
        for n in e.children {
            try appendReferencedContainer(n, ancestry: ancestry, into: &containers)
            guard !n.children.isEmpty else { continue }
            let pushed = pushViewport(of: n)
            defer { if pushed { popViewport() } }
            // masks, patterns and markers may be defined inside one another
            try parseReferencedContainers(n, ancestry: Ancestry(element: n, parent: ancestry), into: &containers)
        }
    }

    /// Kept out of line so the recursive walk keeps a small frame (see `appendSkippingInvalid`).
    @inline(never)
    private func appendReferencedContainer(
        _ n: XML.Element,
        ancestry: Ancestry,
        into containers: inout ReferencedContainers
    ) throws {
        switch n.name {
        case "mask":
            let count = containers.masks.count
            try appendSkippingInvalid(&containers.masks, n, parseMask)
            if containers.masks.count > count {
                let mask = containers.masks[count]
                mask.ancestors = makeAncestors(ancestry)
                recordOrder(of: mask.id, in: &containers)
            }
        case "pattern":
            // a pattern without an id can never be referenced; skip it rather than fail
            guard n.attributes["id"] != nil else { return }
            let count = containers.patterns.count
            try appendSkippingInvalid(&containers.patterns, n, parsePattern)
            if containers.patterns.count > count {
                // a pattern has no presentation attributes of its own, but its contents inherit them
                containers.patterns[count].ancestors = makeAncestors(Ancestry(element: n, parent: ancestry))
                recordOrder(of: containers.patterns[count].id, in: &containers)
            }
        case "marker":
            // a marker without an id can never be referenced; skip it rather than fail
            guard n.attributes["id"] != nil else { return }
            let count = containers.markers.count
            try appendSkippingInvalid(&containers.markers, n, parseMarker)
            if containers.markers.count > count {
                let marker = containers.markers[count]
                marker.ancestors = makeAncestors(ancestry)
                recordOrder(of: marker.id, in: &containers)
            }
        default:
            break
        }
    }

    private func recordOrder(of id: String?, in containers: inout ReferencedContainers) {
        guard let id, containers.documentOrder[id] == nil else { return }
        containers.documentOrder[id] = containers.documentOrder.count
    }

    /// Elements holding the presentation attributes of each ancestor, outermost first: the
    /// contents of masks, patterns and markers inherit from these, not from the referencing element.
    private func makeAncestors(_ ancestry: Ancestry?) -> [DOM.GraphicsElement] {
        var ancestors = [DOM.GraphicsElement]()
        var next = ancestry
        while let current = next {
            let holder = DOM.Group()
            holder.class = current.element.attributes["class"]
            holder.attributes = (try? parsePresentationAttributes(current.element)) ?? DOM.PresentationAttributes()
            applyStyle(of: current.element, to: holder)
            ancestors.append(holder)
            next = current.parent
        }
        return ancestors.reversed()
    }
}
