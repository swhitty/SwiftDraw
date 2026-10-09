//
//  LayerTree.CommandGenerator.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 5/6/17.
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
import SwiftDrawDOM

// Convert a LayerTree into RenderCommands

extension LayerTree {

    final class CommandGenerator<P: RendererTypeProvider> {

        let provider: P
        let size: LayerTree.Size
        let scale: LayerTree.Float
        let options: SVG.Options

        private var hasLoggedFilterWarning = false
        private var hasLoggedGradientWarning = false
        private var hasLoggedMaskWarning = false
        private var hasLoggedSpreadWarning = false

        private var paths: [LayerTree.Shape: P.Types.Path] = [:]
        private var images: [LayerTree.Image: P.Types.Image] = [:]

        init(provider: P, size: LayerTree.Size, scale: LayerTree.Float = 3.0, options: SVG.Options) {
            self.provider = provider
            self.size = size
            self.scale = scale
            self.options = options
        }

        func renderCommands(for l: Layer, colorConverter c: any ColorConverter) -> [RendererCommand<P.Types>] {
            var commands = [RendererCommand<P.Types>]()

            var stack: [RenderStep] = [
                .beginLayer(l, c)
            ]

            while let step = stack.popLast() {
                switch step {
                case let .beginLayer(layer, colorConverter):
                    let state = makeCommandState(for: layer, colorConverter: colorConverter)

                    //guard state.hasContents else { continue }
                    if let filterLayer = state.filterLayer, filterLayer.region.isEmpty {
                        // an empty filter region clips everything away (matches Chrome / Safari)
                        continue
                    }
                    if state.hasFilters && state.filterLayer == nil && layer.hasUnsupportedFilters {
                        if options.contains(.hideUnsupportedFilters) {
                            continue
                        }
                        logUnsupportedFilters(layer.filters)
                    }

                    stack.append(.endLayer(layer, state))

                    if state.hasOpacity || state.hasTransform || state.hasClip || state.hasMask {
                        commands.append(.pushState)
                    }

                    commands.append(contentsOf: renderCommands(forTransforms: layer.transform))
                    commands.append(contentsOf: renderCommands(forOpacity: layer.opacity))
                    commands.append(contentsOf: renderCommands(forClip: layer.clip, using: layer.clipRule))

                    if state.hasMask {
                        commands.append(.pushTransparencyLayer)
                    }

                    // filter is applied before clipping, masking and opacity
                    if let filterLayer = state.filterLayer {
                        commands.append(.pushFilterLayer(filterLayer))
                    }

                    //push render of all of the layer contents in reverse order
                    for contents in layer.contents.reversed() {
                        switch makeRenderContents(for: contents, colorConverter: colorConverter) {
                        case let .simple(cmd):
                            stack.append(.contents(cmd))
                        case let .layer(layer):
                            stack.append(.beginLayer(layer, colorConverter))
                        }
                    }

                case let .contents(cmd):
                    commands.append(contentsOf: cmd)

                case let .endLayer(layer, state):
                    if state.filterLayer != nil {
                        commands.append(.popFilterLayer)
                    }

                    //render apply mask
                    if state.hasMask {
                        commands.append(contentsOf: renderCommands(forMask: layer.mask))
                        commands.append(.popTransparencyLayer)
                    }

                    if state.hasOpacity {
                        commands.append(.popTransparencyLayer)
                    }

                    if state.hasOpacity || state.hasTransform || state.hasClip || state.hasMask {
                        commands.append(.popState)
                    }
                }
            }

            return commands
        }

        enum RenderStep {
            case beginLayer(LayerTree.Layer, any ColorConverter)
            case contents([RendererCommand<P.Types>])
            case endLayer(LayerTree.Layer, CommandState)
        }

        struct CommandState {
            var hasOpacity: Bool
            var hasTransform: Bool
            var hasClip: Bool
            var hasContents: Bool
            var hasMask: Bool
            var hasFilters: Bool
            var colorConverter: any ColorConverter
            var filterLayer: LayerTree.FilterLayer?
        }

        func makeCommandState(for layer: Layer, colorConverter: any ColorConverter) -> CommandState {
            var hasContents = !layer.contents.isEmpty && layer.opacity > 0.0
            let hasMask = layer.mask != nil
            let hasFilters = !layer.filters.isEmpty

            if hasMask && options.contains(.disableTransparencyLayers) {
                hasContents = false
            }

            if hasFilters && options.contains(.hideUnsupportedFilters) {
                hasContents = false
            }

            return CommandState(
                hasOpacity: layer.opacity < 1.0,
                hasTransform: !layer.transform.isEmpty,
                hasClip: !layer.clip.isEmpty,
                hasContents: hasContents,
                hasMask: hasMask,
                hasFilters: hasFilters,
                colorConverter: colorConverter,
                filterLayer: hasFilters ? makeFilterLayer(for: layer) : nil
            )
        }

        func renderCommands(for contents: Layer.Contents, colorConverter: any ColorConverter) -> [RendererCommand<P.Types>] {
            switch makeRenderContents(for: contents, colorConverter: colorConverter) {
            case .simple(let commands):
                return commands
            case .layer(let layer):
                return renderCommands(for: layer, colorConverter: colorConverter)
            }
        }

        enum RenderContents {
            // simple contents create array of commands
            case simple([RendererCommand<P.Types>])

            // layer contents requires recursion
            case layer(LayerTree.Layer)
        }

        func makeRenderContents(for contents: Layer.Contents, colorConverter: any ColorConverter) -> RenderContents  {
            switch contents {
            case .shape(let shape, let stroke, let fill):
                return .simple(renderCommands(for: shape, stroke: stroke, fill: fill, colorConverter: colorConverter))
            case .image(let image):
                return .simple(renderCommands(for: image))
            case .text(let text, let point, let att):
                return .simple(renderCommands(for: text, at: point, attributes: att, colorConverter: colorConverter))
            case .layer(let layer):
                return .layer(layer)
            }
        }

        func renderCommands(for shape: Shape,
                            stroke: StrokeAttributes,
                            fill: FillAttributes,
                            colorConverter: any ColorConverter) -> [RendererCommand<P.Types>] {
            var commands = [RendererCommand<P.Types>]()
            let path = makeCachedPath(from: shape)

            switch fill.fill {
            case .color(let color):
                if (color != .none) {
                    let converted = colorConverter.createColor(from: color)
                    let color = provider.createColor(from: converted)
                    let rule = provider.createFillRule(from: fill.rule)
                    commands.append(.setFill(color: color))
                    commands.append(.fill(path, rule: rule))
                }
            case .pattern(let fillPattern):
                if let (resolvedPattern, contentTransform) = Self.resolvePattern(fillPattern, in: provider.getBounds(from: shape)) {
                    var patternCommands = [RendererCommand<P.Types>]()
                    if contentTransform != .identity {
                        patternCommands.append(.pushState)
                        patternCommands.append(.concatenate(transform: provider.createTransform(from: contentTransform)))
                    }
                    for contents in resolvedPattern.contents {
                        patternCommands.append(contentsOf: renderCommands(for: contents, colorConverter: colorConverter))
                    }
                    if contentTransform != .identity {
                        patternCommands.append(.popState)
                    }

                    let pattern = provider.createPattern(from: resolvedPattern, contents: patternCommands)
                    let rule = provider.createFillRule(from: fill.rule)
                    commands.append(.setFillPattern(pattern))
                    commands.append(.fill(path, rule: rule))
                }
            case .linearGradient(let gradient):
                if canRenderGradient(gradient.gradient) {
                    commands.append(.pushState)
                    let rule = provider.createFillRule(from: fill.rule)
                    commands.append(.setClip(path: path, rule: rule))

                    let pathBounds = provider.getBounds(from: shape)
                    commands.append(contentsOf: renderCommands(forLinear: gradient,
                                                               endpoints: pathBounds.endpoints,
                                                               covering: pathBounds,
                                                               opacity: fill.opacity,
                                                               colorConverter: colorConverter))
                    commands.append(.popState)
                }
            case .radialGradient(let gradient):
                if canRenderGradient(gradient.gradient) {
                    commands.append(.pushState)
                    let rule = provider.createFillRule(from: fill.rule)
                    commands.append(.setClip(path: path, rule: rule))
                    let pathBounds = provider.getBounds(from: shape)
                    commands.append(contentsOf: renderCommands(forRadial: gradient,
                                                               in: pathBounds,
                                                               covering: pathBounds,
                                                               opacity: fill.opacity,
                                                               colorConverter: colorConverter))
                    commands.append(.popState)
                }
            }

            switch stroke.color {
            case .color(let color) where color != .none && stroke.width > 0:
                let converted = colorConverter.createColor(from: color)
                let color = provider.createColor(from: converted)
                let width = provider.createFloat(from: stroke.width)
                let cap = provider.createLineCap(from: stroke.cap)
                let join = provider.createLineJoin(from: stroke.join)
                let limit = provider.createFloat(from: stroke.miterLimit)

                let dash = renderCommands(forDash: stroke)

                if !dash.isEmpty {
                    commands.append(.pushState)
                }
                commands.append(.setLineCap(cap))
                commands.append(.setLineJoin(join))
                commands.append(.setLine(width: width))
                commands.append(.setLineMiter(limit: limit))
                commands.append(contentsOf: dash)
                commands.append(.setStroke(color: color))
                commands.append(.stroke(path))
                if !dash.isEmpty {
                    commands.append(contentsOf: renderCommands(forDashResetOf: stroke))
                    commands.append(.popState)
                }
            case .linearGradient(let gradient):
                if let endpoints = shape.gradientEndpoints, canRenderGradient(gradient.gradient) {
                    let width = provider.createFloat(from: stroke.width)
                    let cap = provider.createLineCap(from: stroke.cap)
                    let join = provider.createLineJoin(from: stroke.join)
                    let limit = provider.createFloat(from: stroke.miterLimit)

                    commands.append(.pushState)
                    commands.append(.setLineCap(cap))
                    commands.append(.setLineJoin(join))
                    commands.append(.setLine(width: width))
                    commands.append(.setLineMiter(limit: limit))
                    commands.append(contentsOf: renderCommands(forDash: stroke))
                    commands.append(.clipStrokeOutline(path))

                    commands.append(contentsOf: renderCommands(forLinear: gradient,
                                                               endpoints: endpoints,
                                                               covering: shape.bounds?.outset(by: stroke.coverage),
                                                               opacity: fill.opacity,
                                                               colorConverter: colorConverter))
                    commands.append(contentsOf: renderCommands(forDashResetOf: stroke))
                    commands.append(.popState)
                }
            case .radialGradient(let gradient):
                if let pathBounds = shape.bounds, canRenderGradient(gradient.gradient) {
                    let width = provider.createFloat(from: stroke.width)
                    let cap = provider.createLineCap(from: stroke.cap)
                    let join = provider.createLineJoin(from: stroke.join)
                    let limit = provider.createFloat(from: stroke.miterLimit)

                    commands.append(.pushState)
                    commands.append(.setLineCap(cap))
                    commands.append(.setLineJoin(join))
                    commands.append(.setLine(width: width))
                    commands.append(.setLineMiter(limit: limit))
                    commands.append(contentsOf: renderCommands(forDash: stroke))
                    commands.append(.clipStrokeOutline(path))

                    commands.append(contentsOf: renderCommands(forRadial: gradient,
                                                               in: pathBounds,
                                                               covering: pathBounds.outset(by: stroke.coverage),
                                                               opacity: fill.opacity,
                                                               colorConverter: colorConverter))
                    commands.append(contentsOf: renderCommands(forDashResetOf: stroke))
                    commands.append(.popState)
                }
            default:
                ()
            }

            return commands
        }

        func renderCommands(forDash stroke: StrokeAttributes) -> [RendererCommand<P.Types>] {
            guard !stroke.dashArray.isEmpty else { return [] }
            return [.setLineDash(phase: provider.createFloat(from: stroke.dashOffset),
                                 lengths: stroke.dashArray.map(provider.createFloat))]
        }

        /// The optimizer may strip a lone push/pop pair (CGText), so a dash must be reset explicitly.
        func renderCommands(forDashResetOf stroke: StrokeAttributes) -> [RendererCommand<P.Types>] {
            guard !stroke.dashArray.isEmpty else { return [] }
            return [.setLineDash(phase: provider.createFloat(from: 0), lengths: [])]
        }

        func renderCommands(for image: Image) -> [RendererCommand<P.Types>] {
            guard let renderImage = makeCachedImage(from: image) else { return  [] }
            let size = provider.createSize(from: renderImage)
            guard size.width > 0 && size.height > 0 else { return [] }

            let (dest, clip) = makeImagePlacement(for: image, bitmapSize: size)
            let draw = RendererCommand<P.Types>.draw(image: renderImage, in: provider.createRect(from: dest))
            guard let clip else { return [draw] }
            return [.pushState,
                    .setClip(path: makeCachedPath(from: .rect(within: clip, radii: .zero)), rule: provider.createFillRule(from: .nonzero)),
                    draw,
                    .popState]
        }

        /// Where the bitmap is drawn and, for `slice` overflowing its frame, the rect that clips it.
        /// With both width and height the bitmap is fitted to the frame per preserveAspectRatio (SVG 1.1 §7.8).
        func makeImagePlacement(for image: Image, bitmapSize size: LayerTree.Size) -> (dest: LayerTree.Rect, clip: LayerTree.Rect?) {
            let frame = makeImageFrame(for: image, bitmapSize: size)
            guard image.width != nil, image.height != nil, frame.width > 0, frame.height > 0 else {
                return (frame, nil)
            }
            let fit = image.preserveAspectRatio.fit(
                contentWidth: size.width, contentHeight: size.height,
                viewportWidth: frame.width, viewportHeight: frame.height
            )
            let dest = LayerTree.Rect(
                x: frame.x + fit.tx,
                y: frame.y + fit.ty,
                width: size.width * fit.sx,
                height: size.height * fit.sy
            )
            // a meet or equal-aspect fit only differs from the frame by rounding noise
            let epsilon = 1e-4 * max(frame.width, frame.height)
            let overflows = image.preserveAspectRatio.align != .none && (dest.width > frame.width + epsilon || dest.height > frame.height + epsilon)
            return (dest, overflows ? frame : nil)
        }

        private func makeCachedPath(from shape: LayerTree.Shape) -> P.Types.Path {
            if let existing = paths[shape] {
                return existing
            }
            let new = provider.createPath(from: shape)
            paths[shape] = new
            return new
        }

        private func makeCachedImage(from image: Image) -> P.Types.Image? {
            if let existing = images[image] {
                return existing
            }
            guard let new = provider.createImage(from: image) else {
                return nil
            }
            images[image] = new
            return new
        }

        func makeImageFrame(for image: Image, bitmapSize: LayerTree.Size) -> LayerTree.Rect {
            var frame = LayerTree.Rect(
                x: image.origin.x,
                y: image.origin.y,
                width: image.width ?? bitmapSize.width,
                height: image.height ?? bitmapSize.height
            )

            let aspectRatio = bitmapSize.width / bitmapSize.height

            if let height = image.height, image.width == nil {
                frame.size.width = height * aspectRatio
            }
            if let width = image.width, image.height == nil {
                frame.size.height = width / aspectRatio
            }
            return frame
        }

        func renderCommands(for text: String, at point: Point, attributes: TextAttributes, colorConverter: any ColorConverter = .default) -> [RendererCommand<P.Types>] {
            guard let path = provider.createPath(from: text, at: point, with: attributes) else { return [] }

            let converted = colorConverter.createColor(from: attributes.color)
            let color = provider.createColor(from: converted)
            let rule = provider.createFillRule(from: .nonzero)

            return [.setFill(color: color),
                    .fill(path, rule: rule)]
        }

        func renderCommands(forOpacity opacity: Float) -> [RendererCommand<P.Types>] {
            guard opacity < 1.0 else { return [] }

            return [.setAlpha(provider.createFloat(from: opacity)),
                    .pushTransparencyLayer]
        }

        func renderCommands(forTransforms transforms: [Transform]) -> [RendererCommand<P.Types>] {
            return transforms.map{ renderCommand(forTransform: $0) }
        }

        func renderCommand(forTransform transform: Transform) -> RendererCommand<P.Types> {
            switch transform {
            case .matrix(let m):
                let t = provider.createTransform(from: m)
                return .concatenate(transform: t)
            case let .translate(tx, ty):
                let tx = provider.createFloat(from: tx)
                let ty = provider.createFloat(from: ty)
                return .translate(tx: tx, ty: ty)
            case let .scale(sx, sy):
                let sx = provider.createFloat(from: sx)
                let sy = provider.createFloat(from: sy)
                return .scale(sx: sx, sy: sy)
            case .rotate(let r):
                let radians = provider.createFloat(from: r)
                return .rotate(angle: radians)
            }
        }

        func renderCommands(forClip shapes: [ClipShape], using rule: FillRule?) -> [RendererCommand<P.Types>] {
            guard !shapes.isEmpty else { return [] }
            let paths = shapes.map { clip in
                if clip.transform == .identity {
                    return makeCachedPath(from: clip.shape)
                } else {
                    return makeCachedPath(from: .path(clip.shape.path.applying(matrix: clip.transform)))
                }
            }

            let rule = provider.createFillRule(from: rule ?? .nonzero)

            if paths.count == 1 {
                return [.setClip(path: paths[0], rule: rule)]
            } else {
                let clipPath = provider.createPath(from: paths)
                return [.setClip(path: clipPath, rule: rule)]
            }
        }


        func renderCommands(forMask layer: Layer?) -> [RendererCommand<P.Types>] {
            guard let layer = layer else { return [] }

            let copy = provider.createBlendMode(from: .copy)
            let destinationIn = provider.createBlendMode(from: .destinationIn)

            var commands = [RendererCommand<P.Types>]()
            commands.append(.setBlend(mode: destinationIn))
            commands.append(.pushTransparencyLayer)
            commands.append(.setBlend(mode: copy))
            //commands.append(contentsOf: renderCommands(forClip: layer.clip))
            let drawMask = layer.contents.flatMap{
                renderCommands(for: $0, colorConverter: .luminance)
            }
            commands.append(contentsOf: drawMask)
            commands.append(.popTransparencyLayer)
            return commands
        }

        func canRenderMask(_ commands: [RendererCommand<P.Types>]) -> Bool {
            guard options.contains(.disableTransparencyLayers) else {
                return true
            }
            guard commands.isEmpty else {
                logUnsupportedMask()
                return false
            }
            return true
        }

        func canRenderGradient(_ gradient: LayerTree.Gradient) -> Bool {
            guard options.contains(.disableTransparencyLayers) else {
                return true
            }
            guard gradient.isOpaque else {
                logUnsupportedGradient()
                return false
            }
            return true
        }

        func renderCommands(forLinear gradient: LayerTree.LinearGradient,
                            endpoints: (start: LayerTree.Point, end: LayerTree.Point),
                            covering area: LayerTree.Rect?,
                            opacity: LayerTree.Float,
                            colorConverter: any ColorConverter) -> [RendererCommand<P.Types>] {
            var pathStart: LayerTree.Point
            var pathEnd: LayerTree.Point
            switch gradient.units  {
            case .objectBoundingBox:
                let width = endpoints.end.x - endpoints.start.x
                let height = endpoints.end.y - endpoints.start.y
                pathStart = LayerTree.Point(endpoints.start.x + width * gradient.start.x,
                                            endpoints.start.y + height * gradient.start.y)
                pathEnd = LayerTree.Point(endpoints.start.x + width * gradient.end.x,
                                          endpoints.start.y + height * gradient.end.y)
            case .userSpaceOnUse:
                pathStart = gradient.start
                pathEnd = gradient.end
            }

            var commands = [RendererCommand<P.Types>]()
            if !gradient.transform.isEmpty {
                commands.append(contentsOf: renderCommands(forTransforms: gradient.transform))
            }

            var stops = gradient.gradient
            if gradient.spread != .pad, let area,
               let periods = Self.spreadPeriods(start: pathStart, end: pathEnd, transform: gradient.transform, covering: area) {
                if periods.count <= Self.maxSpreadPeriods(stopCount: stops.stops.count) {
                    let vector = LayerTree.Point(pathEnd.x - pathStart.x, pathEnd.y - pathStart.y)
                    stops = stops.spread(gradient.spread, periods: periods)
                    pathEnd = pathStart.offset(vector, times: LayerTree.Float(periods.upperBound + 1))
                    pathStart = pathStart.offset(vector, times: LayerTree.Float(periods.lowerBound))
                } else {
                    logUnsupportedSpread()
                    stops = stops.averaged()
                }
            }

            let converted = stops.convertColor(using: colorConverter)
            let gradient = provider.createGradient(from: converted)
            let start = provider.createPoint(from: pathStart)
            let end = provider.createPoint(from: pathEnd)
            let apha = provider.createFloat(from: opacity)
            commands.append(.setAlpha(apha))
            commands.append(.drawLinearGradient(gradient, from: start, to: end))
            return commands
        }

        func renderCommands(forRadial gradient: RadialGradient,
                            in bounds: LayerTree.Rect,
                            covering area: LayerTree.Rect?,
                            opacity: LayerTree.Float,
                            colorConverter: any ColorConverter) -> [RendererCommand<P.Types>] {
            let startCenter: LayerTree.Point
            let startRadius: LayerTree.Float
            var endCenter: LayerTree.Point
            var endRadius: LayerTree.Float

            switch gradient.units  {
            case .objectBoundingBox:
                let h = max(bounds.width, bounds.height)
                startCenter = LayerTree.Point(
                    bounds.x + (gradient.center.x * bounds.width),
                    bounds.y + (gradient.center.y * bounds.height)
                )
                startRadius = h * gradient.radius
                endCenter = LayerTree.Point(
                    bounds.x + (gradient.endCenter.x * bounds.width),
                    bounds.y + (gradient.endCenter.y * bounds.height)
                )
                endRadius = h * gradient.endRadius
            case .userSpaceOnUse:
                startCenter = gradient.center
                startRadius = gradient.radius
                endCenter = gradient.endCenter
                endRadius = gradient.endRadius
            }

            var commands = [RendererCommand<P.Types>]()
            if !gradient.transform.isEmpty {
                commands.append(contentsOf: renderCommands(forTransforms: gradient.transform))
            }

            var stops = gradient.gradient
            if gradient.spread != .pad, let area,
               let periods = Self.spreadPeriods(startCenter: startCenter, startRadius: startRadius,
                                                endCenter: endCenter, endRadius: endRadius,
                                                transform: gradient.transform, covering: area) {
                if periods.count <= Self.maxSpreadPeriods(stopCount: stops.stops.count) {
                    let vector = LayerTree.Point(endCenter.x - startCenter.x, endCenter.y - startCenter.y)
                    let count = LayerTree.Float(periods.upperBound + 1)
                    stops = stops.spread(gradient.spread, periods: periods)
                    endCenter = startCenter.offset(vector, times: count)
                    endRadius = startRadius + (endRadius - startRadius) * count
                } else {
                    logUnsupportedSpread()
                    stops = stops.averaged()
                }
            }

            let converted = stops.convertColor(using: colorConverter)
            let gradient = provider.createGradient(from: converted)
            let apha = provider.createFloat(from: opacity)
            commands.append(.setAlpha(apha))
            commands.append(.drawRadialGradient(
                gradient,
                startCenter: provider.createPoint(from: startCenter),
                startRadius: provider.createFloat(from: startRadius),
                endCenter: provider.createPoint(from: endCenter),
                endRadius: provider.createFloat(from: endRadius)
            ))
            return commands
        }
    }
}

extension LayerTree.CommandGenerator {

    /// Most stops a `reflect` or `repeat` gradient expands to.
    static var maxSpreadStops: Int { 4096 }

    /// Most periods drawn for a gradient of `stopCount` stops (each period may gain two stops when
    /// completed to 0...1); a gradient needing more paints its average colour instead.
    static func maxSpreadPeriods(stopCount: Int) -> Int {
        max(1, maxSpreadStops / (stopCount + 2))
    }

    /// The periods of a linear gradient (0 being start...end) needed to cover `area`, which is in
    /// the space the gradient's transform is applied to. nil when they cannot be computed.
    static func spreadPeriods(start: LayerTree.Point, end: LayerTree.Point,
                              transform: [LayerTree.Transform],
                              covering area: LayerTree.Rect) -> ClosedRange<Int>? {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = dx * dx + dy * dy
        guard length > 0, let inverse = transform.toMatrix().inverted() else { return nil }
        let offsets = area.corners.map {
            let p = inverse.transform(point: $0)
            return ((p.x - start.x) * dx + (p.y - start.y) * dy) / length
        }
        guard let lower = offsets.min(), let upper = offsets.max() else { return nil }
        return makePeriods(lower: lower, upper: upper)
    }

    /// The periods of a radial gradient needed to cover `area`. Only computed when the focal circle
    /// lies inside the end circle; otherwise (and inside the focal circle) the gradient pads.
    static func spreadPeriods(startCenter: LayerTree.Point, startRadius: LayerTree.Float,
                              endCenter: LayerTree.Point, endRadius: LayerTree.Float,
                              transform: [LayerTree.Transform],
                              covering area: LayerTree.Rect) -> ClosedRange<Int>? {
        // the circle at t has centre c0 + t·Δc and radius r0 + t·Δr; a point p = c0 + q is on it when
        // (Δc·Δc − Δr²)t² − 2(q·Δc + r0Δr)t + (q·q − r0²) = 0. With the focal circle inside
        // (Δr > |Δc|) the circles nest, so p is covered from the larger root on.
        let dx = endCenter.x - startCenter.x
        let dy = endCenter.y - startCenter.y
        let dr = endRadius - startRadius
        let a = dx * dx + dy * dy - dr * dr
        guard a < 0, dr > 0, let inverse = transform.toMatrix().inverted() else { return nil }
        let offsets = area.corners.map { corner -> LayerTree.Float in
            let p = inverse.transform(point: corner)
            let qx = p.x - startCenter.x
            let qy = p.y - startCenter.y
            let b = -2 * (qx * dx + qy * dy + startRadius * dr)
            let c = qx * qx + qy * qy - startRadius * startRadius
            let discriminant = max(0, b * b - 4 * a * c)
            return (-b - discriminant.squareRoot()) / (2 * a)
        }
        guard let upper = offsets.max() else { return nil }
        return makePeriods(lower: 0, upper: upper)
    }

    /// The whole periods spanning lower...upper, always including period 0.
    static func makePeriods(lower: LayerTree.Float, upper: LayerTree.Float) -> ClosedRange<Int>? {
        guard lower.isFinite, upper.isFinite else { return nil }
        // bounded so the conversion to Int cannot trap; anything this large is averaged anyway
        let limit: LayerTree.Float = 1_000_000
        let first = Int(max(-limit, min(0, lower.rounded(.down))))
        let last = Int(min(limit, max(1, upper.rounded(.up)))) - 1
        return first...last
    }

    // Resolves the layer's filter into its user space; nil when a primitive is unsupported
    // or the filter region cannot be resolved (e.g. text-only contents under objectBoundingBox),
    // in which case the contents are drawn unfiltered.
    func makeFilterLayer(for layer: LayerTree.Layer) -> LayerTree.FilterLayer? {
        guard !layer.filters.isEmpty,
              !layer.hasUnsupportedFilters else { return nil }

        let region = layer.filterRegion
        let bounds = makeBounds(for: layer)

        // Filter Effects 1 §5.1, SVG 1.1 §15.7.2: filter region
        let rect: LayerTree.Rect
        switch region.units {
        case .objectBoundingBox:
            guard let bounds else { return nil }
            rect = LayerTree.Rect(
                x: bounds.x + (region.x ?? -0.1) * bounds.width,
                y: bounds.y + (region.y ?? -0.1) * bounds.height,
                width: (region.width ?? 1.2) * bounds.width,
                height: (region.height ?? 1.2) * bounds.height
            )
        case .userSpaceOnUse:
            rect = LayerTree.Rect(
                x: region.x ?? -0.1 * size.width,
                y: region.y ?? -0.1 * size.height,
                width: region.width ?? 1.2 * size.width,
                height: region.height ?? 1.2 * size.height
            )
        }

        var scale = LayerTree.Size(1, 1)
        if region.primitiveUnits == .objectBoundingBox {
            guard let bounds else { return nil }
            scale = bounds.size
        }

        guard rect.x.isFinite, rect.y.isFinite, rect.width.isFinite, rect.height.isFinite else { return nil }

        let effects = layer.filters.map { $0.resolved(scale: scale) }
        let width = max(rect.width, 0)
        let height = max(rect.height, 0)
        return LayerTree.FilterLayer(
            region: LayerTree.Rect(x: rect.x, y: rect.y, width: width, height: height),
            effects: effects
        )
    }

    // Geometry bounding box of the layer contents in the layer's user space; stroke excluded.
    // nil when the contents include text, which is not measured: the filter is then dropped
    // rather than clipping the text away.
    func makeBounds(for layer: LayerTree.Layer) -> LayerTree.Rect? {
        guard !layer.containsText else { return nil }
        var points = [LayerTree.Point]()
        for contents in layer.contents {
            switch contents {
            case .shape(let shape, _, _):
                if let rect = shape.bounds {
                    points.append(contentsOf: rect.corners)
                }
            case .image(let image):
                if let width = image.width, let height = image.height {
                    points.append(contentsOf: LayerTree.Rect(x: image.origin.x, y: image.origin.y, width: width, height: height).corners)
                }
            case .text:
                break
            case .layer(let child):
                if let rect = makeBounds(for: child) {
                    let matrix = child.transform.toMatrix()
                    points.append(contentsOf: rect.corners.map { matrix.transform(point: $0) })
                }
            }
        }
        guard !points.isEmpty else { return nil }
        return .makeBounds(between: points)
    }

    func logUnsupportedFilters(_ filters: [LayerTree.Filter]) {
        guard !hasLoggedFilterWarning else { return }
        let name = filters.map(\.name).joined(separator: ", ")

        let hint: String
        if options.contains(.commandLine) {
            hint = "[--hideUnsupportedFilters]"
        } else {
        #if canImport(UIKit)
            hint = "UIImage(svgNamed:, options: .hideUnsupportedFilters)"
        #else
            hint = "NSImage(svgNamed:, options: .hideUnsupportedFilters)"
        #endif
        }

        print("Warning:", name, "is not supported. Elements with this filter can be hidden with \(hint)", to: &.standardError)
        hasLoggedFilterWarning = true
    }

    func logUnsupportedGradient() {
        guard !hasLoggedGradientWarning else { return }
        print("Warning:", "PDF does not support gradients with stop-opacity", to: &.standardError)
        hasLoggedGradientWarning = true
    }

    func logUnsupportedSpread() {
        guard !hasLoggedSpreadWarning else { return }
        print("Warning:", "spreadMethod needs more than \(Self.maxSpreadStops) gradient stops; painting the average colour", to: &.standardError)
        hasLoggedSpreadWarning = true
    }

    func logUnsupportedMask() {
        guard !hasLoggedMaskWarning else { return }
        print("Warning:", "PDF does not support transparency masks", to: &.standardError)
        hasLoggedMaskWarning = true
    }
}

private extension LayerTree.Rect {

    func outset(by amount: LayerTree.Float) -> LayerTree.Rect {
        LayerTree.Rect(x: x - amount, y: y - amount, width: width + amount * 2, height: height + amount * 2)
    }

    func getPoint(offset: LayerTree.Point) -> LayerTree.Point {
        return LayerTree.Point(origin.x + size.width * offset.x,
                               origin.y + size.height * offset.y)
    }

    var endpoints: (start: LayerTree.Point, end: LayerTree.Point) {
        let max = LayerTree.Point(origin.x + size.width, origin.y + size.height)
        return (start: origin, end: max)
    }
}


extension LayerTree.Gradient {

    /// The stops of the given periods of this gradient laid end to end over 0...1, every odd period
    /// mirrored for `reflect` (SVG 1.1 §13.2.2 spreadMethod).
    func spread(_ spread: Spread, periods: ClosedRange<Int>) -> LayerTree.Gradient {
        guard spread != .pad, !stops.isEmpty else { return self }
        let period = completedPeriod
        let mirrored = period.reversed().map { Stop(offset: 1 - $0.offset, color: $0.color, opacity: $0.opacity) }
        let count = LayerTree.Float(periods.count)
        var result = [Stop]()
        for (index, k) in periods.enumerated() {
            let source = spread == .reflect && k % 2 != 0 ? mirrored : period
            for stop in source {
                result.append(Stop(offset: (LayerTree.Float(index) + stop.offset) / count,
                                   color: stop.color, opacity: stop.opacity))
            }
        }
        return LayerTree.Gradient(stops: result)
    }

    /// The stops completed so the first and last colours fill 0 and 1.
    var completedPeriod: [Stop] {
        var period = stops
        if let first = period.first, first.offset > 0 {
            period.insert(Stop(offset: 0, color: first.color, opacity: first.opacity), at: 0)
        }
        if let last = period.last, last.offset < 1 {
            period.append(Stop(offset: 1, color: last.color, opacity: last.opacity))
        }
        return period
    }

    /// A flat gradient of the average colour of one period (premultiplied, the same for `reflect`),
    /// for spreads too fine to draw.
    func averaged() -> LayerTree.Gradient {
        let period = completedPeriod
        var sum: (r: LayerTree.Float, g: LayerTree.Float, b: LayerTree.Float, a: LayerTree.Float) = (0, 0, 0, 0)
        var space = LayerTree.ColorSpace.srgb
        for (lhs, rhs) in zip(period, period.dropFirst()) {
            let weight = (rhs.offset - lhs.offset) / 2
            for stop in [lhs, rhs] {
                let c = stop.premultiplied
                sum = (sum.r + c.r * weight, sum.g + c.g * weight, sum.b + c.b * weight, sum.a + c.a * weight)
            }
            if case .rgba(_, _, _, _, let s) = lhs.color { space = s }
        }
        let color: LayerTree.Color = sum.a > 0
            ? .rgba(r: sum.r / sum.a, g: sum.g / sum.a, b: sum.b / sum.a, a: sum.a, space: space)
            : .none
        return LayerTree.Gradient(stops: [Stop(offset: 0, color: color, opacity: 1),
                                          Stop(offset: 1, color: color, opacity: 1)])
    }
}

private extension LayerTree.Gradient.Stop {
    var premultiplied: (r: LayerTree.Float, g: LayerTree.Float, b: LayerTree.Float, a: LayerTree.Float) {
        switch color {
        case .none:
            return (0, 0, 0, 0)
        case let .rgba(r, g, b, a, _):
            let alpha = a * opacity
            return (r * alpha, g * alpha, b * alpha, alpha)
        case let .gray(white, a):
            let alpha = a * opacity
            return (white * alpha, white * alpha, white * alpha, alpha)
        }
    }
}

private extension LayerTree.Gradient {
    func convertColor(using converter: any ColorConverter) -> LayerTree.Gradient {
        let stops: [LayerTree.Gradient.Stop] = stops.map { stop in
            var stop = stop
            stop.color = converter.createColor(from: stop.color).withMultiplyingAlpha(stop.opacity)
            return stop
        }
        return LayerTree.Gradient(stops: stops)
    }
}

private extension LayerTree.StrokeAttributes {
    /// How far the stroke may reach beyond the path's bounds: half the width, √2 times that at
    /// square caps, up to the miter limit at miter joins.
    var coverage: LayerTree.Float {
        let cap: LayerTree.Float = self.cap == .square ? LayerTree.Float(2).squareRoot() : 1
        let join: LayerTree.Float = self.join == .miter ? max(1, miterLimit) : 1
        return width / 2 * max(cap, join)
    }
}

private extension LayerTree.Point {
    func offset(_ vector: LayerTree.Point, times factor: LayerTree.Float) -> LayerTree.Point {
        LayerTree.Point(x + vector.x * factor, y + vector.y * factor)
    }
}

private extension LayerTree.Transform.Matrix {
    func inverted() -> Self? {
        let determinant = a * d - b * c
        guard determinant != 0, determinant.isFinite else { return nil }
        return Self(a: d / determinant, b: -b / determinant,
                    c: -c / determinant, d: a / determinant,
                    tx: (c * ty - d * tx) / determinant,
                    ty: (b * tx - a * ty) / determinant)
    }
}

private extension LayerTree.Shape {

    var gradientEndpoints: (start: LayerTree.Point, end: LayerTree.Point)? {
        bounds?.gradientEndpoints
    }

    var bounds: LayerTree.Rect? {
        switch self {
        case .path(let p):
            return p.bounds
        case .rect(within: let rect, _),
             .ellipse(within: let rect):
            return rect
        case .polygon(between: let points),
             .line(between: let points):
            return .makeBounds(between: points)
        }
    }
}

private extension LayerTree.Filter {
    var name: String {
        switch self {
        case .gaussianBlur(_, _):
            return "<feGaussianBlur>"
        case .unsupported(let name):
            return "<\(name)>"
        }
    }

    // stdDeviation in user units with both values explicit.
    // Filter Effects 1 §9.16: a negative value disables the primitive, zero disables one direction.
    func resolved(scale: LayerTree.Size) -> Self {
        switch self {
        case let .gaussianBlur(stdDeviation: x, stdDeviationY: y):
            let y = y ?? x
            guard x >= 0, y >= 0 else {
                return .gaussianBlur(stdDeviation: 0, stdDeviationY: 0)
            }
            // renderers clamp to their pixel limits; keep the values finite
            let maximum = LayerTree.Float.greatestFiniteMagnitude
            return .gaussianBlur(stdDeviation: min(x * scale.width, maximum),
                                 stdDeviationY: min(y * scale.height, maximum))
        case .unsupported:
            return self
        }
    }
}

private extension LayerTree.Rect {

    var isEmpty: Bool {
        width <= 0 || height <= 0
    }

    var corners: [LayerTree.Point] {
        [origin,
         LayerTree.Point(maxX, minY),
         LayerTree.Point(maxX, maxY),
         LayerTree.Point(minX, maxY)]
    }

    var gradientEndpoints: (start: LayerTree.Point, end: LayerTree.Point) {
        let start = LayerTree.Point(midX, minY)
        let end = LayerTree.Point(midX, maxY)
        return (start, end)
    }

    static func makeBounds(between points: [LayerTree.Point]) -> Self? {
        var min = LayerTree.Point.maximum
        var max = LayerTree.Point.minimum
        for point in points {
            min = min.minimum(combining: point)
            max = max.maximum(combining: point)
        }
        return LayerTree.Rect(
            x: min.x,
            y: min.y,
            width: max.x - min.x,
            height: max.y - min.y
        )
    }
}

extension LayerTree.CommandGenerator {

    /// Resolves a pattern against the bounding box of the element it fills (SVG 1.1 §13.3).
    ///
    /// Returns a pattern whose `frame` is the tile in pattern space (user units) and whose `transform`
    /// is the patternTransform, plus the transform that maps the pattern contents into that tile
    /// (tile origin, then viewBox or objectBoundingBox content units). Returns nil when the
    /// pattern disables rendering: a zero or negative tile, an empty bounding box with
    /// objectBoundingBox units, an empty viewBox, or a non-finite or non-invertible patternTransform.
    /// `bounds` is only evaluated when objectBoundingBox units need it.
    static func resolvePattern(_ pattern: LayerTree.Pattern, in boundingBox: @autoclosure () -> LayerTree.Rect) -> (LayerTree.Pattern, LayerTree.Transform.Matrix)? {
        let t = pattern.transform
        let determinant = t.a * t.d - t.b * t.c
        guard [t.a, t.b, t.c, t.d, t.tx, t.ty].allSatisfy(\.isFinite),
              determinant.isFinite, determinant != 0 else { return nil }

        let needsBounds = pattern.units == .objectBoundingBox ||
            (pattern.viewBox == nil && pattern.contentUnits == .objectBoundingBox)
        let bounds = needsBounds ? boundingBox() : .zero

        var tile = pattern.frame
        if pattern.units == .objectBoundingBox {
            tile = LayerTree.Rect(
                x: bounds.x + pattern.frame.x * bounds.width,
                y: bounds.y + pattern.frame.y * bounds.height,
                width: pattern.frame.width * bounds.width,
                height: pattern.frame.height * bounds.height
            )
        }
        guard [tile.x, tile.y, tile.width, tile.height].allSatisfy(\.isFinite),
              tile.width > 0, tile.height > 0 else { return nil }

        var contentTransform = LayerTree.Transform.Matrix.identity
        if let viewBox = pattern.viewBox {
            // the viewBox is fitted into the tile per the pattern's preserveAspectRatio (SVG 1.1 §7.8)
            guard viewBox.width > 0, viewBox.height > 0 else { return nil }
            let fit = pattern.preserveAspectRatio.fit(
                contentWidth: viewBox.width, contentHeight: viewBox.height,
                viewportWidth: tile.width, viewportHeight: tile.height
            )
            contentTransform = LayerTree.Transform.Matrix(
                a: fit.sx, b: 0, c: 0, d: fit.sy,
                tx: fit.tx - viewBox.x * fit.sx,
                ty: fit.ty - viewBox.y * fit.sy
            )
        } else if pattern.contentUnits == .objectBoundingBox {
            guard bounds.width > 0, bounds.height > 0 else { return nil }
            contentTransform = LayerTree.Transform.Matrix(a: bounds.width, b: 0, c: 0, d: bounds.height, tx: 0, ty: 0)
        }
        contentTransform = contentTransform.concatenated(
            LayerTree.Transform.translate(tx: tile.x, ty: tile.y).toMatrix()
        )

        let resolved = LayerTree.Pattern(frame: tile)
        resolved.transform = pattern.transform
        resolved.contents = pattern.contents
        return (resolved, contentTransform)
    }
}
