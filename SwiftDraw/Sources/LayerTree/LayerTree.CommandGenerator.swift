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
                    stack.append(.endLayer(layer, state))

                    if state.hasFilters {
                        logUnsupportedFilters(layer.filters)
                    }

                    if state.hasOpacity || state.hasTransform || state.hasClip || state.hasMask {
                        commands.append(.pushState)
                    }

                    commands.append(contentsOf: renderCommands(forTransforms: layer.transform))
                    commands.append(contentsOf: renderCommands(forOpacity: layer.opacity))
                    commands.append(contentsOf: renderCommands(forClip: layer.clip, using: layer.clipRule))

                    if state.hasMask {
                        commands.append(.pushTransparencyLayer)
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
                colorConverter: colorConverter
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
                var patternCommands = [RendererCommand<P.Types>]()
                for contents in fillPattern.contents {
                    patternCommands.append(contentsOf: renderCommands(for: contents, colorConverter: colorConverter))
                }

                let pattern = provider.createPattern(from: fillPattern, contents: patternCommands)
                let rule = provider.createFillRule(from: fill.rule)
                commands.append(.setFillPattern(pattern))
                commands.append(.fill(path, rule: rule))
            case .linearGradient(let gradient):
                if canRenderGradient(gradient.gradient) {
                    commands.append(.pushState)
                    let rule = provider.createFillRule(from: fill.rule)
                    commands.append(.setClip(path: path, rule: rule))

                    let pathBounds = provider.getBounds(from: shape)
                    commands.append(contentsOf: renderCommands(forLinear: gradient,
                                                               endpoints: pathBounds.endpoints,
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

                commands.append(.setLineCap(cap))
                commands.append(.setLineJoin(join))
                commands.append(.setLine(width: width))
                commands.append(.setLineMiter(limit: limit))
                commands.append(.setStroke(color: color))
                commands.append(.stroke(path))
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
                    commands.append(.clipStrokeOutline(path))

                    commands.append(contentsOf: renderCommands(forLinear: gradient,
                                                               endpoints: endpoints,
                                                               opacity: fill.opacity,
                                                               colorConverter: colorConverter))
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
                    commands.append(.clipStrokeOutline(path))

                    commands.append(contentsOf: renderCommands(forRadial: gradient,
                                                               in: pathBounds,
                                                               opacity: fill.opacity,
                                                               colorConverter: colorConverter))
                    commands.append(.popState)
                }
            default:
                ()
            }

            return commands
        }

        func renderCommands(for image: Image) -> [RendererCommand<P.Types>] {
            guard let renderImage = makeCachedImage(from: image) else { return  [] }
            let size = provider.createSize(from: renderImage)
            guard size.width > 0 && size.height > 0 else { return [] }

            let frame = makeImageFrame(for: image, bitmapSize: size)
            let rect = provider.createRect(from: frame)
            return [.draw(image: renderImage, in: rect)]
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
                            opacity: LayerTree.Float,
                            colorConverter: any ColorConverter) -> [RendererCommand<P.Types>] {
            let pathStart: LayerTree.Point
            let pathEnd: LayerTree.Point
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

            let converted =  gradient.gradient.convertColor(using: colorConverter)
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
                            opacity: LayerTree.Float,
                            colorConverter: any ColorConverter) -> [RendererCommand<P.Types>] {
            let startCenter: LayerTree.Point
            let startRadius: LayerTree.Float
            let endCenter: LayerTree.Point
            let endRadius: LayerTree.Float

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

            let converted =  gradient.gradient.convertColor(using: colorConverter)
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

    func logUnsupportedMask() {
        guard !hasLoggedMaskWarning else { return }
        print("Warning:", "PDF does not support transparency masks", to: &.standardError)
        hasLoggedMaskWarning = true
    }
}

private extension LayerTree.Rect {

    func getPoint(offset: LayerTree.Point) -> LayerTree.Point {
        return LayerTree.Point(origin.x + size.width * offset.x,
                               origin.y + size.height * offset.y)
    }

    var endpoints: (start: LayerTree.Point, end: LayerTree.Point) {
        let max = LayerTree.Point(origin.x + size.width, origin.y + size.height)
        return (start: origin, end: max)
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
        case .gaussianBlur:
            return "<feGaussianBlur>"
        }
    }
}

private extension LayerTree.Rect {

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
