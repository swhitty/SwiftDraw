//
//  LayerTree.Builder.Clip.swift
//  SwiftDraw
//
//  Created by Misoservices on 8/10/26.
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

    /// What an element's `clip-path` resolves to (SVG 1.1 §14.3.5).
    enum Clip {
        /// A union of shapes sharing one clip-rule, applied with a single `setClip`.
        case shapes([LayerTree.ClipShape], LayerTree.FillRule)
        /// Geometry one clipping path cannot express (text, mixed clip-rules, a `clip-path` on the
        /// `<clipPath>` itself): drawn opaque white and applied as an alpha mask.
        case mask(LayerTree.Layer)
    }

    /// A shape or text inside a `<clipPath>`, with the transform from its own coordinates to the
    /// clip path's content coordinates and the clip-rule it resolves to.
    struct ClipMember {
        var element: DOM.GraphicsElement
        var transform: LayerTree.Transform.Matrix
        var rule: LayerTree.FillRule
    }

    func makeClip(for element: DOM.GraphicsElement) -> Clip? {
        let attributes = DOM.presentationAttributes(for: element, styles: svg.styles)
        guard let clipID = attributes.clipPath?.fragmentID else { return nil }
        return makeClip(id: clipID, bounds: { makeBoundingBox(for: element) })
    }

    /// `bounds` is the bounding box of the referencing element, evaluated only for objectBoundingBox units.
    func makeClip(id: String, bounds: () -> LayerTree.Rect?) -> Clip? {
        guard let clip = svg.defs.clipPaths.first(where: { $0.id == id }) else { return nil }

        // a clip path that (indirectly) clips itself is ignored; the active set is not counted
        // against the document-wide reference budget, so any number of elements may share a clip.
        // Each nested clip-path costs native stack, so nesting stops at ReferenceGuard.maxDepth.
        guard activeClips.count < ReferenceGuard.maxDepth,
              activeClips.insert(id).inserted else { return nil }
        defer { activeClips.remove(id) }

        var units = LayerTree.Transform.Matrix.identity
        if clip.clipPathUnits == .objectBoundingBox {
            // the bounding box of text is unknown here: keep the element unclipped rather than lose content
            guard let bounds = bounds() else { return nil }
            // an empty bounding box clips everything away
            guard bounds.width > 0, bounds.height > 0 else { return .shapes([.empty], .nonzero) }
            units = LayerTree.Transform.Matrix(a: bounds.width, b: 0, c: 0, d: bounds.height,
                                               tx: bounds.x, ty: bounds.y)
        }

        let transform = clip.style.transform ?? clip.attributes.transform ?? []
        // the bounding box mapping comes first, then the <clipPath>'s transform in user units
        // (as Blink, Gecko and resvg do: clipTransform × translate(bbox) × scale(bbox))
        let space = units.concatenated(Self.createTransforms(from: transform).toMatrix())
        let rule = clip.style.clipRule ?? clip.attributes.clipRule ?? .nonzero
        let members = clip.childElements.flatMap { makeClipMembers(for: $0, inheriting: rule) }
        let nested = (clip.style.clipPath ?? clip.attributes.clipPath)?.fragmentID

        let shapes = members.compactMap { member -> LayerTree.ClipShape? in
            guard let shape = Self.makeShape(from: member.element) else { return nil }
            return LayerTree.ClipShape(shape: shape, transform: member.transform.concatenated(space))
        }
        let rules = Set(members.map(\.rule))

        if shapes.count == members.count, rules.count <= 1, nested == nil {
            // a clip path without any shape clips everything away
            return .shapes(shapes.isEmpty ? [.empty] : shapes, rules.first ?? .nonzero)
        }

        let content = LayerTree.Layer()
        if space != .identity {
            content.transform = [.matrix(space)]
        }
        for member in members {
            content.appendContents(.layer(makeClipMaskLayer(for: member)))
        }

        let region = LayerTree.Layer()
        if let nested, let clip = makeClip(id: nested, bounds: bounds) {
            apply(clip, to: region)
        }
        region.appendContents(.layer(content))

        let mask = LayerTree.Layer()
        mask.appendContents(.layer(region))
        return .mask(mask)
    }

    /// The shapes and text a `<clipPath>` child contributes: a `<use>` contributes the shape or text
    /// it references directly; any other element is ignored (SVG 1.1 §14.3.5).
    func makeClipMembers(for element: DOM.GraphicsElement, inheriting rule: LayerTree.FillRule) -> [ClipMember] {
        let attributes = DOM.presentationAttributes(for: element, styles: svg.styles)
        // SVG 1.1 §14.3.5: children with `display="none"` or hidden `visibility` do not contribute to the clip
        guard attributes.display != DOM.DisplayMode.none, (attributes.visibility ?? .visible) == .visible else { return [] }
        let transform = Self.createTransforms(from: attributes.transform ?? []).toMatrix()
        let rule = attributes.clipRule ?? rule

        if let use = element as? DOM.Use {
            guard let id = use.href.fragmentID,
                  let referenced = svg.firstGraphicsElement(with: id),
                  !(referenced is DOM.Use) else { return [] }
            let translate = LayerTree.Transform.translate(tx: use.x ?? 0, ty: use.y ?? 0).toMatrix()
            return makeClipMembers(for: referenced, inheriting: rule).map {
                var member = $0
                member.transform = member.transform.concatenated(translate).concatenated(transform)
                return member
            }
        } else if Self.makeShape(from: element) != nil || element is DOM.Text {
            return [ClipMember(element: element, transform: transform, rule: rule)]
        }
        return []
    }

    func makeClipMaskLayer(for member: ClipMember) -> LayerTree.Layer {
        let l = LayerTree.Layer()
        if member.transform != .identity {
            l.transform = [.matrix(member.transform)]
        }
        if let shape = Self.makeShape(from: member.element) {
            var state = State()
            state.fill = .color(.keyword(.white))
            state.fillRule = member.rule
            l.appendContents(makeShapeContents(from: shape, with: state))
        } else if let text = member.element as? DOM.Text {
            let state = createState(for: text, inheriting: State())
            if case .text(let string, let point, var attributes) = makeTextContents(from: text, with: state) {
                attributes.color = .white
                l.appendContents(.text(string, point, attributes))
            }
        }
        return l
    }

    func apply(_ clip: Clip, to layer: LayerTree.Layer) {
        switch clip {
        case let .shapes(shapes, rule):
            layer.clip = shapes
            layer.clipRule = rule
        case let .mask(mask):
            guard let existing = layer.mask else {
                layer.mask = mask
                layer.maskIsClip = true
                return
            }
            // a mask and a clip together: the clip masks the mask's own contents
            let inner = LayerTree.Layer()
            inner.mask = mask
            existing.contents.forEach(inner.appendContents)
            let combined = LayerTree.Layer()
            combined.appendContents(.layer(inner))
            layer.mask = combined
        }
    }

    /// The region outside which a `<mask>` is zero (SVG 1.1 §14.4): nil when it cannot be resolved
    /// (an objectBoundingBox region on an element whose bounding box is unknown).
    func makeMaskRegion(for mask: DOM.Mask, bounds: LayerTree.Rect?) -> LayerTree.Rect? {
        let x = mask.x ?? .percentage(-10)
        let y = mask.y ?? .percentage(-10)
        let width = mask.width ?? .percentage(120)
        let height = mask.height ?? .percentage(120)

        switch mask.maskUnits ?? .objectBoundingBox {
        case .objectBoundingBox:
            guard let bounds else { return nil }
            func fraction(_ length: DOM.DashLength) -> LayerTree.Float {
                switch length {
                case .absolute(let value): return value
                case .percentage(let value): return value / 100
                }
            }
            return LayerTree.Rect(x: bounds.x + fraction(x) * bounds.width,
                                  y: bounds.y + fraction(y) * bounds.height,
                                  width: fraction(width) * bounds.width,
                                  height: fraction(height) * bounds.height)
        case .userSpaceOnUse:
            let viewport = svg.viewBox.map { LayerTree.Size($0.width, $0.height) }
                ?? LayerTree.Size(LayerTree.Float(svg.width), LayerTree.Float(svg.height))
            func length(_ length: DOM.DashLength, _ reference: LayerTree.Float) -> LayerTree.Float {
                switch length {
                case .absolute(let value): return value
                case .percentage(let value): return value / 100 * reference
                }
            }
            return LayerTree.Rect(x: length(x, viewport.width),
                                  y: length(y, viewport.height),
                                  width: length(width, viewport.width),
                                  height: length(height, viewport.height))
        }
    }

    /// The object bounding box of an element in its own user space: the fill geometry of its shapes,
    /// without stroke (SVG 1.1 §7.11). Nil when unknown: text, or a container holding text, since
    /// a box measured without it would cut the text away.
    func makeBoundingBox(for element: DOM.GraphicsElement) -> LayerTree.Rect? {
        var visited = Set<String>()
        switch makeBounds(for: element, depth: 0, visited: &visited) {
        case .known(let rect): return rect
        case .empty, .unknown: return nil
        }
    }

    enum Bounds {
        case known(LayerTree.Rect)
        /// no geometry (an empty group, a move-only path): ignored by the enclosing container
        case empty
        /// geometry this platform-independent builder cannot measure (text)
        case unknown
    }

    /// Measurement keeps its own visited set, depth cap and step budget: it never spends the
    /// document-wide reference budget that `<use>`, masks and patterns share.
    private func makeBounds(for element: DOM.GraphicsElement, depth: Int, visited: inout Set<String>) -> Bounds {
        guard depth < 32, measurement.spend() else { return .unknown }

        if let shape = Self.makeShape(from: element) {
            return Bounds(shape.path.bounds)
        } else if let image = element as? DOM.Image {
            guard let width = image.width, let height = image.height else { return .unknown }
            return Bounds(LayerTree.Rect(x: image.x ?? 0, y: image.y ?? 0, width: width, height: height))
        } else if let use = element as? DOM.Use {
            guard let id = use.href.fragmentID,
                  let referenced = svg.firstGraphicsElement(with: id) else { return .empty }
            guard visited.insert(id).inserted else { return .empty }
            defer { visited.remove(id) }
            let referencedBounds = makeBounds(for: referenced, depth: depth + 1, visited: &visited)
            guard case .known(let bounds) = referencedBounds else { return referencedBounds }
            let transform = Self.createTransforms(from: referenced.attributes.transform ?? []).toMatrix()
                .concatenated(LayerTree.Transform.translate(tx: use.x ?? 0, ty: use.y ?? 0).toMatrix())
            return Bounds(bounds.applying(transform))
        } else if let container = element as? any ContainerElement {
            var result: LayerTree.Rect?
            for child in container.childElements where child.attributes.display != DOM.DisplayMode.none {
                switch makeBounds(for: child, depth: depth + 1, visited: &visited) {
                case .unknown:
                    return .unknown
                case .empty:
                    continue
                case .known(let bounds):
                    let transform: LayerTree.Transform.Matrix
                    if let svg = child as? DOM.SVG {
                        transform = Self.makeTransform(x: svg.x, y: svg.y, viewBox: svg.viewBox,
                                                       width: svg.width, height: svg.height).toMatrix()
                    } else {
                        transform = Self.createTransforms(from: child.attributes.transform ?? []).toMatrix()
                    }
                    guard case .known(let childBounds) = Bounds(bounds.applying(transform)) else { continue }
                    result = result.map { $0.union(childBounds) } ?? childBounds
                }
            }
            return result.map(Bounds.known) ?? .empty
        } else if element is DOM.Text {
            return .unknown
        }
        return .empty
    }
}

extension LayerTree.Builder.Bounds {
    /// Non-finite or negative-sized bounds (a move-only path, NaN from 0 × inf) carry no geometry.
    init(_ rect: LayerTree.Rect) {
        let values = [rect.x, rect.y, rect.width, rect.height]
        guard values.allSatisfy(\.isFinite), rect.width >= 0, rect.height >= 0 else {
            self = .empty
            return
        }
        self = .known(rect)
    }
}

/// Ids of the clip paths being resolved, to drop cycles.
final class ActiveClipSet {
    private var ids = Set<String>()

    var count: Int { ids.count }

    func insert(_ id: String) -> (inserted: Bool, memberAfterInsert: String) {
        ids.insert(id)
    }

    func remove(_ id: String) {
        ids.remove(id)
    }
}

extension LayerTree.Builder {

    /// Bounds the elements visited measuring bounding boxes, document-wide: `visited` only cuts cycles,
    /// and non-cyclic `<use>` fan-out (4 uses per level) is exponential. Past the budget every box is
    /// unknown, so bbox clips and mask regions degrade to none rather than hide content.
    final class MeasurementBudget {
        static let maxSteps = 250_000
        private(set) var steps = 0

        func spend() -> Bool {
            guard steps < Self.maxSteps else { return false }
            steps += 1
            return true
        }
    }
}

extension LayerTree.ClipShape {
    /// A clip that nothing passes through.
    static var empty: Self {
        LayerTree.ClipShape(shape: .rect(within: .zero, radii: .zero), transform: .identity)
    }
}

extension LayerTree.Rect {

    func applying(_ matrix: LayerTree.Transform.Matrix) -> LayerTree.Rect {
        guard matrix != .identity else { return self }
        let points = [
            LayerTree.Point(x, y),
            LayerTree.Point(x + width, y),
            LayerTree.Point(x, y + height),
            LayerTree.Point(x + width, y + height)
        ].map(matrix.transform(point:))
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        let minX = xs.min()!, minY = ys.min()!
        return LayerTree.Rect(x: minX, y: minY, width: xs.max()! - minX, height: ys.max()! - minY)
    }

    func union(_ other: LayerTree.Rect) -> LayerTree.Rect {
        let minX = Swift.min(x, other.x)
        let minY = Swift.min(y, other.y)
        let maxX = Swift.max(x + width, other.x + other.width)
        let maxY = Swift.max(y + height, other.y + other.height)
        return LayerTree.Rect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
