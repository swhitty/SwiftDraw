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
        private var hasLoggedSpreadWarning = false
        private var hasLoggedMaskWarning = false

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
                        commands.append(contentsOf: renderCommands(forMask: layer.mask))
                        commands.append(.pushTransparencyLayer)
                    }

                    // filter is applied before clipping, masking and opacity
                    if let filterLayer = state.filterLayer {
                        commands.append(.pushFilterLayer(filterLayer))
                        // what each feImage draws, for the renderer to rasterize into the filter's pixels
                        for (index, primitive) in filterLayer.primitives.enumerated() {
                            if case .image(let image) = primitive.effect {
                                commands.append(
                                    .filterImage(
                                        primitive: index,
                                        contents: renderCommands(for: image.layer, colorConverter: colorConverter)
                                    )
                                )
                            }
                        }
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

                case let .endLayer(_, state):
                    if state.filterLayer != nil {
                        commands.append(.popFilterLayer)
                    }

                    // composite the contents through the mask clip
                    if state.hasMask {
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
            // disableFilters draws the layer as if it had no filter
            let hasFilters = !layer.filters.isEmpty && !options.contains(.disableFilters)

            if hasMask && options.contains(.disableTransparencyLayers) {
                hasContents = false
            }

            // a supported filter (feGaussianBlur) is rendered, so only unsupported ones hide the layer
            if hasFilters && layer.hasUnsupportedFilters && options.contains(.hideUnsupportedFilters) {
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
                filterLayer: hasFilters ? makeFilterLayer(for: layer, colorConverter: colorConverter) : nil
            )
        }

        func renderCommands(
            for contents: Layer.Contents,
            colorConverter: any ColorConverter
        ) -> [RendererCommand<P.Types>] {
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

        func makeRenderContents(for contents: Layer.Contents, colorConverter: any ColorConverter) -> RenderContents {
            switch contents {
            case .shape(let shape, let stroke, let fill):
                return .simple(renderCommands(for: shape, stroke: stroke, fill: fill, colorConverter: colorConverter))
            case .image(let image):
                return .simple(renderCommands(for: image))
            case .text(let text, let point, let att):
                return .simple(renderCommands(for: text, at: point, attributes: att, colorConverter: colorConverter))
            case .glyphs(let run):
                return .simple(renderCommands(for: run, colorConverter: colorConverter))
            case .layer(let layer):
                return .layer(layer)
            }
        }

        func renderCommands(
            for shape: Shape,
            stroke: StrokeAttributes,
            fill: FillAttributes,
            colorConverter: any ColorConverter
        ) -> [RendererCommand<P.Types>] {
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
                if let pattern = makePattern(
                    fillPattern,
                    in: fill.boundingBox ?? provider.getBounds(from: shape),
                    colorConverter: colorConverter
                ) {
                    let rule = provider.createFillRule(from: fill.rule)
                    commands.append(
                        contentsOf: renderCommands(
                            withOpacity: fill.opacity,
                            [
                                .setFillPattern(pattern),
                                .fill(path, rule: rule),
                            ]
                        )
                    )
                }
            case .linearGradient(let gradient):
                if canRenderGradient(gradient.gradient) {
                    commands.append(.pushState)
                    let rule = provider.createFillRule(from: fill.rule)
                    commands.append(.setClip(path: path, rule: rule))

                    let pathBounds = provider.getBounds(from: shape)
                    commands.append(
                        contentsOf: renderCommands(
                            forLinear: gradient,
                            in: fill.boundingBox ?? pathBounds,
                            covering: pathBounds,
                            opacity: fill.opacity,
                            colorConverter: colorConverter
                        )
                    )
                    commands.append(.popState)
                }
            case .radialGradient(let gradient):
                if canRenderGradient(gradient.gradient) {
                    commands.append(.pushState)
                    let rule = provider.createFillRule(from: fill.rule)
                    commands.append(.setClip(path: path, rule: rule))
                    let pathBounds = provider.getBounds(from: shape)
                    commands.append(
                        contentsOf: renderCommands(
                            forRadial: gradient,
                            in: fill.boundingBox ?? pathBounds,
                            opacity: fill.opacity,
                            colorConverter: colorConverter
                        )
                    )
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

                    commands.append(
                        contentsOf: renderCommands(
                            forLinear: gradient,
                            in: stroke.boundingBox ?? pathBounds,
                            covering: pathBounds.outset(by: stroke.coverage),
                            opacity: stroke.opacity,
                            colorConverter: colorConverter
                        )
                    )
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

                    commands.append(
                        contentsOf: renderCommands(
                            forRadial: gradient,
                            in: stroke.boundingBox ?? pathBounds,
                            opacity: stroke.opacity,
                            colorConverter: colorConverter
                        )
                    )
                    commands.append(contentsOf: renderCommands(forDashResetOf: stroke))
                    commands.append(.popState)
                }
            case .pattern(let strokePattern):
                // objectBoundingBox resolves against the geometry, not the stroke (SVG 1.1 §13.3)
                if stroke.width > 0, let pathBounds = shape.bounds,
                    let pattern = makePattern(
                        strokePattern,
                        in: stroke.boundingBox ?? pathBounds,
                        colorConverter: colorConverter
                    )
                {
                    let width = provider.createFloat(from: stroke.width)
                    let cap = provider.createLineCap(from: stroke.cap)
                    let join = provider.createLineJoin(from: stroke.join)
                    let limit = provider.createFloat(from: stroke.miterLimit)
                    let area = provider.createPath(
                        from: .rect(within: pathBounds.outset(by: stroke.coverage), radii: .zero)
                    )

                    commands.append(.pushState)
                    commands.append(.setLineCap(cap))
                    commands.append(.setLineJoin(join))
                    commands.append(.setLine(width: width))
                    commands.append(.setLineMiter(limit: limit))
                    commands.append(contentsOf: renderCommands(forDash: stroke))
                    commands.append(.clipStrokeOutline(path))
                    if stroke.opacity < 1 {
                        commands.append(.setAlpha(provider.createFloat(from: stroke.opacity)))
                    }
                    commands.append(.setFillPattern(pattern))
                    commands.append(.fill(area, rule: provider.createFillRule(from: .nonzero)))
                    commands.append(contentsOf: renderCommands(forDashResetOf: stroke))
                    commands.append(.popState)
                }
            default:
                ()
            }

            return commands
        }

        /// The pattern resolved against `bounds`, with its contents rendered; nil when it disables rendering.
        func makePattern(
            _ pattern: LayerTree.Pattern,
            in bounds: @autoclosure () -> LayerTree.Rect,
            colorConverter: any ColorConverter
        ) -> P.Types.Pattern? {
            guard let (resolvedPattern, contentTransform) = Self.resolvePattern(pattern, in: bounds()) else {
                return nil
            }
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
            return provider.createPattern(from: resolvedPattern, contents: patternCommands)
        }

        /// Wraps `commands` in a state with the given alpha, when it is less than 1.
        func renderCommands(
            withOpacity opacity: LayerTree.Float,
            _ commands: [RendererCommand<P.Types>]
        ) -> [RendererCommand<P.Types>] {
            guard opacity < 1 else { return commands }
            return [.pushState, .setAlpha(provider.createFloat(from: opacity))] + commands + [.popState]
        }

        func renderCommands(forDash stroke: StrokeAttributes) -> [RendererCommand<P.Types>] {
            guard !stroke.dashArray.isEmpty else { return [] }
            return [
                .setLineDash(
                    phase: provider.createFloat(from: stroke.dashOffset),
                    lengths: stroke.dashArray.map(provider.createFloat)
                )
            ]
        }

        /// The optimizer may strip a lone push/pop pair (CGText), so a dash must be reset explicitly.
        func renderCommands(forDashResetOf stroke: StrokeAttributes) -> [RendererCommand<P.Types>] {
            guard !stroke.dashArray.isEmpty else { return [] }
            return [.setLineDash(phase: provider.createFloat(from: 0), lengths: [])]
        }

        func renderCommands(for image: Image) -> [RendererCommand<P.Types>] {
            guard let renderImage = makeCachedImage(from: image) else { return [] }
            let size = provider.createSize(from: renderImage)
            guard size.width > 0 && size.height > 0 else { return [] }

            let (dest, clip) = makeImagePlacement(for: image, bitmapSize: size)
            let draw = RendererCommand<P.Types>.draw(image: renderImage, in: provider.createRect(from: dest))
            guard let clip else { return [draw] }
            return [
                .pushState,
                .setClip(
                    path: makeCachedPath(from: .rect(within: clip, radii: .zero)),
                    rule: provider.createFillRule(from: .nonzero)
                ),
                draw,
                .popState,
            ]
        }

        /// Where the bitmap is drawn and, for `slice` overflowing its frame, the rect that clips it.
        /// With both width and height the bitmap is fitted to the frame per preserveAspectRatio (SVG 1.1 §7.8).
        func makeImagePlacement(
            for image: Image,
            bitmapSize size: LayerTree.Size
        ) -> (dest: LayerTree.Rect, clip: LayerTree.Rect?) {
            let frame = makeImageFrame(for: image, bitmapSize: size)
            guard image.width != nil, image.height != nil, frame.width > 0, frame.height > 0 else {
                return (frame, nil)
            }
            let fit = image.preserveAspectRatio.fit(
                contentWidth: size.width,
                contentHeight: size.height,
                viewportWidth: frame.width,
                viewportHeight: frame.height
            )
            let dest = LayerTree.Rect(
                x: frame.x + fit.tx,
                y: frame.y + fit.ty,
                width: size.width * fit.sx,
                height: size.height * fit.sy
            )
            // a meet or equal-aspect fit only differs from the frame by rounding noise
            let epsilon = 1e-4 * max(frame.width, frame.height)
            let overflows =
                image.preserveAspectRatio.align != .none
                && (dest.width > frame.width + epsilon || dest.height > frame.height + epsilon)
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

        func renderCommands(
            for text: String,
            at point: Point,
            attributes: TextAttributes,
            colorConverter: any ColorConverter = .default
        ) -> [RendererCommand<P.Types>] {
            guard let path = provider.createPath(from: text, at: point, with: attributes) else { return [] }

            let converted = colorConverter.createColor(from: attributes.color)
            let color = provider.createColor(from: converted)
            let rule = provider.createFillRule(from: .nonzero)

            return [
                .setFill(color: color),
                .fill(path, rule: rule),
            ]
        }

        func renderCommands(
            for run: GlyphRun,
            colorConverter: any ColorConverter = .default
        ) -> [RendererCommand<P.Types>] {
            guard let path = provider.createPath(from: run) else { return [] }
            let color = provider.createColor(from: colorConverter.createColor(from: run.attributes.color))
            return [
                .setFill(color: color),
                .fill(path, rule: provider.createFillRule(from: .nonzero)),
            ]
        }

        func renderCommands(forOpacity opacity: Float) -> [RendererCommand<P.Types>] {
            guard opacity < 1.0 else { return [] }

            return [
                .setAlpha(provider.createFloat(from: opacity)),
                .pushTransparencyLayer,
            ]
        }

        func renderCommands(forTransforms transforms: [Transform]) -> [RendererCommand<P.Types>] {
            return transforms.map { renderCommand(forTransform: $0) }
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

        // The mask contents are drawn with normal compositing in greyscale (colours converted to their luminance,
        // or to white for `mask-type: alpha`), so overlapping, translucent and opacity-grouped mask contents
        // combine as they would in colour.
        // The renderer turns the result into a clip; the masked contents are drawn into a transparency layer
        // within it, so they are masked as a group.
        func renderCommands(forMask layer: Layer?) -> [RendererCommand<P.Types>] {
            guard let layer = layer else { return [] }
            //commands.append(contentsOf: renderCommands(forClip: layer.clip))
            let converter: any ColorConverter =
                switch layer.maskType {
                case .luminance: .luminance
                case .linearLuminance: .linearLuminance
                case .alpha: .alpha
                }
            let drawMask = layer.contents.flatMap {
                renderCommands(for: $0, colorConverter: converter)
            }
            return [.clipToMask(drawMask)]
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

        // objectBoundingBox gradients are drawn in the unit space of the bounding box (SVG 1.1 §13.2.2),
        // with gradientTransform applied within it, so they stretch with a wide or tall box.
        // A box with no width or height ignores the gradient and paints nothing.
        func renderCommands(
            forGradientUnits units: LayerTree.Gradient.Units,
            transform: [LayerTree.Transform],
            in bounds: LayerTree.Rect
        ) -> [RendererCommand<P.Types>]? {
            guard let transforms = Self.makeGradientTransforms(units: units, transform: transform, in: bounds) else {
                return nil
            }
            return renderCommands(forTransforms: transforms)
        }

        // CoreGraphics only pads, so reflect and repeat (SVG 1.1 §13.2.2 spreadMethod) are drawn by
        // laying the periods that cover `area` end to end as one padded gradient. (after SD6, PR #142)
        func renderCommands(
            forLinear gradient: LayerTree.LinearGradient,
            in bounds: LayerTree.Rect,
            covering area: LayerTree.Rect?,
            opacity: LayerTree.Float,
            colorConverter: any ColorConverter
        ) -> [RendererCommand<P.Types>] {
            guard
                let transforms = Self.makeGradientTransforms(
                    units: gradient.units,
                    transform: gradient.transform,
                    in: bounds
                )
            else { return [] }
            var commands = renderCommands(forTransforms: transforms)
            var pathStart = gradient.start
            var pathEnd = gradient.end

            var stops = gradient.gradient
            if gradient.spread != .pad, let area,
                let periods = Self.spreadPeriods(start: pathStart, end: pathEnd, transform: transforms, covering: area)
            {
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

            let converted = stops.resolved(using: colorConverter)
            let gradient = provider.createGradient(from: converted)
            let start = provider.createPoint(from: pathStart)
            let end = provider.createPoint(from: pathEnd)
            let apha = provider.createFloat(from: opacity)
            commands.append(.setAlpha(apha))
            commands.append(.drawLinearGradient(gradient, from: start, to: end))
            return commands
        }

        func renderCommands(
            forRadial gradient: RadialGradient,
            in bounds: LayerTree.Rect,
            opacity: LayerTree.Float,
            colorConverter: any ColorConverter
        ) -> [RendererCommand<P.Types>] {
            guard
                var commands = renderCommands(
                    forGradientUnits: gradient.units,
                    transform: gradient.transform,
                    in: bounds
                )
            else { return [] }
            let startCenter = gradient.center
            let startRadius = gradient.radius
            let endCenter = gradient.endCenter
            let endRadius = gradient.endRadius

            let converted = gradient.gradient.resolved(using: colorConverter)
            let gradient = provider.createGradient(from: converted)
            let apha = provider.createFloat(from: opacity)
            commands.append(.setAlpha(apha))
            commands.append(
                .drawRadialGradient(
                    gradient,
                    startCenter: provider.createPoint(from: startCenter),
                    startRadius: provider.createFloat(from: startRadius),
                    endCenter: provider.createPoint(from: endCenter),
                    endRadius: provider.createFloat(from: endRadius)
                )
            )
            return commands
        }
    }
}

extension LayerTree.CommandGenerator {

    /// The transforms from gradient space to user space: the bounding box for objectBoundingBox
    /// (SVG 1.1 §13.2.2), then gradientTransform. nil when the box has no width or height.
    static func makeGradientTransforms(
        units: LayerTree.Gradient.Units,
        transform: [LayerTree.Transform],
        in bounds: LayerTree.Rect
    ) -> [LayerTree.Transform]? {
        guard units == .objectBoundingBox else { return transform }
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        return [.translate(tx: bounds.x, ty: bounds.y), .scale(sx: bounds.width, sy: bounds.height)] + transform
    }

    /// Most stops a `reflect` or `repeat` gradient expands to.
    static var maxSpreadStops: Int { 4096 }

    /// Most periods drawn for a gradient of `stopCount` stops (each period may gain two stops when
    /// completed to 0...1); a gradient needing more paints its average colour instead.
    static func maxSpreadPeriods(stopCount: Int) -> Int {
        max(1, maxSpreadStops / (stopCount + 2))
    }

    /// The periods of a linear gradient (0 being start...end) needed to cover `area`, which is in
    /// user space; `transform` maps gradient space to user space. nil when they cannot be computed.
    static func spreadPeriods(
        start: LayerTree.Point,
        end: LayerTree.Point,
        transform: [LayerTree.Transform],
        covering area: LayerTree.Rect
    ) -> ClosedRange<Int>? {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = dx * dx + dy * dy
        guard length > 0, let inverse = transform.toMatrix().inverted() else { return nil }
        let offsets = area.corners.map {
            let p = inverse.transform(point: $0)
            return ((p.x - start.x) * dx + (p.y - start.y) * dy) / length
        }
        guard let lower = offsets.min(), let upper = offsets.max(),
            lower.isFinite, upper.isFinite
        else { return nil }
        // bounded so the conversion to Int cannot trap; anything this large is averaged anyway
        let limit: LayerTree.Float = 1_000_000
        let first = Int(max(-limit, lower.rounded(.down)))
        let last = Int(min(limit, upper.rounded(.up))) - 1
        return first...max(first, last)
    }

    // Resolves the layer's filter into its user space; nil when a primitive is unsupported
    // or the filter region cannot be resolved (e.g. text-only contents under objectBoundingBox),
    // in which case the contents are drawn unfiltered.
    func makeFilterLayer(
        for layer: LayerTree.Layer,
        colorConverter: any ColorConverter = DefaultColorConverter()
    ) -> LayerTree.FilterLayer? {
        guard !layer.filters.isEmpty,
            !layer.hasUnsupportedFilters
        else { return nil }

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

        // primitive values map to user space as units.origin + value × units.size
        var units = LayerTree.Rect(x: 0, y: 0, width: 1, height: 1)
        if region.primitiveUnits == .objectBoundingBox {
            guard let bounds else { return nil }
            units = bounds
        }

        guard rect.x.isFinite, rect.y.isFinite, rect.width.isFinite, rect.height.isFinite else { return nil }

        let width = max(rect.width, 0)
        let height = max(rect.height, 0)
        let filterRegion = LayerTree.Rect(x: rect.x, y: rect.y, width: width, height: height)

        // the primary tree only, inputs renumbered to positions within it
        let inputs = LayerTree.FilterLayer.makeInputs(for: layer.filters)
        var positions = [Int: Int]()
        var primitives = [LayerTree.FilterLayer.Primitive]()
        let tree = LayerTree.FilterLayer.primaryTree(of: inputs)
        guard
            LayerTree.FilterLayer.primitiveCount(of: tree.map { layer.filters[$0] })
                <= LayerTree.FilterLayer.maxPrimitives
        else {
            return nil
        }
        for index in tree {
            let primitive = layer.filters[index]
            let sources = inputs[index].map { input -> LayerTree.FilterLayer.Input in
                guard case .primitive(let source) = input else { return input }
                return positions[source].map { .primitive($0) } ?? .transparent
            }
            let subregion = makeSubregion(
                for: primitive,
                inputs: sources,
                resolved: primitives,
                region: filterRegion,
                units: units
            )
            let colorInterpolation: LayerTree.FilterLayer.ColorInterpolation =
                primitive.colorInterpolation == .linearRGB ? .linearRGB : .sRGB
            if case .image(let image) = primitive.effect {
                let placement = makeUnclippedSubregion(
                    for: primitive,
                    inputs: sources,
                    resolved: primitives,
                    region: filterRegion,
                    units: units
                )
                positions[index] = primitives.count
                primitives.append(
                    LayerTree.FilterLayer.Primitive(
                        effect: makeFilterImage(image, element: layer.filterImages[index], placement: placement),
                        inputs: sources,
                        subregion: subregion,
                        colorInterpolation: colorInterpolation
                    )
                )
                continue
            }
            if case .dropShadow(let shadow) = primitive.effect {
                primitives.append(
                    contentsOf: makeDropShadow(
                        shadow,
                        input: sources.first ?? .sourceGraphic,
                        first: primitives.count,
                        subregion: subregion,
                        region: filterRegion,
                        scale: units.size,
                        colorInterpolation: colorInterpolation,
                        colorConverter: colorConverter
                    )
                )
                positions[index] = primitives.count - 1
                continue
            }
            guard let effect = makeFilterEffect(primitive.effect, scale: units.size, colorConverter: colorConverter)
            else {
                return nil
            }
            positions[index] = primitives.count
            primitives.append(
                LayerTree.FilterLayer.Primitive(
                    effect: effect,
                    inputs: sources,
                    subregion: subregion,
                    colorInterpolation: colorInterpolation
                )
            )
        }

        return LayerTree.FilterLayer(region: filterRegion, primitives: primitives)
    }

    // Filter Effects 1 §9.4: x, y, width and height default to the union of the subregions of the inputs, or to
    // the filter region when there is no input or one is a standard input. The subregion never exceeds the
    // filter region (SVG 1.1 §15.7.3); zero or negative sizes disable the primitive (empty rect).
    func makeSubregion(
        for primitive: LayerTree.FilterPrimitive,
        inputs: [LayerTree.FilterLayer.Input],
        resolved: [LayerTree.FilterLayer.Primitive],
        region: LayerTree.Rect,
        units: LayerTree.Rect
    ) -> LayerTree.Rect {
        guard
            let rect = makeUnclippedSubregion(
                for: primitive,
                inputs: inputs,
                resolved: resolved,
                region: region,
                units: units
            )
        else { return .zero }
        // the default is already within the region: keep it exact
        guard primitive.x != nil || primitive.y != nil || primitive.width != nil || primitive.height != nil else {
            return rect
        }
        let minX = max(rect.minX, region.minX)
        let minY = max(rect.minY, region.minY)
        let maxX = min(rect.maxX, region.maxX)
        let maxY = min(rect.maxY, region.maxY)
        guard maxX > minX, maxY > minY else { return .zero }
        return LayerTree.Rect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    // The subregion's x, y, width and height in user space, before the filter region clips them;
    // nil when the primitive is disabled
    func makeUnclippedSubregion(
        for primitive: LayerTree.FilterPrimitive,
        inputs: [LayerTree.FilterLayer.Input],
        resolved: [LayerTree.FilterLayer.Primitive],
        region: LayerTree.Rect,
        units: LayerTree.Rect
    ) -> LayerTree.Rect? {
        var rect: LayerTree.Rect? = inputs.isEmpty ? region : nil
        for input in inputs {
            guard case .primitive(let source) = input else {
                rect = region
                break
            }
            let other = resolved[source].subregion
            guard !other.isEmpty else { continue }
            rect = rect.map { $0.union(other) } ?? other
        }
        guard let rect else { return nil }
        guard primitive.x != nil || primitive.y != nil || primitive.width != nil || primitive.height != nil else {
            return rect
        }

        var x = primitive.x.map { units.x + LayerTree.Float($0) * units.width } ?? rect.x
        var y = primitive.y.map { units.y + LayerTree.Float($0) * units.height } ?? rect.y
        var width = primitive.width.map { LayerTree.Float($0) * units.width } ?? rect.width
        var height = primitive.height.map { LayerTree.Float($0) * units.height } ?? rect.height
        if !x.isFinite { x = rect.x }
        if !y.isFinite { y = rect.y }
        if !width.isFinite { width = rect.width }
        if !height.isFinite { height = rect.height }
        guard width > 0, height > 0 else { return nil }
        return LayerTree.Rect(x: x, y: y, width: width, height: height)
    }

    // Filter Effects 1 §9.15: a referenced element is drawn as a <use> would, offset to the origin of the
    // subregion (`placement`, before the filter region clips it); its own transform applies, but the
    // subregion's size does not scale it, as in resvg and Chrome. An image is fitted into the subregion per
    // preserveAspectRatio, as <image> into its viewport. Anything else (a missing, recursive or non-graphics
    // element, an image that cannot be loaded, a disabled primitive) is transparent black.
    func makeFilterImage(
        _ image: DOM.Filter.Image,
        element: LayerTree.Layer?,
        placement: LayerTree.Rect?
    ) -> LayerTree.FilterLayer.Effect {
        guard let placement else { return .flood(.none) }
        let layer = LayerTree.Layer()
        if let element {
            if placement.x != 0 || placement.y != 0 {
                layer.transform = [.translate(tx: placement.x, ty: placement.y)]
            }
            layer.appendContents(.layer(element))
        } else if let decoded = image.href?.decodedData,
            var bitmap = LayerTree.Image(mimeType: decoded.mimeType, data: decoded.data)
        {
            bitmap.origin = placement.origin
            bitmap.width = placement.width
            bitmap.height = placement.height
            bitmap.preserveAspectRatio = image.preserveAspectRatio
            layer.appendContents(.image(bitmap))
        } else {
            return .flood(.none)
        }
        return .image(LayerTree.FilterLayer.Image(layer: layer, isPixelated: image.isPixelated))
    }

    // Filter Effects 1 §9.12: feDropShadow is the blur of the input's alpha, offset, flooded with the
    // shadow colour, under the input. The colour comes from the flood `in` the offset blur, so the blur
    // can read the input itself: only its alpha reaches the result. The steps between are unclipped
    // (the filter region), the shadow's own subregion clips the merged result.
    func makeDropShadow(
        _ shadow: DOM.Filter.DropShadow,
        input: LayerTree.FilterLayer.Input,
        first: Int,
        subregion: LayerTree.Rect,
        region: LayerTree.Rect,
        scale: LayerTree.Size,
        colorInterpolation: LayerTree.FilterLayer.ColorInterpolation,
        colorConverter: any ColorConverter
    ) -> [LayerTree.FilterLayer.Primitive] {
        func make(_ filter: LayerTree.Filter) -> LayerTree.FilterLayer.Effect {
            // only feDropShadow's own values reach here, all of them supported
            makeFilterEffect(filter, scale: scale, colorConverter: colorConverter)!
        }
        func primitive(
            _ effect: LayerTree.FilterLayer.Effect,
            _ inputs: [LayerTree.FilterLayer.Input],
            _ subregion: LayerTree.Rect
        ) -> LayerTree.FilterLayer.Primitive {
            LayerTree.FilterLayer.Primitive(
                effect: effect,
                inputs: inputs,
                subregion: subregion,
                colorInterpolation: colorInterpolation
            )
        }
        return [
            primitive(
                make(.gaussianBlur(stdDeviation: shadow.stdDeviation, stdDeviationY: shadow.stdDeviationY)),
                [input],
                region
            ),
            primitive(make(.offset(dx: shadow.dx, dy: shadow.dy)), [.primitive(first)], region),
            primitive(make(.flood(color: shadow.color, opacity: shadow.opacity)), [], region),
            primitive(.composite(.in), [.primitive(first + 2), .primitive(first + 1)], region),
            primitive(.merge, [.primitive(first + 3), input], subregion),
        ]
    }

    // The effect in user units; nil when unsupported.
    func makeFilterEffect(
        _ effect: LayerTree.Filter,
        scale: LayerTree.Size,
        colorConverter: any ColorConverter
    ) -> LayerTree.FilterLayer.Effect? {
        // renderers clamp to their pixel limits; keep the values finite
        let maximum = LayerTree.Float.greatestFiniteMagnitude
        switch effect {
        case let .gaussianBlur(stdDeviation: x, stdDeviationY: y):
            // Filter Effects 1 §9.14: a negative value disables the primitive, zero disables one direction.
            let y = y ?? x
            guard x >= 0, y >= 0 else {
                return .gaussianBlur(stdDeviation: 0, stdDeviationY: 0)
            }
            return .gaussianBlur(
                stdDeviation: min(x * scale.width, maximum),
                stdDeviationY: min(y * scale.height, maximum)
            )
        case .unsupported:
            return nil
        case let .offset(dx: dx, dy: dy):
            return .offset(
                dx: max(-maximum, min(dx * scale.width, maximum)),
                dy: max(-maximum, min(dy * scale.height, maximum))
            )
        case let .flood(color: color, opacity: opacity):
            // Filter Effects 1 §9.13: flood-opacity multiplies the alpha of flood-color
            let flood = LayerTree.Color.create(from: color, current: .none).withAlpha(opacity)
            return .flood(colorConverter.createColor(from: flood))
        case .composite(let op):
            return .composite(op)
        case .merge:
            return .merge
        case .blend(let mode):
            return .blend(mode)
        case .colorMatrix(let matrix):
            return .colorMatrix(matrix.values)
        case .componentTransfer(let transfer):
            return .componentTransfer(transfer)
        case let .morphology(op, radius: x, radiusY: y):
            // Filter Effects 1 §9.17: a negative radius, or both zero, disables the primitive (the input).
            // One zero with the other positive is 1, as in resvg, Chrome and Safari.
            var x = x
            var y = y ?? x
            guard x >= 0, y >= 0, x > 0 || y > 0 else {
                return .morphology(op, radiusX: 0, radiusY: 0)
            }
            if x == 0 { x = 1 }
            if y == 0 { y = 1 }
            return .morphology(
                op,
                radiusX: min(x * scale.width, maximum),
                radiusY: min(y * scale.height, maximum)
            )
        case .turbulence(let turbulence):
            return makeTurbulence(turbulence)
        case .convolveMatrix(let matrix):
            return makeConvolveMatrix(matrix)
        case .image:
            // resolved with its subregion by makeFilterImage
            return nil
        case .dropShadow:
            // resolved into its primitives by makeDropShadow
            return nil
        }
    }

    // Filter Effects 1 §9.21: a negative frequency is an error, transparent black as in resvg and Safari.
    // baseFrequency is in user space whatever primitiveUnits is, as in resvg and Safari.
    // The seed is truncated towards zero (the spec's reference code takes an integer).
    func makeTurbulence(_ turbulence: DOM.Filter.Turbulence) -> LayerTree.FilterLayer.Effect {
        guard turbulence.baseFrequencyX >= 0, turbulence.baseFrequencyY >= 0 else {
            return .flood(.none)
        }
        let seed = turbulence.seed.rounded(.towardZero)
        return .turbulence(
            LayerTree.FilterLayer.Turbulence(
                baseFrequencyX: turbulence.baseFrequencyX,
                baseFrequencyY: turbulence.baseFrequencyY,
                numOctaves: max(0, turbulence.numOctaves),
                seed: Int(max(-2_147_483_648, min(Double(seed), 2_147_483_647))),
                isFractalNoise: turbulence.type == .fractalNoise,
                stitchTiles: turbulence.stitchTiles
            )
        )
    }

    // Filter Effects 1 §9.9: an order that is not a positive integer, a kernelMatrix of another size than
    // orderX × orderY and a target outside the kernel are errors: transparent black, as in resvg and Safari.
    // A divisor of zero is an error too, as in resvg and Safari. A missing divisor is the sum of the kernel,
    // or 1 when that is zero (within rounding: 0.1 × 8 - 0.8 is not quite 0 in Float).
    func makeConvolveMatrix(_ matrix: DOM.Filter.ConvolveMatrix) -> LayerTree.FilterLayer.Effect {
        let targetX = matrix.targetX ?? matrix.orderX / 2
        let targetY = matrix.targetY ?? matrix.orderY / 2
        let size = matrix.orderX.multipliedReportingOverflow(by: matrix.orderY)
        guard matrix.orderX > 0, matrix.orderY > 0, !size.overflow,
            matrix.kernelMatrix.count == size.partialValue,
            (0..<matrix.orderX).contains(targetX),
            (0..<matrix.orderY).contains(targetY),
            matrix.divisor != 0
        else {
            return .flood(.none)
        }
        var divisor: Float
        if let value = matrix.divisor {
            divisor = value
        } else {
            let sum = matrix.kernelMatrix.reduce(0, +)
            let magnitude = matrix.kernelMatrix.reduce(0) { $0 + abs($1) }
            divisor = abs(sum) > magnitude * 1e-5 && sum.isFinite ? sum : 1
        }
        return .convolveMatrix(
            LayerTree.FilterLayer.ConvolveMatrix(
                orderX: matrix.orderX,
                orderY: matrix.orderY,
                kernelMatrix: matrix.kernelMatrix,
                divisor: divisor,
                bias: matrix.bias,
                targetX: targetX,
                targetY: targetY,
                edgeMode: matrix.edgeMode,
                preserveAlpha: matrix.preserveAlpha
            )
        )
    }

    // Geometry bounding box of the layer contents in the layer's user space; stroke excluded.
    // Text counts with the box the builder measured for it (`textBounds`); nil when the contents
    // include text that was not measured: the filter is then dropped rather than clipping the text away.
    func makeBounds(for layer: LayerTree.Layer) -> LayerTree.Rect? {
        var points = [LayerTree.Point]()
        guard appendBounds(of: layer, to: &points, isTextMeasured: false), !points.isEmpty else { return nil }
        return .makeBounds(between: points)
    }

    /// Appends the corners of the layer's contents; false when it draws text without a measured box.
    /// - Parameter isTextMeasured: an ancestor's `textBounds` already covers the text of this layer
    private func appendBounds(
        of layer: LayerTree.Layer,
        to points: inout [LayerTree.Point],
        isTextMeasured: Bool
    ) -> Bool {
        var isTextMeasured = isTextMeasured
        if let bounds = layer.textBounds {
            points.append(contentsOf: bounds.corners)
            isTextMeasured = true
        }
        for contents in layer.contents {
            switch contents {
            case .shape(let shape, _, _):
                if let rect = shape.bounds {
                    points.append(contentsOf: rect.corners)
                }
            case .image(let image):
                if let width = image.width, let height = image.height {
                    points.append(
                        contentsOf: LayerTree.Rect(x: image.origin.x, y: image.origin.y, width: width, height: height)
                            .corners
                    )
                }
            case .text, .glyphs:
                guard isTextMeasured else { return false }
            case .layer(let child):
                var childPoints = [LayerTree.Point]()
                guard appendBounds(of: child, to: &childPoints, isTextMeasured: isTextMeasured) else { return false }
                let matrix = child.transform.toMatrix()
                points.append(contentsOf: childPoints.map { matrix.transform(point: $0) })
            }
        }
        return true
    }

    func logUnsupportedFilters(_ filters: [LayerTree.FilterPrimitive]) {
        guard !hasLoggedFilterWarning else { return }
        // name only what is unsupported: the rest of the filter renders
        let unsupported = filters.map(\.effect).filter { !$0.isSupported }
        let name =
            unsupported.isEmpty
            ? "A filter of more than \(LayerTree.FilterLayer.maxPrimitives) primitives"
            : Set(unsupported.map(\.name)).sorted().joined(separator: ", ")

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

        LogSink.warning("\(name) is not supported. Elements with this filter can be hidden with \(hint)")
        hasLoggedFilterWarning = true
    }

    func logUnsupportedGradient() {
        guard !hasLoggedGradientWarning else { return }
        LogSink.warning("PDF does not support gradients with stop-opacity")
        hasLoggedGradientWarning = true
    }

    func logUnsupportedSpread() {
        guard !hasLoggedSpreadWarning else { return }
        LogSink.warning(
            "spreadMethod needs more than \(Self.maxSpreadStops) gradient stops; painting the average colour"
        )
        hasLoggedSpreadWarning = true
    }

    func logUnsupportedMask() {
        guard !hasLoggedMaskWarning else { return }
        LogSink.warning("PDF does not support transparency masks")
        hasLoggedMaskWarning = true
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
                result.append(
                    Stop(
                        offset: (LayerTree.Float(index) + stop.offset) / count,
                        color: stop.color,
                        opacity: stop.opacity
                    )
                )
            }
        }
        return LayerTree.Gradient(stops: result, interpolation: interpolation)
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
        // the gradient's own space (P3 when any stop is P3); the other stops are converted into it
        let space = colorSpace
        for (lhs, rhs) in zip(period, period.dropFirst()) {
            let weight = (rhs.offset - lhs.offset) / 2
            for stop in [lhs, rhs] {
                let c = stop.premultiplied(in: space)
                sum = (sum.r + c.r * weight, sum.g + c.g * weight, sum.b + c.b * weight, sum.a + c.a * weight)
            }
        }
        let color: LayerTree.Color =
            sum.a > 0
            ? .rgba(r: sum.r / sum.a, g: sum.g / sum.a, b: sum.b / sum.a, a: sum.a, space: space)
            : .none
        return LayerTree.Gradient(stops: [
            Stop(offset: 0, color: color, opacity: 1),
            Stop(offset: 1, color: color, opacity: 1),
        ])
    }
}

private extension LayerTree.Gradient.Stop {
    func premultiplied(
        in space: LayerTree.ColorSpace
    ) -> (r: LayerTree.Float, g: LayerTree.Float, b: LayerTree.Float, a: LayerTree.Float) {
        switch color {
        case .none:
            return (0, 0, 0, 0)
        case let .rgba(r, g, b, a, source):
            let alpha = a * opacity
            let (r, g, b) = LayerTree.Color.convert(r: r, g: g, b: b, from: source, to: space)
            return (r * alpha, g * alpha, b * alpha, alpha)
        case let .gray(white, a):
            let alpha = a * opacity
            return (white * alpha, white * alpha, white * alpha, alpha)
        }
    }
}

extension LayerTree.Color {

    /// The sRGB transfer curve, from encoded to linear light.
    static func linear(_ v: LayerTree.Float) -> LayerTree.Float {
        v <= 0.04045 ? v / 12.92 : LayerTree.Float(pow(Double((v + 0.055) / 1.055), 2.4))
    }

    /// The sRGB transfer curve, from linear light to encoded. Clamped to 0...1.
    static func encode(_ v: LayerTree.Float) -> LayerTree.Float {
        let c = min(1, max(0, v))
        return c <= 0.0031308 ? c * 12.92 : LayerTree.Float(1.055 * pow(Double(c), 1 / 2.4) - 0.055)
    }

    /// Display P3 shares sRGB's transfer curve: convert through linear light. Clamped to 0...1.
    static func convert(
        r: LayerTree.Float,
        g: LayerTree.Float,
        b: LayerTree.Float,
        from: LayerTree.ColorSpace,
        to: LayerTree.ColorSpace
    ) -> (LayerTree.Float, LayerTree.Float, LayerTree.Float) {
        guard from != to else { return (r, g, b) }
        let (lr, lg, lb) = (linear(r), linear(g), linear(b))
        if from == .p3 {
            return (
                encode(1.2249401 * lr - 0.2249404 * lg),
                encode(-0.0420569 * lr + 1.0420571 * lg),
                encode(-0.0196376 * lr - 0.0786361 * lg + 1.0982735 * lb)
            )
        }
        return (
            encode(0.8224621 * lr + 0.1775380 * lg),
            encode(0.0331941 * lr + 0.9668058 * lg),
            encode(0.0170827 * lr + 0.0723974 * lg + 0.9105199 * lb)
        )
    }
}

private extension LayerTree.StrokeAttributes {
    /// How far the stroke may reach beyond the path's bounds: half the width, √2 times that at
    /// square caps, up to the miter limit at miter joins.
    var coverage: LayerTree.Float {
        let cap: LayerTree.Float = cap == .square ? LayerTree.Float(2).squareRoot() : 1
        let join: LayerTree.Float = join == .miter ? max(1, miterLimit) : 1
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
        return Self(
            a: d / determinant,
            b: -b / determinant,
            c: -c / determinant,
            d: a / determinant,
            tx: (c * ty - d * tx) / determinant,
            ty: (b * tx - a * ty) / determinant
        )
    }
}

private extension LayerTree.Filter {
    var name: String {
        switch self {
        case .gaussianBlur(_, _):
            return "<feGaussianBlur>"
        case .unsupported(let name):
            return "<\(name)>"
        case .offset:
            return "<feOffset>"
        case .flood:
            return "<feFlood>"
        case .composite:
            return "<feComposite>"
        case .merge:
            return "<feMerge>"
        case .blend:
            return "<feBlend>"
        case .colorMatrix:
            return "<feColorMatrix>"
        case .componentTransfer:
            return "<feComponentTransfer>"
        case .morphology:
            return "<feMorphology>"
        case .turbulence:
            return "<feTurbulence>"
        case .convolveMatrix:
            return "<feConvolveMatrix>"
        case .image:
            return "<feImage>"
        case .dropShadow:
            return "<feDropShadow>"
        }
    }
}

private extension LayerTree.Rect {

    var isEmpty: Bool {
        width <= 0 || height <= 0
    }

    func outset(by amount: LayerTree.Float) -> LayerTree.Rect {
        LayerTree.Rect(x: x - amount, y: y - amount, width: width + amount * 2, height: height + amount * 2)
    }

    var corners: [LayerTree.Point] {
        [
            origin,
            LayerTree.Point(maxX, minY),
            LayerTree.Point(maxX, maxY),
            LayerTree.Point(minX, maxY),
        ]
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
    static func resolvePattern(
        _ pattern: LayerTree.Pattern,
        in boundingBox: @autoclosure () -> LayerTree.Rect
    ) -> (LayerTree.Pattern, LayerTree.Transform.Matrix)? {
        let t = pattern.transform
        let determinant = t.a * t.d - t.b * t.c
        guard [t.a, t.b, t.c, t.d, t.tx, t.ty].allSatisfy(\.isFinite),
            determinant.isFinite, determinant != 0
        else { return nil }

        let needsBounds =
            pattern.units == .objectBoundingBox
            || (pattern.viewBox == nil && pattern.contentUnits == .objectBoundingBox)
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
            tile.width > 0, tile.height > 0
        else { return nil }

        var contentTransform = LayerTree.Transform.Matrix.identity
        if let viewBox = pattern.viewBox {
            // the viewBox is fitted into the tile per the pattern's preserveAspectRatio (SVG 1.1 §7.8)
            guard viewBox.width > 0, viewBox.height > 0 else { return nil }
            let fit = pattern.preserveAspectRatio.fit(
                contentWidth: viewBox.width,
                contentHeight: viewBox.height,
                viewportWidth: tile.width,
                viewportHeight: tile.height
            )
            // a tiny viewBox in a large tile can overflow the scale: no pattern, not an infinite matrix
            guard [fit.sx, fit.sy, fit.tx, fit.ty].allSatisfy(\.isFinite) else { return nil }
            contentTransform = LayerTree.Transform.Matrix(
                a: fit.sx,
                b: 0,
                c: 0,
                d: fit.sy,
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
