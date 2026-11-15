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

        // The use, mask and pattern elements being built. Reaching one again is a cycle.
        private final class Active {
            var elements = Set<AnyHashable>()
            var depth = 0
            var total = 0
        }
        private let active = Active()

        /// References nested deeper than this are dropped: each level costs native stack.
        static let maxReferenceDepth = 16
        /// References expanded beyond this in one document are dropped: fan-out without a cycle,
        /// such as each level using the previous one several times, grows exponentially.
        static let maxReferences = 20_000

        init(svg: DOM.SVG) {
            self.svg = svg
        }

        /// Builds a referenced use, mask or pattern, or returns `cycle` when the reference is
        /// already being built or exceeds the depth or document budget.
        func building<R>(_ key: some Hashable, cycle: R, _ build: () throws -> R) rethrows -> R {
            guard active.depth < Self.maxReferenceDepth,
                  active.total < Self.maxReferences,
                  active.elements.insert(key).inserted else { return cycle }
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
            l.transform = Builder.makeTransform(
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
            width: DOM.Length,
            height: DOM.Length,
            preserveAspectRatio: DOM.PreserveAspectRatio? = nil
        ) -> [LayerTree.Transform] {
            let fit = makeViewBoxFit(viewBox: viewBox, width: width, height: height, preserveAspectRatio: preserveAspectRatio)
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
            width: DOM.Length,
            height: DOM.Length,
            preserveAspectRatio: DOM.PreserveAspectRatio?
        ) -> (viewBox: DOM.SVG.ViewBox, sx: LayerTree.Float, sy: LayerTree.Float, tx: LayerTree.Float, ty: LayerTree.Float) {
            var box = DOM.SVG.ViewBox(x: 0, y: 0, width: .init(width), height: .init(height))
            if let viewBox, viewBox.x.isFinite, viewBox.y.isFinite,
               viewBox.width.isFinite, viewBox.height.isFinite,
               viewBox.width > 0, viewBox.height > 0 {
                box = viewBox
            }
            // an empty or non-finite viewport (or one that overflows the fit) has no mapping: identity
            guard box.width > 0, box.height > 0, width > 0, height > 0 else {
                return (box, 1, 1, 0, 0)
            }
            let fit = (preserveAspectRatio ?? .default).fit(
                contentWidth: box.width, contentHeight: box.height,
                viewportWidth: .init(width), viewportHeight: .init(height)
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
            width: DOM.Length,
            height: DOM.Length,
            preserveAspectRatio: DOM.PreserveAspectRatio?
        ) -> LayerTree.Rect {
            let fit = makeViewBoxFit(viewBox: viewBox, width: width, height: height, preserveAspectRatio: preserveAspectRatio)
            return LayerTree.Rect(
                x: fit.viewBox.x - fit.tx / fit.sx,
                y: fit.viewBox.y - fit.ty / fit.sy,
                width: LayerTree.Float(width) / fit.sx,
                height: LayerTree.Float(height) / fit.sy
            )
        }

        func makeLayer(from root: DOM.GraphicsElement, inheriting previousState: State) -> Layer {
            var stack: [(DOM.GraphicsElement, State, Layer?)] = [(root, previousState, nil)]
            var resultLayer: Layer? = nil

            while let (currentElement, currentState, parentLayer) = stack.popLast() {
                let newState = createState(for: currentElement, inheriting: currentState)
                // SVG 1.1 §11.6.2: `display="none"` removes the element and its whole subtree from rendering,
                // before any transform, clip, mask, filter or opacity is built for it
                if newState.display == .none || Self.isHiddenLeaf(currentElement, newState) {
                    if parentLayer == nil {
                        resultLayer = Layer()
                    }
                    continue
                }
                let layer = makeBaseLayer(from: currentElement, with: newState)

                if let contents = makeContents(from: currentElement, with: newState) {
                    layer.appendContents(contents)
                } else if let container = currentElement as? any ContainerElement {
                    // Push children in reverse so they are processed in the original order
                    for child in container.childElements.reversed() {
                        stack.append((child, newState, layer))
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

        func makeBaseLayer(from element: DOM.GraphicsElement, with state: State) -> Layer {
            let attributes = element.attributes
            let l = Layer()
            l.class = element.class
            l.transform = Builder.createTransforms(from: attributes.transform ?? [])
            l.clip = makeClipShapes(for: element)
            l.clipRule = attributes.clipRule
            l.clipUnits = makeClipUnits(for: element)
            l.mask = createMaskLayer(for: element)
            l.opacity = state.opacity
            if let filter = makeFilter(for: element) {
                l.filters = filter.effects
                l.filterRegion = makeFilterRegion(for: filter)
            }
            return l
        }

        func makeContents(from element: DOM.GraphicsElement, with state: State) -> Layer.Contents? {
            // SVG 1.1 §11.6.2: `visibility` hides graphics only; a child may set `visible` again
            let isVisible = state.visibility == .visible
            if let shape = Builder.makeShape(from: element) {
                return isVisible ? makeShapeContents(from: shape, with: state) : nil
            } else if let text = element as? DOM.Text {
                return isVisible ? makeTextContents(from: text, with: state) : nil
            } else if let image = element as? DOM.Image {
                return isVisible ? try? Builder.makeImageContents(from: image) : nil
            } else if let use = element as? DOM.Use {
                return try? makeUseLayerContents(from: use, with: state)
            } else if let sw = element as? DOM.Switch,
                      let e = sw.childElements.first {
                //TODO: select first element that creates non empty Layer
                return .layer(makeLayer(from: e, inheriting: state))
            }

            return nil
        }

        func makeClipShapes(for element: DOM.GraphicsElement) -> [ClipShape] {
            let attributes = DOM.presentationAttributes(for: element, styles: svg.styles)
            guard let clipID = attributes.clipPath?.fragmentID,
                  let clip = svg.defs.clipPaths.first(where: { $0.id == clipID }) else { return [] }
            let contributing = clip.childElements.filter(contributesToClip)
            // SVG 1.1 §14.3.5: a clipPath without contributing children clips everything away; a child
            // this builder cannot clip with (`<use>`, `<text>`) still contributes, so the element stays unclipped
            guard !contributing.isEmpty else {
                return [ClipShape(shape: .rect(within: .zero, radii: .zero), transform: .identity)]
            }
            return contributing.compactMap(makeClipShape)
        }

        func contributesToClip(_ element: DOM.GraphicsElement) -> Bool {
            // SVG 1.1 §14.3.5: children with `display="none"` or hidden `visibility` do not contribute to the clip
            let att = DOM.presentationAttributes(for: element, styles: svg.styles)
            return att.display != DOM.DisplayMode.none && (att.visibility ?? .visible) == .visible
        }

        func makeClipUnits(for element: DOM.GraphicsElement) -> ClipUnits {
            let attributes = DOM.presentationAttributes(for: element, styles: svg.styles)
            guard let clipID = attributes.clipPath?.fragmentID,
                  let clip = svg.defs.clipPaths.first(where: { $0.id == clipID }) else { return .userSpaceOnUse }
            switch clip.clipPathUnits {
            case .objectBoundingBox: return .objectBoundingBox
            case .userSpaceOnUse, nil: return .userSpaceOnUse
            }
        }

        func makeClipShape(for element: DOM.GraphicsElement) -> ClipShape? {
            guard let shape = Builder.makeShape(from: element) else {
                return nil
            }

            let transform = Self.createTransforms(from: element.attributes.transform ?? [])
                .toMatrix()

            return ClipShape(shape: shape, transform: transform)
        }

        func createMaskLayer(for element: DOM.GraphicsElement) -> Layer? {
            guard let maskId = element.attributes.mask?.fragmentID,
                  let mask = svg.defs.masks.first(where: { $0.id == maskId }) else { return nil }

            // A mask inside itself is empty, so it hides what it masks
            return building(ObjectIdentifier(mask), cycle: Layer()) {
                let l = Layer()
                if DOM.presentationAttributes(for: mask, styles: svg.styles).maskType == .alpha {
                    l.maskType = .alpha
                }

                var maskState = createState(for: mask, inheriting: State())
                // SVG 1.1 §11.5: `display` does not apply to `<mask>`; only its children can be hidden
                maskState.display = .inline
                mask.childElements.forEach {
                    let contents = Layer.Contents.layer(makeLayer(from: $0, inheriting: maskState))
                    l.appendContents(contents)
                }

                return l
            }
        }

        // `filter` is not inherited: it applies once, to the element that references it
        func makeFilter(for element: DOM.GraphicsElement) -> DOM.Filter? {
            let attributes = DOM.presentationAttributes(for: element, styles: svg.styles)
            guard let filterId = attributes.filter?.fragmentID else { return nil }
            return svg.defs.filters.first(where: { $0.id == filterId })
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

    func makeStrokeAttributes(with state: State) -> LayerTree.StrokeAttributes {
        let stroke: LayerTree.StrokeAttributes.Stroke

        if state.strokeWidth > 0.0 {
            switch resolveFallback(state.stroke) {
            case .color(let c):
                let color = LayerTree.Color
                    .create(from: c, current: state.color)
                    .withAlpha(state.strokeOpacity).maybeNone()
                stroke = .color(color)
            case .url(let gradientId):
                if let gradient = makeLinearGradient(for: gradientId) {
                    stroke = .linearGradient(gradient)
                } else if let gradient = makeRadialGradient(for: gradientId) {
                    stroke = .radialGradient(gradient)
                } else {
                    stroke = .color(.none)
                }
            case .urlWithFallback:
                stroke = .color(.none) // resolved to .url or .color above
            }
        } else {
            stroke = .color(.none)
        }

        return LayerTree.StrokeAttributes(color: stroke,
                                          width: state.strokeWidth,
                                          cap: state.strokeLineCap,
                                          join: state.strokeLineJoin,
                                          miterLimit: state.strokeLineMiterLimit,
                                          dashArray: makeDashArray(with: state),
                                          dashOffset: makeDashOffset(with: state))
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

    func makeDashLength(_ length: DOM.DashLength) -> LayerTree.Float {
        switch length {
        case .absolute(let value): return value
        case .percentage(let value): return value / 100 * viewportDiagonal
        }
    }

    func makeDashOffset(with state: State) -> LayerTree.Float {
        let offset = makeDashLength(state.strokeDashOffset)
        return offset.isFinite ? offset : 0
    }

    /// SVG 1.1 §11.4: odd-length lists repeat to even length; a zero sum renders solid.
    func makeDashArray(with state: State) -> [LayerTree.Float] {
        var lengths = state.strokeDashArray.map(makeDashLength)
        guard !lengths.isEmpty, lengths.allSatisfy({ $0 >= 0 && $0.isFinite }), lengths.reduce(0, +) > 0 else {
            return []
        }
        if lengths.count % 2 == 1 {
            lengths += lengths
        }
        return lengths
    }

    /// SVG 1.1 §11.2: a paint server that resolves wins; otherwise the fallback colour (`none` paints nothing).
    func resolveFallback(_ paint: DOM.Fill) -> DOM.Fill {
        guard case .urlWithFallback(let url, let color) = paint else { return paint }
        let resolves = url.fragmentID.map { id in
            svg.defs.patterns.contains(where: { $0.id == id }) ||
                makeLinearGradient(for: url) != nil ||
                makeRadialGradient(for: url) != nil
        } ?? false
        return resolves ? .url(url) : .color(color)
    }

    func makeFillAttributes(with state: State) -> LayerTree.FillAttributes {
        var state = state
        state.fill = resolveFallback(state.fill)
        let fill = LayerTree.Color
            .create(from: state.fill.makeColor(), current: state.color)
            .withAlpha(state.fillOpacity).maybeNone()

        if case .url(let patternId) = state.fill,
           let element = svg.defs.patterns.first(where: { $0.id == patternId.fragmentID }) {
            let pattern = makePattern(for: element)
            return LayerTree.FillAttributes(pattern: pattern, rule: state.fillRule, opacity: state.fillOpacity)
        } else if case .url(let gradientId) = state.fill,
                  let element = svg.defs.linearGradients.first(where: { $0.id == gradientId.fragmentID }),
                  let gradient = makeGradient(for: element) {
            return LayerTree.FillAttributes(linear: gradient, rule: state.fillRule, opacity: state.fillOpacity)
        } else if case .url(let gradientId) = state.fill,
                  let element = svg.defs.radialGradients.first(where: { $0.id == gradientId.fragmentID }),
                  let gradient = makeGradient(for: element) {
            return LayerTree.FillAttributes(radial: gradient, rule: state.fillRule, opacity: state.fillOpacity)
        } else {
            return LayerTree.FillAttributes(color: fill, rule: state.fillRule)
        }
    }

    func makeLinearGradient(for gradientId: URL) -> LayerTree.LinearGradient? {
        guard let element = svg.defs.linearGradients.first(where: { $0.id == gradientId.fragmentID }),
              let gradient = makeGradient(for: element) else {
            return nil
        }
        return gradient
    }

    func makeRadialGradient(for gradientId: URL) -> LayerTree.RadialGradient? {
        guard let element = svg.defs.radialGradients.first(where: { $0.id == gradientId.fragmentID }),
              let gradient = makeGradient(for: element) else {
            return nil
        }
        return gradient
    }

    func makeTextAttributes(with state: State) -> LayerTree.TextAttributes {
        var state = state
        state.fill = resolveFallback(state.fill)
        let fill = LayerTree.Color
            .create(from: state.fill.makeColor(), current: state.color)
            .withAlpha(state.fillOpacity).maybeNone()

        return LayerTree.TextAttributes(
            color: fill,
            font: state.fontFamily.flatMap(makeFonts),
            size: state.fontSize,
            anchor: state.textAnchor,
            baseline: state.textBaseline
        )
    }

    func makeFonts(with font: DOM.FontFamily) -> [LayerTree.TextAttributes.Font] {
        switch font {
        case .name(let name):
            return makeFonts(faceName: name)
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

    func makeFonts(faceName: String) -> [LayerTree.TextAttributes.Font] {
        let fonts = svg.fontSources(for: faceName)
            .compactMap { try? makeFont(for: $0) }

        guard !fonts.isEmpty else {
            return [.name(faceName)]
        }
        return fonts
    }

    func makeFont(for source: DOM.FontFace.Source) throws -> LayerTree.TextAttributes.Font {
        switch source {
        case .local(let name):
            return .name(name)
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

        let units: LayerTree.PatternUnits = inherited(\.patternUnits) == .userSpaceOnUse ? .userSpaceOnUse : .objectBoundingBox

        // Percentages are fractions of the bounding box under objectBoundingBox, and of the
        // viewport (in user units) under userSpaceOnUse.
        let viewport = svg.viewBox.map { LayerTree.Size($0.width, $0.height) }
            ?? LayerTree.Size(LayerTree.Float(svg.width), LayerTree.Float(svg.height))
        func geometry(_ key: String, _ value: (DOM.Pattern) -> DOM.Coordinate?, viewport length: LayerTree.Float) -> LayerTree.Float {
            guard let source = chain.first(where: { value($0) != nil }),
                  let coordinate = value(source) else { return 0 }
            if units == .userSpaceOnUse && source.percentageAttributes.contains(key) {
                return coordinate * length
            }
            return coordinate
        }

        let frame = LayerTree.Rect(x: geometry("x", \.x, viewport: viewport.width),
                                   y: geometry("y", \.y, viewport: viewport.height),
                                   width: geometry("width", \.width, viewport: viewport.width),
                                   height: geometry("height", \.height, viewport: viewport.height))
        let contentUnits: LayerTree.PatternUnits = inherited(\.patternContentUnits) == .objectBoundingBox ? .objectBoundingBox : .userSpaceOnUse
        let pattern = LayerTree.Pattern(frame: frame, contentUnits: contentUnits, units: units)
        if let viewBox = inherited(\.viewBox) {
            pattern.viewBox = LayerTree.Rect(x: viewBox.x, y: viewBox.y, width: viewBox.width, height: viewBox.height)
        }
        pattern.preserveAspectRatio = inherited(\.preserveAspectRatio) ?? .default
        pattern.transform = Self.createTransforms(from: inherited(\.patternTransform) ?? []).toMatrix()
        let children = chain.first(where: { !$0.childElements.isEmpty })?.childElements ?? []
        // A pattern inside itself is empty
        building(element.id, cycle: ()) {
            pattern.contents = children.compactMap { .layer(makeLayer(from: $0, inheriting: .init())) }
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
              let next = svg.defs.patterns.first(where: { $0.id == id }) {
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

        let linear = chain.compactMap(\.linear)
        var gradient = LayerTree.LinearGradient(
            gradient: .init(stops: stops),
            start: Point(linear.lazy.compactMap(\.x1).first ?? 0, linear.lazy.compactMap(\.y1).first ?? 0),
            end: Point(linear.lazy.compactMap(\.x2).first ?? 1, linear.lazy.compactMap(\.y2).first ?? 0)
        )

        gradient.units = Self.createUnits(from: chain.lazy.compactMap(\.units).first)
        gradient.transform = Self.createTransforms(from: chain.lazy.map(\.transform).first { !$0.isEmpty } ?? [])
        return gradient
    }

    func makeGradient(for element: DOM.RadialGradient) -> LayerTree.RadialGradient? {
        let chain = makeGradientChain(from: .radial(element))
        let stops = makeGradientStops(for: chain)
        guard stops.count > 1 else {
            return nil
        }

        let radial = chain.compactMap(\.radial)
        let cx = radial.lazy.compactMap(\.cx).first ?? 0.5
        let cy = radial.lazy.compactMap(\.cy).first ?? 0.5
        var gradient = LayerTree.RadialGradient(
            gradient: .init(stops: stops),
            center: LayerTree.Point(radial.lazy.compactMap(\.fx).first ?? cx, radial.lazy.compactMap(\.fy).first ?? cy),
            radius: LayerTree.Float(radial.lazy.compactMap(\.fr).first ?? 0),
            endCenter: LayerTree.Point(cx, cy),
            endRadius: LayerTree.Float(radial.lazy.compactMap(\.r).first ?? 0.5)
        )
        gradient.units = Self.createUnits(from: chain.lazy.compactMap(\.units).first)
        gradient.transform = Self.createTransforms(from: chain.lazy.map(\.transform).first { !$0.isEmpty } ?? [])
        return gradient
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
                return stops
            }
        }
        return []
    }

    func makeGradientStops(for element: DOM.LinearGradient) -> [LayerTree.Gradient.Stop] {
        return element.stops.map {
            LayerTree.Gradient.Stop(offset: $0.offset,
                                    color: LayerTree.Color.create(from: $0.color, current: .none),
                                    opacity: $0.opacity)
        }
    }

    func makeGradientStops(for element: DOM.RadialGradient) -> [LayerTree.Gradient.Stop] {
        return element.stops.map {
            LayerTree.Gradient.Stop(offset: $0.offset,
                                    color: LayerTree.Color.create(from: $0.color, current: .none),
                                    opacity: $0.opacity)
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
        var textAnchor: DOM.TextAnchor
        var textBaseline: DOM.TextBaseline

        init() {
            //default root SVG element state
            opacity = 1.0
            display = .inline
            visibility = .visible
            color = .keyword(.black)

            stroke = .color(.none)
            strokeWidth = 1.0
            strokeOpacity = 1.0
            strokeLineCap = .butt
            strokeLineJoin = .miter
            strokeLineMiterLimit = 4.0
            strokeDashArray = []
            strokeDashOffset = .absolute(0)

            fill = .color(.keyword(.black))
            fillOpacity = 1.0
            fillRule = .nonzero
            textAnchor = .start
            textBaseline = .auto

            fontFamily = [.keyword(.serif)]
            fontSize = 12.0
        }
    }

    func createState(for element: DOM.GraphicsElement, inheriting existing: State) -> State {
        let attributes = DOM.presentationAttributes(for: element, styles: svg.styles)
        return Self.createState(for: attributes, inheriting: existing)
    }

    static func createState(for attributes: DOM.PresentationAttributes, inheriting existing: State) -> State {
        var state = State()

        state.opacity = attributes.opacity ?? 1.0
        state.display = attributes.display ?? existing.display
        state.visibility = attributes.visibility ?? existing.visibility
        state.color = attributes.color ?? existing.color

        state.stroke = attributes.stroke ?? existing.stroke
        state.strokeWidth = attributes.strokeWidth ?? existing.strokeWidth
        state.strokeOpacity = attributes.strokeOpacity ?? existing.strokeOpacity
        state.strokeLineCap = attributes.strokeLineCap ?? existing.strokeLineCap
        state.strokeLineJoin = attributes.strokeLineJoin ?? existing.strokeLineJoin
        state.strokeDashArray = attributes.strokeDashArray ?? existing.strokeDashArray
        state.strokeDashOffset = attributes.strokeDashOffset ?? existing.strokeDashOffset

        state.fill = attributes.fill ?? existing.fill
        state.fillOpacity = attributes.fillOpacity ?? existing.fillOpacity
        state.fillRule = attributes.fillRule ?? existing.fillRule

        state.fontFamily = attributes.fontFamily ?? existing.fontFamily
        state.fontSize = attributes.fontSize ?? existing.fontSize
        state.textAnchor = attributes.textAnchor ?? existing.textAnchor
        state.textBaseline = attributes.dominantBaseline ?? existing.textBaseline

        return state
    }
}

extension LayerTree.Builder {
    static func createTransform(for dom: DOM.Transform) -> [LayerTree.Transform] {
        switch dom {
        case let .matrix(a, b, c, d, e, f):
            let matrix = LayerTree.Transform.Matrix(a: Float(a),
                                                    b: Float(b),
                                                    c: Float(c),
                                                    d: Float(d),
                                                    tx: Float(e),
                                                    ty: Float(f))
            return [.matrix(matrix)]

        case let .translate(tx, ty):
            return [.translate(tx: Float(tx), ty: Float(ty))]

        case let .scale(sx, sy):
            return [.scale(sx: Float(sx), sy: Float(sy))]

        case .rotate(let angle):
            let radians = Float(angle)*Float.pi/180.0
            return [.rotate(radians: radians)]

        case let .rotatePoint(angle, cx, cy):
            let radians = Float(angle)*Float.pi/180.0
            let t1 = LayerTree.Transform.translate(tx: cx, ty: cy)
            let t2 = LayerTree.Transform.rotate(radians: radians)
            let t3 = LayerTree.Transform.translate(tx: -cx, ty: -cy)
            return [t1, t2, t3]

        case let .skewX(angle):
            let radians = Float(angle)*Float.pi/180.0
            return [.skewX(angle: radians)]
        case let .skewY(angle):
            let radians = Float(angle)*Float.pi/180.0
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

    static func createTransforms(from transforms: [DOM.Transform]) -> [LayerTree.Transform] {
        return transforms.flatMap{ createTransform(for: $0) }
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

    func fontSources(for family: String) -> [DOM.FontFace.Source] {
        var sources = [DOM.FontFace.Source]()
        for style in styles {
            for font in style.fonts where font.family == family {
                sources.append(font.src)
            }
        }
        return sources
    }
}
