//
//  LayerTree.Builder.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 4/6/17.
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

// Convert a DOM.SVG into a layer tree

import SwiftDrawDOM
import Foundation

extension LayerTree {

    struct Builder {

        let svg: DOM.SVG
        /// The user's preferred languages for `systemLanguage` (BCP 47 tags, most preferred first).
        let languages: [String]

        // The use, mask, pattern and marker elements being built. Reaching one again is a cycle.
        private final class Active {
            var elements = Set<AnyHashable>()
            var depth = 0
            var total = 0
        }
        private let active = Active()
        // References dropped because they are recursive, found once per document.
        let recursion = Recursion()
        // The clip paths being resolved (SD8): cycles are dropped without spending the reference budget.
        let activeClips = ActiveClipSet()
        // Bounds the elements visited measuring objectBoundingBox clips and mask regions (SD8).
        let measurement = MeasurementBudget()

        /// References nested deeper than this are dropped: each level costs native stack.
        static let maxReferenceDepth = 16
        /// References expanded beyond this in one document are dropped: fan-out without a cycle,
        /// such as each level using the previous one several times, grows exponentially.
        static let maxReferences = 20_000

        init(svg: DOM.SVG, languages: [String] = Builder.preferredLanguages) {
            self.svg = svg
            self.languages = languages
        }

        /// The system's preferred languages on Apple platforms; `en` elsewhere, where the locale
        /// environment rarely reflects a reader's preference.
        static var preferredLanguages: [String] {
            #if canImport(Darwin)
            let languages = Locale.preferredLanguages
            return languages.isEmpty ? ["en"] : languages
            #else
            return ["en"]
            #endif
        }

        /// Builds a referenced use, mask, pattern or marker, or returns `cycle` when the reference is
        /// already being built or exceeds the depth or document budget.
        func building<R>(_ key: some Hashable, cycle: R, _ build: () throws -> R) rethrows -> R {
            guard active.depth < Self.maxReferenceDepth,
                active.total < Self.maxReferences,
                active.elements.insert(key).inserted
            else { return cycle }
            active.depth += 1
            active.total += 1
            defer {
                active.elements.remove(key)
                active.depth -= 1
            }
            return try build()
        }

        func makeLayer() -> Layer {
            makeLayer(svg: svg, inheriting: State())
        }

        /// SVG 1.1 §11.6.2: hidden shapes, text and images paint nothing, whatever mask, filter or
        /// opacity they carry (a filter such as feFlood could otherwise still paint).
        static func isHiddenLeaf(_ element: DOM.GraphicsElement, _ state: State) -> Bool {
            guard state.visibility != .visible else { return false }
            return makeShape(from: element) != nil || element is DOM.Text || element is DOM.Image
        }

        func makeLayer(svg: DOM.SVG, inheriting previousState: State) -> Layer {
            // a root removed by `display` has no viewport mapping either
            if DOM.presentationAttributes(for: svg, styles: self.svg.styles).display == DOM.DisplayMode.none {
                return Layer()
            }
            let l = makeLayer(from: svg, inheriting: previousState)
            // SVG 2: the root's own `transform` applies outside the viewBox mapping, in the viewport,
            // where its transform-origin percentages resolve. The outermost <svg> has a CSS box, so its
            // transform-origin defaults to `50% 50%` rather than `0 0` (as in resvg and browsers).
            let attributes = DOM.presentationAttributes(for: svg, styles: self.svg.styles)
            let rootTransform = Builder.createTransforms(
                from: attributes.transform ?? [],
                origin: attributes.transformOrigin ?? .init(x: .fraction(0.5), y: .fraction(0.5)),
                viewport: LayerTree.Size(LayerTree.Float(svg.width), LayerTree.Float(svg.height))
            )
            l.transform =
                rootTransform
                + Builder.makeTransform(
                    x: svg.x,
                    y: svg.y,
                    viewBox: svg.viewBox,
                    width: svg.width,
                    height: svg.height,
                    preserveAspectRatio: svg.preserveAspectRatio
                )
            // `slice` lets the viewBox overflow the viewport, which clips it (also when drawn into a larger context).
            // layer.clip applies after layer.transform, so the viewport is expressed in viewBox space.
            if let par = svg.preserveAspectRatio, par.align != .none, par.meetOrSlice == .slice {
                let viewport = Builder.makeViewportClip(
                    viewBox: svg.viewBox,
                    width: svg.width,
                    height: svg.height,
                    preserveAspectRatio: par
                )
                let viewportClip = [ClipShape(shape: .rect(within: viewport, radii: .zero), transform: .identity)]
                if l.clip.isEmpty {
                    l.clip = viewportClip
                } else {
                    // the root's own clip-path and the viewport both apply: layer clips are unioned, so
                    // the viewport clips an outer layer holding the root layer, which keeps its clip-path
                    let outer = Layer()
                    outer.transform = l.transform
                    outer.clip = viewportClip
                    l.transform = []
                    outer.contents = [.layer(l)]
                    return outer
                }
            }
            return l
        }

        static func makeTransform(
            x: DOM.Coordinate?,
            y: DOM.Coordinate?,
            viewBox: DOM.SVG.ViewBox?,
            width: DOM.Coordinate,
            height: DOM.Coordinate,
            preserveAspectRatio: DOM.PreserveAspectRatio? = nil
        ) -> [LayerTree.Transform] {
            let fit = makeViewBoxFit(
                viewBox: viewBox,
                width: width,
                height: height,
                preserveAspectRatio: preserveAspectRatio
            )
            let position = LayerTree.Transform.translate(tx: (x ?? 0) + fit.tx, ty: (y ?? 0) + fit.ty)
            let scale = LayerTree.Transform.scale(sx: fit.sx, sy: fit.sy)
            let translate = LayerTree.Transform.translate(tx: -fit.viewBox.x, ty: -fit.viewBox.y)

            var transform: [LayerTree.Transform] = []

            if position != .translate(tx: 0, ty: 0) {
                transform.append(position)
            }

            if scale != .scale(sx: 1, sy: 1) {
                transform.append(scale)
            }

            if translate != .translate(tx: 0, ty: 0) {
                transform.append(translate)
            }

            return transform
        }

        /// Maps the viewBox into the `width` x `height` viewport (SVG 1.1 §7.8, `preserveAspectRatio`):
        /// `viewport = (user - viewBox.origin) * scale + offset`. A missing or empty viewBox is the viewport itself.
        static func makeViewBoxFit(
            viewBox: DOM.SVG.ViewBox?,
            width: DOM.Coordinate,
            height: DOM.Coordinate,
            preserveAspectRatio: DOM.PreserveAspectRatio?
        ) -> (
            viewBox: DOM.SVG.ViewBox, sx: LayerTree.Float, sy: LayerTree.Float, tx: LayerTree.Float, ty: LayerTree.Float
        ) {
            var box = DOM.SVG.ViewBox(x: 0, y: 0, width: .init(width), height: .init(height))
            if let viewBox, viewBox.x.isFinite, viewBox.y.isFinite,
                viewBox.width.isFinite, viewBox.height.isFinite,
                viewBox.width > 0, viewBox.height > 0
            {
                box = viewBox
            }
            // an empty or non-finite viewport (or one that overflows the fit) has no mapping: identity
            guard box.width > 0, box.height > 0, width > 0, height > 0 else {
                return (box, 1, 1, 0, 0)
            }
            let fit = (preserveAspectRatio ?? .default).fit(
                contentWidth: box.width,
                contentHeight: box.height,
                viewportWidth: .init(width),
                viewportHeight: .init(height)
            )
            // the free space of an exact fit is only rounding noise
            let tx = abs(fit.tx) < 1e-4 ? 0 : fit.tx
            let ty = abs(fit.ty) < 1e-4 ? 0 : fit.ty
            guard [fit.sx, fit.sy, tx, ty].allSatisfy(\.isFinite), fit.sx > 0, fit.sy > 0 else {
                return (DOM.SVG.ViewBox(x: 0, y: 0, width: .init(width), height: .init(height)), 1, 1, 0, 0)
            }
            return (box, fit.sx, fit.sy, tx, ty)
        }

        /// The viewport of a nested `<svg>` in the coordinates of its contents (the viewBox space),
        /// where its `overflow: hidden` clip applies. Larger than the viewBox when `meet` letterboxes it.
        static func makeViewportClip(
            viewBox: DOM.SVG.ViewBox?,
            width: DOM.Coordinate,
            height: DOM.Coordinate,
            preserveAspectRatio: DOM.PreserveAspectRatio?
        ) -> LayerTree.Rect {
            let fit = makeViewBoxFit(
                viewBox: viewBox,
                width: width,
                height: height,
                preserveAspectRatio: preserveAspectRatio
            )
            return LayerTree.Rect(
                x: fit.viewBox.x - fit.tx / fit.sx,
                y: fit.viewBox.y - fit.ty / fit.sy,
                width: LayerTree.Float(width) / fit.sx,
                height: LayerTree.Float(height) / fit.sy
            )
        }

        func makeLayer(from root: DOM.GraphicsElement, inheriting previousState: State) -> Layer {
            // `isFiltered`: the element or an ancestor has a filter, so text measures its bounding box
            // for an objectBoundingBox filter region
            var stack: [(DOM.GraphicsElement, State, Layer?, isFiltered: Bool)] = [(root, previousState, nil, false)]
            var resultLayer: Layer? = nil

            while let (currentElement, currentState, parentLayer, parentIsFiltered) = stack.popLast() {
                // a <symbol> is only drawn as the root of a <use> that references it
                if currentElement is DOM.Symbol, parentLayer != nil {
                    continue
                }
                let newState = createState(for: currentElement, inheriting: currentState)
                // SVG 1.1 §11.6.2: `display="none"` removes the element and its whole subtree from rendering,
                // before any transform, clip, mask, filter or opacity is built for it;
                // SVG 2 §5.8: so does a conditional processing attribute that evaluates to false
                if newState.display == .none || Self.isHiddenLeaf(currentElement, newState)
                    || !currentElement.passesConditions(languages: languages)
                {
                    if parentLayer == nil {
                        resultLayer = Layer()
                    }
                    continue
                }
                // a `filter` whose url() references are all missing removes the element (as resvg)
                guard let (layer, contentLayer) = makeBaseLayer(from: currentElement, with: newState) else {
                    if parentLayer == nil {
                        resultLayer = Layer()
                    }
                    continue
                }

                let isFiltered = parentIsFiltered || !layer.filters.isEmpty
                if let contents = makeContents(from: currentElement, with: newState) {
                    contentLayer.appendContents(contents)
                    if isFiltered, let text = currentElement as? DOM.Text {
                        contentLayer.textBounds = makeTextBounds(for: text, with: newState)
                    }
                } else if let container = currentElement as? any ContainerElement {
                    // Push children in reverse so they are processed in the original order
                    for child in container.childElements.reversed() {
                        stack.append((child, newState, contentLayer, isFiltered))
                    }
                }

                if let parent = parentLayer {
                    parent.appendContents(.layer(layer))

                    if let svg = currentElement as? DOM.SVG {
                        let bounds = Builder.makeViewportClip(
                            viewBox: svg.viewBox,
                            width: svg.width,
                            height: svg.height,
                            preserveAspectRatio: svg.preserveAspectRatio
                        )
                        layer.clip = [ClipShape(shape: .rect(within: bounds, radii: .zero), transform: .identity)]
                        layer.transform = Builder.makeTransform(
                            x: svg.x,
                            y: svg.y,
                            viewBox: svg.viewBox,
                            width: svg.width,
                            height: svg.height,
                            preserveAspectRatio: svg.preserveAspectRatio
                        )
                    }
                } else {
                    // This must be the top-level root layer
                    resultLayer = layer
                }
            }

            return resultLayer!
        }

        /// The layer of an element and the layer its contents go into: the same layer, unless the `filter`
        /// list has more than one entry. Each entry is then a layer of its own, the first innermost, so they
        /// apply in order, each with its own filter region. nil when the element is not rendered.
        func makeBaseLayer(from element: DOM.GraphicsElement, with state: State) -> (layer: Layer, contents: Layer)? {
            // transform and mask may come from CSS as well as attributes
            let attributes = DOM.presentationAttributes(for: element, styles: svg.styles)
            guard let filters = makeFilters(for: attributes, with: state) else { return nil }
            let l = Layer()
            l.class = element.class
            l.transform = createTransforms(from: attributes)
            l.mask = createMaskLayer(for: element, attributes: attributes, state: state)
            // clip-rule comes from the <clipPath> contents and objectBoundingBox units are resolved
            // here, so every clip reaches the renderers in user space (SVG 1.1 §14.3.5)
            if let clip = makeClip(for: element, state: state) {
                apply(clip, to: l)
            }
            l.opacity = state.opacity
            var contents = l
            if let last = filters.last {
                l.filters = last.primitives
                l.filterRegion = last.region
                l.filterImages = makeFilterImages(for: last.primitives)
                for filter in filters.dropLast().reversed() {
                    let inner = Layer()
                    inner.filters = filter.primitives
                    inner.filterRegion = filter.region
                    inner.filterImages = makeFilterImages(for: filter.primitives)
                    contents.appendContents(.layer(inner))
                    contents = inner
                }
            }
            return (l, contents)
        }

        func makeContents(from element: DOM.GraphicsElement, with state: State) -> Layer.Contents? {
            // SVG 1.1 §11.6.2: `visibility` hides graphics only; a child may set `visible` again
            let isVisible = state.visibility == .visible
            if let shape = Builder.makeShape(from: element) {
                guard isVisible else { return nil }
                let contents = makeShapeContents(from: shape, with: state)
                return makePaintedContents(contents, for: element, with: state)
            } else if let text = element as? DOM.Text {
                guard isVisible else { return nil }
                if let textPath = text.textPath {
                    return makeTextPathContents(from: textPath, with: state)
                }
                return makeTextContents(from: text, with: state)
            } else if let image = element as? DOM.Image {
                return isVisible ? try? Builder.makeImageContents(from: image) : nil
            } else if let use = element as? DOM.Use {
                return try? makeUseLayerContents(from: use, with: state)
            } else if let sw = element as? DOM.Switch {
                // SVG 2 §5.8.2: only the first direct child whose conditions evaluate to true is rendered,
                // even if it then draws nothing (such as `display="none"`)
                guard let e = sw.childElements.first(where: { $0.passesConditions(languages: languages) }) else {
                    return .layer(Layer())
                }
                return .layer(makeLayer(from: e, inheriting: state))
            }

            return nil
        }

        func makeClipShapes(for element: DOM.GraphicsElement) -> [ClipShape] {
            guard case .shapes(let shapes, _) = makeClip(for: element) else { return [] }
            return shapes
        }

        func createMaskLayer(for element: DOM.GraphicsElement) -> Layer? {
            createMaskLayer(for: element, attributes: DOM.presentationAttributes(for: element, styles: svg.styles))
        }

        /// `attributes` is the cascade of `element`: its `mask` may come from a stylesheet rule.
        /// `state` is the element's, to measure the bounding box of text.
        func createMaskLayer(
            for element: DOM.GraphicsElement,
            attributes: DOM.PresentationAttributes,
            state: State? = nil
        ) -> Layer? {
            guard let maskId = attributes.mask?.fragmentID,
                let mask = svg.defs.masks.first(where: { $0.id == maskId }),
                !isInvalid(element, .mask)
            else { return nil }

            // SVG 1.1 §14.4: maskUnits places the mask region, maskContentUnits the contents
            let regionUnits = mask.maskUnits ?? .objectBoundingBox
            let contentUnits = mask.maskContentUnits ?? .userSpaceOnUse
            let bounds =
                (regionUnits == .objectBoundingBox || contentUnits == .objectBoundingBox)
                ? makeBoundingBox(for: element, state: state) : nil
            // a bounding box that cannot be measured (text without CoreText): ignore the mask
            if contentUnits == .objectBoundingBox && bounds == nil { return nil }

            // A mask reached again inside itself is invalid, so the element it is on is not masked
            return building(ObjectIdentifier(mask), cycle: nil) { () -> Layer? in
                buildingContents {
                    let l = Layer()
                    if DOM.presentationAttributes(for: mask, styles: svg.styles).maskType == .alpha {
                        l.maskType = .alpha
                    } else if makeColorInterpolation(for: mask) == .linearRGB {
                        l.maskType = .linearLuminance
                    }

                    let content = Layer()
                    if contentUnits == .objectBoundingBox, let bounds {
                        // an empty bounding box masks everything away
                        guard bounds.width > 0, bounds.height > 0 else { return l }
                        content.transform = [
                            .matrix(
                                Transform.Matrix(
                                    a: bounds.width,
                                    b: 0,
                                    c: 0,
                                    d: bounds.height,
                                    tx: bounds.x,
                                    ty: bounds.y
                                )
                            )
                        ]
                    }

                    // the contents inherit from the mask's ancestors, not from the masked element
                    var maskState = createState(for: mask, inheriting: makeInheritedState(from: mask.ancestors))
                    // SVG 1.1 §11.5: `display` does not apply to `<mask>`; only its children can be hidden
                    maskState.display = .inline
                    mask.childElements.forEach {
                        let contents = Layer.Contents.layer(makeLayer(from: $0, inheriting: maskState))
                        content.appendContents(contents)
                    }

                    if let region = makeMaskRegion(for: mask, bounds: bounds) {
                        // a zero or negative region disables rendering of the element
                        guard region.width > 0, region.height > 0 else { return l }
                        let clipped = Layer()
                        clipped.clip = [ClipShape(shape: .rect(within: region, radii: .zero), transform: .identity)]
                        clipped.appendContents(.layer(content))
                        l.appendContents(.layer(clipped))
                    } else if content.transform.isEmpty {
                        content.contents.forEach(l.appendContents)
                    } else {
                        l.appendContents(.layer(content))
                    }

                    return l
                }
            }
        }

        // `filter` is not inherited: it applies once, to the element that references it.
        // Each url() and filter function in the list is one filter, applied in order. A url() to a missing
        // <filter> is skipped; when every entry is such a url() the element is not rendered (nil), as resvg.
        func makeFilters(
            for attributes: DOM.PresentationAttributes,
            with state: State
        ) -> [(primitives: [FilterPrimitive], region: FilterRegion)]? {
            guard let values = attributes.filter else { return [] }
            var filters = [(primitives: [FilterPrimitive], region: FilterRegion)]()
            var hasMissingURL = false
            for value in values {
                switch value {
                case .url(let url):
                    if let filterId = url.fragmentID,
                        let filter = svg.defs.filters.first(where: { $0.id == filterId })
                    {
                        let filter = resolvingHref(filter)
                        // Filter Effects 1 §5.1: a filter without primitives paints transparent black, hiding the element
                        let primitives =
                            filter.primitives.isEmpty
                            ? [DOM.Filter.Primitive(effect: .flood(color: .keyword(.black), opacity: 0))]
                            : filter.primitives
                        filters.append((primitives, makeFilterRegion(for: filter)))
                    } else {
                        hasMissingURL = true
                    }
                case .function(let function):
                    filters.append(Self.makeFilter(for: function, with: state))
                }
            }
            if filters.isEmpty && hasMissingURL {
                return nil
            }
            return filters
        }

        // SVG 1.1 §15.5 (dropped by Filter Effects 1, followed by resvg): attributes the filter leaves unset,
        // and its primitives when it has none, come from the filter its href references, and so on along the chain
        func resolvingHref(_ filter: DOM.Filter) -> DOM.Filter {
            guard filter.href != nil else { return filter }
            let resolved = DOM.Filter(id: filter.id)
            resolved.primitives = filter.primitives
            resolved.x = filter.x
            resolved.y = filter.y
            resolved.width = filter.width
            resolved.height = filter.height
            resolved.filterUnits = filter.filterUnits
            resolved.primitiveUnits = filter.primitiveUnits

            var visited: Set<String> = [filter.id]
            var href = filter.href
            while let id = href?.fragmentID, visited.insert(id).inserted,
                let referenced = svg.defs.filters.first(where: { $0.id == id })
            {
                if resolved.primitives.isEmpty { resolved.primitives = referenced.primitives }
                resolved.x = resolved.x ?? referenced.x
                resolved.y = resolved.y ?? referenced.y
                resolved.width = resolved.width ?? referenced.width
                resolved.height = resolved.height ?? referenced.height
                resolved.filterUnits = resolved.filterUnits ?? referenced.filterUnits
                resolved.primitiveUnits = resolved.primitiveUnits ?? referenced.primitiveUnits
                href = referenced.href
            }
            return resolved
        }

        func makeFilterRegion(for filter: DOM.Filter) -> FilterRegion {
            FilterRegion(
                x: filter.x.map { Float($0) },
                y: filter.y.map { Float($0) },
                width: filter.width.map { Float($0) },
                height: filter.height.map { Float($0) },
                units: filter.filterUnits == .userSpaceOnUse ? .userSpaceOnUse : .objectBoundingBox,
                primitiveUnits: filter.primitiveUnits == .objectBoundingBox ? .objectBoundingBox : .userSpaceOnUse
            )
        }
    }
}

extension LayerTree.Builder {

    /// `bounds` is the bounding box of the geometry being stroked; when it has no width or height a
    /// paint server with objectBoundingBox units gives way to its fallback colour (SVG 2 §8.10).
    func makeStrokeAttributes(with state: State, bounds: LayerTree.Rect? = nil) -> LayerTree.StrokeAttributes {
        let stroke: LayerTree.StrokeAttributes.Stroke

        if state.strokeWidth > 0.0 {
            switch resolveFallback(state.stroke, bounds: bounds) {
            case .color(let c):
                let color = LayerTree.Color
                    .create(from: c, current: state.color)
                    .withAlpha(state.strokeOpacity).maybeNone()
                stroke = .color(color)
            case .url(let paintId):
                if let element = svg.defs.patterns.first(where: { $0.id == paintId.fragmentID }) {
                    stroke = .pattern(makePattern(for: element))
                } else {
                    switch makeGradientPaint(for: paintId) {
                    case .linear(let gradient):
                        stroke = .linearGradient(gradient)
                    case .radial(let gradient):
                        stroke = .radialGradient(gradient)
                    case .color(let color):
                        stroke = .color(color.withAlpha(state.strokeOpacity).maybeNone())
                    case nil:
                        stroke = .color(.none)
                    }
                }
            case .urlWithFallback:
                stroke = .color(.none)  // resolved to .url or .color above
            }
        } else {
            stroke = .color(.none)
        }

        return LayerTree.StrokeAttributes(
            color: stroke,
            width: state.strokeWidth,
            cap: state.strokeLineCap,
            join: state.strokeLineJoin,
            miterLimit: state.strokeLineMiterLimit,
            dashArray: makeDashArray(with: state),
            dashOffset: makeDashOffset(with: state),
            opacity: state.strokeOpacity
        )
    }

    /// Length of the viewport diagonal / sqrt(2), the reference for percentages (SVG 1.1 §7.10).
    var viewportDiagonal: LayerTree.Float {
        let w: LayerTree.Float
        let h: LayerTree.Float
        if let viewBox = svg.viewBox {
            w = viewBox.width
            h = viewBox.height
        } else {
            w = LayerTree.Float(svg.width)
            h = LayerTree.Float(svg.height)
        }
        return ((w * w + h * h) / 2).squareRoot()
    }

    func makeDashLength(_ length: DOM.DashLength, fontSize: LayerTree.Float) -> LayerTree.Float {
        Self.resolve(length, fontSize: fontSize, viewportDiagonal: viewportDiagonal)
    }

    /// A length in user units: `em` against the font-size, a percentage against the viewport diagonal.
    static func resolve(
        _ length: DOM.DashLength,
        fontSize: LayerTree.Float,
        viewportDiagonal: LayerTree.Float
    ) -> LayerTree.Float {
        switch length {
        case .absolute(let value): return value
        case .percentage(let value): return value / 100 * viewportDiagonal
        case .em(let value): return value * fontSize
        }
    }

    func makeDashOffset(with state: State) -> LayerTree.Float {
        let offset = makeDashLength(state.strokeDashOffset, fontSize: state.fontSize)
        return offset.isFinite ? offset : 0
    }

    /// SVG 1.1 §11.4: odd-length lists repeat to even length; a zero sum renders solid.
    func makeDashArray(with state: State) -> [LayerTree.Float] {
        var lengths = state.strokeDashArray.map { makeDashLength($0, fontSize: state.fontSize) }
        guard !lengths.isEmpty, lengths.allSatisfy({ $0 >= 0 && $0.isFinite }), lengths.reduce(0, +) > 0 else {
            return []
        }
        if lengths.count % 2 == 1 {
            lengths += lengths
        }
        return lengths
    }

    /// SVG 1.1 §11.2: a paint server that resolves wins; otherwise the fallback colour (`none` paints nothing).
    /// A paint server with objectBoundingBox units does not resolve on a `bounds` with no width or
    /// height, such as a horizontal or vertical line (SVG 2 §8.10).
    func resolveFallback(_ paint: DOM.Fill, bounds: LayerTree.Rect? = nil) -> DOM.Fill {
        guard case .urlWithFallback(let url, let color) = paint else { return paint }
        guard let id = url.fragmentID else { return .color(color) }
        let units: LayerTree.Gradient.Units
        if let element = svg.defs.patterns.first(where: { $0.id == id }) {
            let patternUnits = makePatternChain(for: element).lazy.compactMap(\.patternUnits).first
            units = patternUnits == .userSpaceOnUse ? .userSpaceOnUse : .objectBoundingBox
        } else if let element = makeGradientElement(for: id), makeGradientPaint(for: url) != nil {
            units = Self.createUnits(from: makeGradientChain(from: element).lazy.compactMap(\.units).first)
        } else {
            return .color(color)
        }
        if units == .objectBoundingBox, let bounds, !(bounds.width > 0 && bounds.height > 0) {
            return .color(color)
        }
        return .url(url)
    }

    func makeGradientElement(for id: String) -> GradientElement? {
        if let element = svg.defs.linearGradients.first(where: { $0.id == id }) {
            return .linear(element)
        } else if let element = svg.defs.radialGradients.first(where: { $0.id == id }) {
            return .radial(element)
        }
        return nil
    }

    func makeFillAttributes(with state: State, bounds: LayerTree.Rect? = nil) -> LayerTree.FillAttributes {
        var state = state
        state.fill = resolveFallback(state.fill, bounds: bounds)
        let fill = LayerTree.Color
            .create(from: state.fill.makeColor(), current: state.color)
            .withAlpha(state.fillOpacity).maybeNone()

        if case .url(let patternId) = state.fill,
            let element = svg.defs.patterns.first(where: { $0.id == patternId.fragmentID })
        {
            let pattern = makePattern(for: element)
            return LayerTree.FillAttributes(pattern: pattern, rule: state.fillRule, opacity: state.fillOpacity)
        } else if case .url(let gradientId) = state.fill,
            let paint = makeGradientPaint(for: gradientId)
        {
            switch paint {
            case .linear(let gradient):
                return LayerTree.FillAttributes(linear: gradient, rule: state.fillRule, opacity: state.fillOpacity)
            case .radial(let gradient):
                return LayerTree.FillAttributes(radial: gradient, rule: state.fillRule, opacity: state.fillOpacity)
            case .color(let color):
                return LayerTree.FillAttributes(
                    color: color.withAlpha(state.fillOpacity).maybeNone(),
                    rule: state.fillRule
                )
            }
        } else {
            return LayerTree.FillAttributes(color: fill, rule: state.fillRule)
        }
    }

    /// What a gradient paints: the gradient itself, or a solid colour when it has a single stop.
    enum GradientPaint {
        case linear(LayerTree.LinearGradient)
        case radial(LayerTree.RadialGradient)
        case color(LayerTree.Color)
    }

    /// nil when the url does not name a gradient, or the gradient has no stops.
    func makeGradientPaint(for gradientId: URL) -> GradientPaint? {
        let id = gradientId.fragmentID
        if let element = svg.defs.linearGradients.first(where: { $0.id == id }) {
            if let color = makeSolidColor(for: .linear(element)) {
                return .color(color)
            }
            return makeGradient(for: element).map(GradientPaint.linear)
        } else if let element = svg.defs.radialGradients.first(where: { $0.id == id }) {
            if let color = makeSolidColor(for: .radial(element)) {
                return .color(color)
            }
            return makeGradient(for: element).map(GradientPaint.radial)
        }
        return nil
    }

    // SVG 1.1 §13.2.4: a gradient with a single stop paints the colour of that stop.
    func makeSolidColor(for element: GradientElement) -> LayerTree.Color? {
        let stops = makeGradientStops(for: makeGradientChain(from: element))
        guard stops.count == 1, let stop = stops.first else { return nil }
        return stop.color.withMultiplyingAlpha(stop.opacity)
    }

    func makeTextAttributes(with state: State) -> LayerTree.TextAttributes {
        var state = state
        state.fill = resolveFallback(state.fill)
        let fill = LayerTree.Color
            .create(from: state.fill.makeColor(), current: state.color)
            .withAlpha(state.fillOpacity).maybeNone()

        return LayerTree.TextAttributes(
            color: fill,
            font: state.fontFamily.flatMap { makeFonts(with: $0, weight: state.fontWeight, style: state.fontStyle) },
            size: state.fontSize,
            weight: state.fontWeight,
            isItalic: state.fontStyle != .normal,
            anchor: state.textAnchor,
            baseline: state.alignmentBaseline ?? state.textBaseline
        )
    }

    func makeFonts(
        with font: DOM.FontFamily,
        weight: Int = 400,
        style: DOM.FontStyle = .normal
    ) -> [LayerTree.TextAttributes.Font] {
        switch font {
        case .name(let name):
            return makeFonts(faceName: name, weight: weight, style: style)
        case .keyword(.serif):
            return [.name("Times")]
        case .keyword(.sansSerif):
            return [.name("Helvetica")]
        case .keyword(.monospace):
            return [.name("Courier")]
        case .keyword(.fantasy):
            return [.name("Papyrus")]
        case .keyword(.cursive):
            return [.name("Apple Chancery")]
        }
    }

    /// The `@font-face` fonts of a family that best match the weight and style, or the family by name
    /// when the document declares none (the renderer then picks the weight and style from the system).
    func makeFonts(
        faceName: String,
        weight: Int = 400,
        style: DOM.FontStyle = .normal
    ) -> [LayerTree.TextAttributes.Font] {
        let faces = Self.matchFontFaces(svg.fontFaces(for: faceName), weight: weight, style: style)
        // each face uses the first of its sources that loads (a local font that is installed, a URL that decodes)
        let fonts = faces.compactMap { face -> LayerTree.TextAttributes.Font? in
            guard let font = face.src.lazy.compactMap({ try? self.makeFont(for: $0) }).first else { return nil }
            let synthesis = Self.makeFontSynthesis(for: face, weight: weight, style: style)
            return synthesis.isEmpty ? font : .synthesized(font, synthesis)
        }

        guard !fonts.isEmpty else {
            return [.name(faceName)]
        }
        return fonts
    }

    /// CSS Fonts 4 §5.2 font matching: the faces of one family closest in style, then in weight. Every face
    /// with that style and weight is kept, so faces split by `unicode-range` still cascade together.
    static func matchFontFaces(_ faces: [DOM.FontFace], weight: Int, style: DOM.FontStyle) -> [DOM.FontFace] {
        let stylePreference: [DOM.FontStyle]
        switch style {
        case .normal: stylePreference = [.normal, .oblique, .italic]
        case .italic: stylePreference = [.italic, .oblique, .normal]
        case .oblique: stylePreference = [.oblique, .italic, .normal]
        }
        guard let bestStyle = stylePreference.first(where: { s in faces.contains { $0.style == s } }) else {
            return []
        }
        let candidates = faces.filter { $0.style == bestStyle }
        func rank(_ range: ClosedRange<Int>) -> (Int, Int) { fontWeightRank(range, for: weight) }
        guard let best = candidates.map({ rank($0.weight) }).min(by: { $0 < $1 }) else { return [] }
        return candidates.filter { rank($0.weight) == best }
    }

    /// How well a face of `weights` matches the desired `weight` in CSS Fonts 4 §5.2 step 4; lower
    /// is better: (tier, distance), where the tier orders the directions searched. Between 400 and
    /// 500, heavier faces up to 500 come first, then lighter, then heavier; below 400 lighter first;
    /// above 500 heavier first.
    static func fontWeightRank(_ weights: ClosedRange<Int>, for weight: Int) -> (Int, Int) {
        if weights.contains(weight) { return (0, 0) }
        let below = weights.upperBound < weight
        let distance = below ? weight - weights.upperBound : weights.lowerBound - weight
        switch weight {
        case 400...500:
            if !below && weights.lowerBound <= 500 { return (1, distance) }
            return below ? (2, distance) : (3, distance)
        case ..<400:
            return below ? (1, distance) : (2, distance)
        default:
            return below ? (2, distance) : (1, distance)
        }
    }

    /// The bold and oblique an `@font-face` face needs synthesized, from its declared `font-weight` and
    /// `font-style` (not the font file's own): bold when 600 or heavier is asked for and the face is
    /// lighter, oblique when italic or oblique is asked for and the face is normal.
    static func makeFontSynthesis(for face: DOM.FontFace, weight: Int, style: DOM.FontStyle) -> LayerTree.FontSynthesis
    {
        LayerTree.FontSynthesis(
            weight: weight,
            isItalic: style != .normal,
            faceWeight: min(max(weight, face.weight.lowerBound), face.weight.upperBound),
            faceIsItalic: face.style != .normal
        )
    }

    func makeFont(for source: DOM.FontFace.Source) throws -> LayerTree.TextAttributes.Font {
        switch source {
        case .local(let name):
            // CSS Fonts 4 §4.3.2: an installed face by full name or PostScript name; when it is not
            // installed this source fails and the next one in `src` is tried
            #if canImport(CoreText)
            guard let postScriptName = CGProvider.installedFontPostScriptName(name) else {
                throw LayerTree.Error.invalid("font not installed: \(name)")
            }
            return .postScript(postScriptName)
            #else
            return .postScript(name)
            #endif
        case let .url(url: url, format: format):
            if let (mime, data) = url.decodedData {
                if mime == "font/truetype" || format == "truetype" {
                    return .truetype(data)
                } else if mime == "font/woff" || format == "woff" {
                    #if canImport(Compression)
                    let decoded = try WOFF(data: data)
                    return .truetype(decoded.fontData)
                    #else
                    throw LayerTree.Error.invalid("unsupported font: \(mime)")
                    #endif
                } else if mime == "font/woff2" || format == "woff2" {
                    #if canImport(Compression)
                    let decoded = try WOFF2(data: data)
                    return .truetype(decoded.fontData)
                    #else
                    throw LayerTree.Error.invalid("unsupported font: \(mime)")
                    #endif
                } else {
                    throw LayerTree.Error.invalid("unsupported font: \(mime)")
                }
            } else {
                throw LayerTree.Error.invalid("unsupported format: \(format ?? "unknown")")
            }
        }
    }

    func makePattern(for element: DOM.Pattern) -> LayerTree.Pattern {
        // SVG 1.1 §13.3: attributes not set on this element, and its children when it has none,
        // are inherited along the xlink:href chain.
        let chain = makePatternChain(for: element)
        func inherited<T>(_ value: (DOM.Pattern) -> T?) -> T? {
            chain.lazy.compactMap(value).first
        }

        let units: LayerTree.PatternUnits =
            inherited(\.patternUnits) == .userSpaceOnUse ? .userSpaceOnUse : .objectBoundingBox

        // Percentages are fractions of the bounding box under objectBoundingBox, and of the
        // viewport (in user units) under userSpaceOnUse: as in WebKit, the viewport the
        // referenced pattern is defined in, also for values it inherits.
        let viewport = userSpaceViewport(element.viewport)
        func geometry(
            _ key: String,
            _ value: (DOM.Pattern) -> DOM.Coordinate?,
            viewport length: LayerTree.Float
        ) -> LayerTree.Float {
            guard let source = chain.first(where: { value($0) != nil }),
                let coordinate = value(source)
            else { return 0 }
            if units == .userSpaceOnUse && source.percentageAttributes.contains(key) {
                return coordinate * length
            }
            return coordinate
        }

        let frame = LayerTree.Rect(
            x: geometry("x", \.x, viewport: viewport.width),
            y: geometry("y", \.y, viewport: viewport.height),
            width: geometry("width", \.width, viewport: viewport.width),
            height: geometry("height", \.height, viewport: viewport.height)
        )
        let contentUnits: LayerTree.PatternUnits =
            inherited(\.patternContentUnits) == .objectBoundingBox ? .objectBoundingBox : .userSpaceOnUse
        let pattern = LayerTree.Pattern(frame: frame, contentUnits: contentUnits, units: units)
        if let viewBox = inherited(\.viewBox) {
            pattern.viewBox = LayerTree.Rect(x: viewBox.x, y: viewBox.y, width: viewBox.width, height: viewBox.height)
        }
        pattern.preserveAspectRatio = inherited(\.preserveAspectRatio) ?? .default
        // transform-origin belongs to the pattern whose patternTransform applies
        let transformSource = chain.first { $0.patternTransform != nil }
        pattern.transform = Self.createTransforms(
            from: transformSource?.patternTransform ?? [],
            origin: transformSource?.transformOrigin,
            viewport: viewport
        ).toMatrix()
        let template = chain.first(where: { !$0.childElements.isEmpty })
        // the contents inherit from the pattern's ancestors, not from the element it fills
        let state = makeInheritedState(from: template?.ancestors ?? [])
        // A pattern reached again inside itself paints nothing
        building(element.id, cycle: ()) {
            buildingContents {
                pattern.contents = (template?.childElements ?? []).map {
                    .layer(makeLayer(from: $0, inheriting: state))
                }
            }
        }
        return pattern
    }

    /// The pattern followed by the patterns it references through href; a cycle or a reference
    /// that is not a pattern ends the chain.
    func makePatternChain(for element: DOM.Pattern) -> [DOM.Pattern] {
        var chain = [element]
        var visited: Set<String> = [element.id]
        var current = element
        while let id = current.href?.fragmentID,
            !visited.contains(id),
            let next = svg.defs.patterns.first(where: { $0.id == id })
        {
            visited.insert(id)
            chain.append(next)
            current = next
        }
        return chain
    }

    func makeGradient(for element: DOM.LinearGradient) -> LayerTree.LinearGradient? {
        let chain = makeGradientChain(from: .linear(element))
        let stops = makeGradientStops(for: chain)
        guard stops.count > 1 else {
            return nil
        }

        let units = Self.createUnits(from: chain.lazy.compactMap(\.units).first)
        // as in WebKit, percentages resolve in the viewport the referenced gradient is defined in,
        // also for values it inherits
        let geometry = GradientGeometry(
            chain: chain.compactMap(\.linear),
            percentageAttributes: \.percentageAttributes,
            units: units,
            viewport: userSpaceViewport(element.viewport)
        )

        // SVG 1.1 §13.2.2: x1, y1, y2 default to 0% and x2 to 100%
        var gradient = LayerTree.LinearGradient(
            gradient: .init(stops: stops),
            start: Point(geometry.x("x1", \.x1) ?? geometry.width(0), geometry.y("y1", \.y1) ?? geometry.height(0)),
            end: Point(geometry.x("x2", \.x2) ?? geometry.width(1), geometry.y("y2", \.y2) ?? geometry.height(0))
        )

        gradient.units = units
        gradient.transform = makeGradientTransform(for: chain, viewport: geometry.viewport)
        gradient.gradient.interpolation = Self.createInterpolation(from: element.colorInterpolation)
        gradient.spread = Self.createSpread(from: chain.lazy.compactMap(\.spreadMethod).first)
        return gradient
    }

    func makeGradient(for element: DOM.RadialGradient) -> LayerTree.RadialGradient? {
        let chain = makeGradientChain(from: .radial(element))
        let stops = makeGradientStops(for: chain)
        guard stops.count > 1 else {
            return nil
        }

        let units = Self.createUnits(from: chain.lazy.compactMap(\.units).first)
        // as in WebKit, percentages resolve in the viewport the referenced gradient is defined in,
        // also for values it inherits
        let geometry = GradientGeometry(
            chain: chain.compactMap(\.radial),
            percentageAttributes: \.percentageAttributes,
            units: units,
            viewport: userSpaceViewport(element.viewport)
        )

        // SVG 1.1 §13.2.3: cx, cy, r default to 50%; fx, fy to cx, cy; fr (SVG 2) to 0%
        let cx = geometry.x("cx", \.cx) ?? geometry.width(0.5)
        let cy = geometry.y("cy", \.cy) ?? geometry.height(0.5)
        var gradient = LayerTree.RadialGradient(
            gradient: .init(stops: stops),
            center: LayerTree.Point(geometry.x("fx", \.fx) ?? cx, geometry.y("fy", \.fy) ?? cy),
            radius: geometry.length("fr", \.fr) ?? geometry.diagonal(0),
            endCenter: LayerTree.Point(cx, cy),
            endRadius: geometry.length("r", \.r) ?? geometry.diagonal(0.5)
        )
        gradient.units = units
        gradient.transform = makeGradientTransform(for: chain, viewport: geometry.viewport)
        gradient.gradient.interpolation = Self.createInterpolation(from: element.colorInterpolation)
        return gradient
    }

    /// The gradientTransform of a chain, from the first gradient that has one, around that gradient's `transform-origin`.
    func makeGradientTransform(for chain: [GradientElement], viewport: LayerTree.Size) -> [LayerTree.Transform] {
        let source = chain.first { $0.hasTransform || !$0.transform.isEmpty }
        return Self.createTransforms(from: source?.transform ?? [], origin: source?.transformOrigin, viewport: viewport)
    }

    /// The viewport that percentages resolve against in user space: the one a paint server was
    /// defined in, or the root's when that is unknown.
    func userSpaceViewport(_ viewport: SwiftDrawDOM.XMLParser.Viewport?) -> LayerTree.Size {
        if let viewport {
            return LayerTree.Size(LayerTree.Float(viewport.width), LayerTree.Float(viewport.height))
        }
        return svg.viewBox.map { LayerTree.Size($0.width, $0.height) }
            ?? LayerTree.Size(LayerTree.Float(svg.width), LayerTree.Float(svg.height))
    }

    /// Resolves gradient geometry inherited along an href chain. Under objectBoundingBox the
    /// stored values (percentages as fractions) are used as is; under userSpaceOnUse a
    /// percentage, or a default written as one, is a fraction of the viewport: its width for x,
    /// height for y and normalised diagonal for other lengths (SVG 1.1 §7.10).
    struct GradientGeometry<Element> {
        var chain: [Element]
        var percentageAttributes: (Element) -> Set<String>
        var units: LayerTree.Gradient.Units
        var viewport: LayerTree.Size

        func x(_ key: String, _ value: (Element) -> DOM.Coordinate?) -> LayerTree.Float? {
            resolve(key, value, against: viewport.width)
        }

        func y(_ key: String, _ value: (Element) -> DOM.Coordinate?) -> LayerTree.Float? {
            resolve(key, value, against: viewport.height)
        }

        func length(_ key: String, _ value: (Element) -> DOM.Coordinate?) -> LayerTree.Float? {
            resolve(key, value, against: viewport.normalizedDiagonal)
        }

        func width(_ fraction: LayerTree.Float) -> LayerTree.Float { scale(fraction, by: viewport.width) }
        func height(_ fraction: LayerTree.Float) -> LayerTree.Float { scale(fraction, by: viewport.height) }
        func diagonal(_ fraction: LayerTree.Float) -> LayerTree.Float {
            scale(fraction, by: viewport.normalizedDiagonal)
        }

        private func scale(_ fraction: LayerTree.Float, by length: LayerTree.Float) -> LayerTree.Float {
            units == .userSpaceOnUse ? fraction * length : fraction
        }

        private func resolve(
            _ key: String,
            _ value: (Element) -> DOM.Coordinate?,
            against length: LayerTree.Float
        ) -> LayerTree.Float? {
            guard let source = chain.first(where: { value($0) != nil }),
                let coordinate = value(source)
            else { return nil }
            let isPercentage = percentageAttributes(source).contains(key)
            return isPercentage ? scale(LayerTree.Float(coordinate), by: length) : LayerTree.Float(coordinate)
        }
    }

    enum GradientElement {
        case linear(DOM.LinearGradient)
        case radial(DOM.RadialGradient)

        var linear: DOM.LinearGradient? {
            guard case let .linear(element) = self else { return nil }
            return element
        }

        var radial: DOM.RadialGradient? {
            guard case let .radial(element) = self else { return nil }
            return element
        }

        var id: String {
            switch self {
            case let .linear(element): return element.id
            case let .radial(element): return element.id
            }
        }

        var href: URL? {
            switch self {
            case let .linear(element): return element.href
            case let .radial(element): return element.href
            }
        }

        var units: DOM.LinearGradient.Units? {
            switch self {
            case let .linear(element): return element.gradientUnits
            case let .radial(element): return element.gradientUnits
            }
        }

        var transform: [DOM.Transform] {
            switch self {
            case let .linear(element): return element.gradientTransform
            case let .radial(element): return element.gradientTransform
            }
        }

        var hasTransform: Bool {
            switch self {
            case let .linear(element): return element.hasGradientTransform
            case let .radial(element): return element.hasGradientTransform
            }
        }

        var transformOrigin: DOM.TransformOrigin? {
            switch self {
            case let .linear(element): return element.transformOrigin
            case let .radial(element): return element.transformOrigin
            }
        }

        var spreadMethod: DOM.LinearGradient.SpreadMethod? {
            switch self {
            case let .linear(element): return element.spreadMethod
            case let .radial(element): return element.spreadMethod
            }
        }
    }

    // SVG 1.1 §13.2.2 / §13.2.3: attributes and stops not specified on a gradient are
    // inherited through xlink:href from gradients of either kind; geometry only from the same kind.
    func makeGradientChain(from element: GradientElement) -> [GradientElement] {
        var chain = [element]
        var visited: Set<String> = [element.id]
        var next = element.href?.fragmentID
        while let id = next, visited.insert(id).inserted {
            if let linear = svg.defs.linearGradients.first(where: { $0.id == id }) {
                chain.append(.linear(linear))
            } else if let radial = svg.defs.radialGradients.first(where: { $0.id == id }) {
                chain.append(.radial(radial))
            } else {
                break
            }
            next = chain.last?.href?.fragmentID
        }
        return chain
    }

    func makeGradientStops(for chain: [GradientElement]) -> [LayerTree.Gradient.Stop] {
        for element in chain {
            let stops: [LayerTree.Gradient.Stop]
            switch element {
            case let .linear(element): stops = makeGradientStops(for: element)
            case let .radial(element): stops = makeGradientStops(for: element)
            }
            if !stops.isEmpty {
                return Self.makeMonotonic(stops)
            }
        }
        return []
    }

    /// SVG 1.1 §13.2.4: offsets are clamped to 0...1, and an offset less than any before it
    /// takes the largest offset before it.
    /// Where three or more stops share an offset only the first and last can be seen: the colour
    /// changes from one to the other there, so the ones between are dropped. A pair at 0 keeps the
    /// first colour for the padding before the gradient, as WebKit and resvg do, so the second is
    /// moved just after 0 (CoreGraphics pads with the last stop at 0).
    static func makeMonotonic(_ stops: [LayerTree.Gradient.Stop]) -> [LayerTree.Gradient.Stop] {
        var previous: LayerTree.Float = 0
        let clamped = stops.map {
            var stop = $0
            stop.offset = max(previous, min(1, stop.offset.isFinite ? stop.offset : 0))
            previous = stop.offset
            return stop
        }

        var result = [LayerTree.Gradient.Stop]()
        for (index, stop) in clamped.enumerated() {
            let isBetween =
                index > 0 && index < clamped.count - 1 && clamped[index - 1].offset == stop.offset
                && clamped[index + 1].offset == stop.offset
            if !isBetween {
                result.append(stop)
            }
        }
        if result.count > 1, result[0].offset == 0, result[1].offset == 0 {
            let next = result.count > 2 ? result[2].offset : 1
            result[1].offset = min(minimumStopOffset, next)
        }
        return result
    }

    /// The offset a second stop at 0 is moved to: small enough not to be seen.
    static var minimumStopOffset: LayerTree.Float { 1e-5 }

    /// The `color-interpolation` in effect on a `<mask>`: its own, or inherited from its ancestors.
    func makeColorInterpolation(for mask: DOM.Mask) -> DOM.ColorInterpolation? {
        (mask.ancestors + [mask]).lazy.reversed()
            .compactMap { DOM.presentationAttributes(for: $0, styles: self.svg.styles).colorInterpolation }
            .first
    }

    static func createInterpolation(from interpolation: DOM.ColorInterpolation?) -> LayerTree.Gradient.Interpolation {
        interpolation == .linearRGB ? .linearRGB : .sRGB
    }

    func makeGradientStops(for element: DOM.LinearGradient) -> [LayerTree.Gradient.Stop] {
        return element.stops.map {
            LayerTree.Gradient.Stop(
                offset: $0.offset,
                color: LayerTree.Color.create(from: $0.color, current: .none),
                opacity: $0.opacity
            )
        }
    }

    func makeGradientStops(for element: DOM.RadialGradient) -> [LayerTree.Gradient.Stop] {
        return element.stops.map {
            LayerTree.Gradient.Stop(
                offset: $0.offset,
                color: LayerTree.Color.create(from: $0.color, current: .none),
                opacity: $0.opacity
            )
        }
    }

    //current state of the render tree, updated as builder traverses child nodes
    struct State {
        var opacity: DOM.Float
        var display: DOM.DisplayMode
        var visibility: DOM.Visibility
        var color: DOM.Color

        var stroke: DOM.Fill
        var strokeWidth: DOM.Float
        var strokeOpacity: DOM.Float
        var strokeLineCap: DOM.LineCap
        var strokeLineJoin: DOM.LineJoin
        var strokeLineMiterLimit: DOM.Float
        var strokeDashArray: [DOM.DashLength]
        var strokeDashOffset: DOM.DashLength

        var fill: DOM.Fill
        var fillOpacity: DOM.Float
        var fillRule: DOM.FillRule

        var fontFamily: [DOM.FontFamily]
        var fontSize: DOM.Float
        /// The numeric weight, with `bolder` and `lighter` already resolved
        var fontWeight: Int
        var fontStyle: DOM.FontStyle
        var textAnchor: DOM.TextAnchor
        /// `dominant-baseline`, inherited
        var textBaseline: DOM.TextBaseline
        /// `alignment-baseline` of the element itself (not inherited); nil uses `textBaseline`
        var alignmentBaseline: DOM.TextBaseline?
        /// `baseline-shift` of the element itself, for a child's `inherit`
        var baselineShift: DOM.BaselineShift?
        /// the `baseline-shift` of the text content element and each of its text content ancestors,
        /// outermost first, with the font-size each was declared at: they add up
        var baselineShifts: [BaselineShiftEntry] = []
        /// CSS `letter-spacing` and `word-spacing`, computed: inherited as absolute lengths
        var letterSpacing: DOM.Float
        var wordSpacing: DOM.Float

        var markerStart: DOM.URL?
        var markerMid: DOM.URL?
        var markerEnd: DOM.URL?
        var paintOrder: DOM.PaintOrder

        init() {
            //default root SVG element state
            self.opacity = 1.0
            self.display = .inline
            self.visibility = .visible
            self.color = .keyword(.black)

            self.stroke = .color(.none)
            self.strokeWidth = 1.0
            self.strokeOpacity = 1.0
            self.strokeLineCap = .butt
            self.strokeLineJoin = .miter
            self.strokeLineMiterLimit = 4.0
            self.strokeDashArray = []
            self.strokeDashOffset = .absolute(0)

            self.fill = .color(.keyword(.black))
            self.fillOpacity = 1.0
            self.fillRule = .nonzero
            self.textAnchor = .start
            self.letterSpacing = 0
            self.wordSpacing = 0
            self.textBaseline = .auto

            self.fontFamily = [.keyword(.serif)]
            self.fontSize = DOM.FontSize.initial
            self.fontWeight = 400
            self.fontStyle = .normal
            self.paintOrder = .normal
        }
    }

    struct BaselineShiftEntry {
        var shift: DOM.BaselineShift
        var fontSize: DOM.Float
    }

    func createState(for element: DOM.GraphicsElement, inheriting existing: State) -> State {
        var state = createReferencedState(for: element, inheriting: existing)
        // recursive references to patterns and markers are dropped (see makeInvalidReferences)
        guard !invalidReferences.isEmpty else { return state }
        if isInvalid(element, .fill) { state.fill = .color(.none) }
        if isInvalid(element, .stroke) { state.stroke = .color(.none) }
        if isInvalid(element, .markerStart) { state.markerStart = nil }
        if isInvalid(element, .markerMid) { state.markerMid = nil }
        if isInvalid(element, .markerEnd) { state.markerEnd = nil }
        return state
    }

    static func createState(
        for attributes: DOM.PresentationAttributes,
        inheriting existing: State,
        viewportDiagonal: LayerTree.Float
    ) -> State {
        var state = State()
        // `em`, `%`, keywords, `larger` and `smaller` resolve against the parent (CSS Fonts 4 §2.5);
        // the `em` lengths below resolve against this computed size
        state.fontSize = attributes.fontSize?.resolved(inheriting: existing.fontSize) ?? existing.fontSize
        // an `em` is computed where it is declared and inherited as an absolute length (CSS Values 4 §6.1)
        func computed(_ length: DOM.DashLength) -> DOM.DashLength {
            guard case .em(let value) = length else { return length }
            return .absolute(value * state.fontSize)
        }

        state.opacity = attributes.opacity ?? 1.0
        state.display = attributes.display ?? existing.display
        state.visibility = attributes.visibility ?? existing.visibility
        // CSS Color 4: `color: currentColor` is the inherited `color`
        if let color = attributes.color, color != .currentColor {
            state.color = color
        } else {
            state.color = existing.color
        }

        state.stroke = attributes.stroke ?? existing.stroke
        state.strokeWidth =
            attributes.strokeWidth.map {
                resolve($0, fontSize: state.fontSize, viewportDiagonal: viewportDiagonal)
            } ?? existing.strokeWidth
        state.strokeOpacity = attributes.strokeOpacity ?? existing.strokeOpacity
        state.strokeLineCap = attributes.strokeLineCap ?? existing.strokeLineCap
        state.strokeLineJoin = attributes.strokeLineJoin ?? existing.strokeLineJoin
        state.strokeDashArray = attributes.strokeDashArray?.map(computed) ?? existing.strokeDashArray
        state.strokeDashOffset = attributes.strokeDashOffset.map(computed) ?? existing.strokeDashOffset

        state.fill = attributes.fill ?? existing.fill
        state.fillOpacity = attributes.fillOpacity ?? existing.fillOpacity
        state.fillRule = attributes.fillRule ?? existing.fillRule

        state.fontFamily = attributes.fontFamily ?? existing.fontFamily
        state.fontWeight = attributes.fontWeight?.resolved(inheriting: existing.fontWeight) ?? existing.fontWeight
        state.fontStyle = attributes.fontStyle ?? existing.fontStyle
        state.textAnchor = attributes.textAnchor ?? existing.textAnchor
        state.textBaseline = attributes.dominantBaseline.flatMap { $0 == .inherit ? nil : $0 } ?? existing.textBaseline
        switch attributes.alignmentBaseline {
        case .auto?, nil: state.alignmentBaseline = nil
        case .inherit?: state.alignmentBaseline = existing.alignmentBaseline
        case let baseline?: state.alignmentBaseline = baseline
        }
        state.baselineShift = attributes.baselineShift == .inherit ? existing.baselineShift : attributes.baselineShift
        state.baselineShifts = existing.baselineShifts
        // `em` is of the element's computed font-size; the parser resolves percentages of the viewport
        func spacing(_ length: DOM.DashLength) -> DOM.Float {
            switch length {
            case .absolute(let value): return value
            case .em(let value): return value * state.fontSize
            case .percentage(let value): return value / 100 * state.fontSize
            }
        }
        state.letterSpacing = attributes.letterSpacing.map(spacing) ?? existing.letterSpacing
        state.wordSpacing = attributes.wordSpacing.map(spacing) ?? existing.wordSpacing

        state.markerStart = attributes.markerStart ?? existing.markerStart
        state.markerMid = attributes.markerMid ?? existing.markerMid
        state.markerEnd = attributes.markerEnd ?? existing.markerEnd
        state.paintOrder = attributes.paintOrder ?? existing.paintOrder

        return state
    }
}

extension LayerTree.Builder {
    static func createTransform(for dom: DOM.Transform) -> [LayerTree.Transform] {
        switch dom {
        case let .matrix(a, b, c, d, e, f):
            let matrix = LayerTree.Transform.Matrix(
                a: Float(a),
                b: Float(b),
                c: Float(c),
                d: Float(d),
                tx: Float(e),
                ty: Float(f)
            )
            return [.matrix(matrix)]

        case let .translate(tx, ty):
            return [.translate(tx: Float(tx), ty: Float(ty))]

        case let .scale(sx, sy):
            return [.scale(sx: Float(sx), sy: Float(sy))]

        case .rotate(let angle):
            let radians = Float(angle) * Float.pi / 180.0
            return [.rotate(radians: radians)]

        case let .rotatePoint(angle, cx, cy):
            let radians = Float(angle) * Float.pi / 180.0
            let t1 = LayerTree.Transform.translate(tx: cx, ty: cy)
            let t2 = LayerTree.Transform.rotate(radians: radians)
            let t3 = LayerTree.Transform.translate(tx: -cx, ty: -cy)
            return [t1, t2, t3]

        case let .skewX(angle):
            let radians = Float(angle) * Float.pi / 180.0
            return [.skewX(angle: radians)]
        case let .skewY(angle):
            let radians = Float(angle) * Float.pi / 180.0
            return [.skewY(angle: radians)]
        }
    }

    static func createUnits(from units: DOM.LinearGradient.Units?) -> LayerTree.Gradient.Units {
        guard let units = units else {
            return .objectBoundingBox
        }
        switch units {
        case .objectBoundingBox:
            return .objectBoundingBox
        case .userSpaceOnUse:
            return .userSpaceOnUse
        }
    }

    static func createSpread(from spread: DOM.LinearGradient.SpreadMethod?) -> LayerTree.Gradient.Spread {
        switch spread {
        case .reflect:
            return .reflect
        case .repeat:
            return .repeat
        case .pad, nil:
            return .pad
        }
    }

    static func createTransforms(from transforms: [DOM.Transform]) -> [LayerTree.Transform] {
        return transforms.flatMap { createTransform(for: $0) }
    }

    /// A transform applied around its `transform-origin`: `translate(o) · transform · translate(-o)`
    /// (CSS Transforms 1 §6). Percentages and keywords resolve against `viewport`: SVG elements
    /// default to `transform-box: view-box`, as in resvg.
    static func createTransforms(
        from transforms: [DOM.Transform],
        origin: DOM.TransformOrigin?,
        viewport: LayerTree.Size
    ) -> [LayerTree.Transform] {
        let transform = createTransforms(from: transforms)
        guard !transform.isEmpty, let origin else { return transform }
        let x = origin.x.resolved(against: viewport.width)
        let y = origin.y.resolved(against: viewport.height)
        guard x.isFinite, y.isFinite, x != 0 || y != 0 else { return transform }
        return [.translate(tx: x, ty: y)] + transform + [.translate(tx: -x, ty: -y)]
    }

    /// The `transform` of an element's cascade around its `transform-origin`, with percentages of the root viewport.
    func createTransforms(from attributes: DOM.PresentationAttributes) -> [LayerTree.Transform] {
        Self.createTransforms(
            from: attributes.transform ?? [],
            origin: attributes.transformOrigin,
            viewport: userSpaceViewport(nil)
        )
    }
}

private extension DOM.Fill {

    func makeColor() -> DOM.Color {
        switch self {
        case .color(let c):
            return c
        case .url:
            return .none
        case .urlWithFallback(_, let c):
            return c
        }
    }
}

private extension DOM.SVG {

    func fontFaces(for family: String) -> [DOM.FontFace] {
        styles.flatMap { $0.fonts.filter { $0.family == family } }
    }
}

private extension LayerTree.Size {
    /// √(w² + h²) / √2, the reference for lengths that are neither horizontal nor vertical (SVG 1.1 §7.10).
    var normalizedDiagonal: LayerTree.Float {
        ((width * width + height * height) / 2).squareRoot()
    }
}
