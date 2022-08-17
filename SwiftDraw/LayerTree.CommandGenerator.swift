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

// Convert a LayerTree into RenderCommands

extension LayerTree {

    final class CommandGenerator<P: RendererTypeProvider> {

        let provider: P
        let size: LayerTree.Size
        let scale: LayerTree.Float
        let options: SwiftDraw.Image.Options

        private var hasLoggedFilterWarning: Bool = false

        init(provider: P, size: LayerTree.Size, scale: LayerTree.Float = 3.0, options: SwiftDraw.Image.Options) {
            self.provider = provider
            self.size = size
            self.scale = scale
            self.options = options
        }

        func renderCommands(for layer: Layer, colorConverter: ColorConverter = DefaultColorConverter()) -> [RendererCommand<P.Types>] {
            if provider.supportsTransparencyLayers {
                return renderCommandsWithTransparency(for: layer, colorConverter: colorConverter)
            } else {
                return renderCommandsWithoutTransparency(for: layer, colorConverter: colorConverter)
            }
        }

        func renderCommandsWithTransparency(for layer: Layer, colorConverter: ColorConverter = DefaultColorConverter()) -> [RendererCommand<P.Types>] {
            guard layer.opacity > 0.0 else { return [] }

            if !layer.filters.isEmpty {
                guard !options.contains(.hideUnsupportedFilters) else {
                    return []
                }
                logUnsupportedFilters(layer.filters)
            }

            let opacityCommands = renderCommands(forOpacity: layer.opacity)
            let transformCommands = renderCommands(forTransforms: layer.transform)
            let clipCommands = renderCommands(forClip: layer.clip, using: layer.clipRule)
            let maskCommands = renderCommands(forMask: layer.mask)

            var commands = [RendererCommand<P.Types>]()

            if !opacityCommands.isEmpty ||
                !transformCommands.isEmpty ||
                !clipCommands.isEmpty ||
                !maskCommands.isEmpty {
                commands.append(.pushState)
            }

            commands.append(contentsOf: transformCommands)
            commands.append(contentsOf: opacityCommands)
            commands.append(contentsOf: clipCommands)

            if !maskCommands.isEmpty {
                commands.append(.pushTransparencyLayer)
            }

            //render all of the layer contents
            for contents in layer.contents {
                commands.append(contentsOf: renderCommands(for: contents, colorConverter: colorConverter))
            }

            //render apply mask
            if !maskCommands.isEmpty {
                commands.append(contentsOf: maskCommands)
                commands.append(.popTransparencyLayer)
            }

            if !opacityCommands.isEmpty {
                commands.append(.popTransparencyLayer)
            }

            if !opacityCommands.isEmpty ||
                !transformCommands.isEmpty ||
                !clipCommands.isEmpty ||
                !maskCommands.isEmpty {
                commands.append(.popState)
            }

            return commands
        }

        func renderCommandsWithoutTransparency(for layer: Layer, colorConverter: ColorConverter = DefaultColorConverter()) -> [RendererCommand<P.Types>] {
            guard layer.opacity > 0.0 else { return [] }

            if !layer.filters.isEmpty {
                guard !options.contains(.hideUnsupportedFilters) else {
                    return []
                }
                logUnsupportedFilters(layer.filters)
            }

            let opacityCommands = renderCommands(forOpacity: layer.opacity)
            let transformCommands = renderCommands(forTransforms: layer.transform)
            let clipCommands = renderCommands(forClip: layer.clip, using: layer.clipRule)
            let mask = makeMask(forMask: layer.mask)

            var commands = [RendererCommand<P.Types>]()

            if !opacityCommands.isEmpty ||
                !transformCommands.isEmpty ||
                !clipCommands.isEmpty ||
                mask != nil {
                commands.append(.pushState)
            }

            commands.append(contentsOf: transformCommands)
            commands.append(contentsOf: opacityCommands)
            commands.append(contentsOf: clipCommands)

            if let mask = mask {
                let bounds = provider.createRect(from: LayerTree.Rect(x: 0, y: 0, width: size.width * scale, height: size.height * scale))
                commands.append(.setClipMask(mask, frame: bounds))

                //render all of the layer contents
                for contents in layer.contents {
                    commands.append(contentsOf: renderCommands(for: contents, colorConverter: colorConverter))
                }

            } else {
                //render all of the layer contents
                for contents in layer.contents {
                    commands.append(contentsOf: renderCommands(for: contents, colorConverter: colorConverter))
                }
            }

            if !opacityCommands.isEmpty {
                commands.append(.popTransparencyLayer)
            }

            if !opacityCommands.isEmpty ||
                !transformCommands.isEmpty ||
                !clipCommands.isEmpty ||
                mask != nil {
                commands.append(.popState)
            }

            return commands
        }

        func renderCommands(for contents: Layer.Contents, colorConverter: ColorConverter) -> [RendererCommand<P.Types>] {
            switch contents {
            case .shape(let shape, let stroke, let fill):
                return renderCommands(for: shape, stroke: stroke, fill: fill, colorConverter: colorConverter)
            case .image(let image):
                return renderCommands(for: image)
            case .text(let text, let point, let att):
                return renderCommands(for: text, at: point, attributes: att, colorConverter: colorConverter)
            case .layer(let layer):
                return renderCommands(for: layer, colorConverter: colorConverter)
            }
        }

        func renderCommands(for shape: Shape,
                            stroke: StrokeAttributes,
                            fill: FillAttributes,
                            colorConverter: ColorConverter) -> [RendererCommand<P.Types>] {
            var commands = [RendererCommand<P.Types>]()
            let path = provider.createPath(from: shape)

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
                commands.append(.pushState)
                let rule = provider.createFillRule(from: fill.rule)
                commands.append(.setClip(path: path, rule: rule))

                let pathBounds = provider.getBounds(from: shape)
                commands.append(contentsOf: renderCommands(forLinear: gradient,
                                                           endpoints: pathBounds.endpoints,
                                                           opacity: fill.opacity,
                                                           colorConverter: colorConverter))
                commands.append(.popState)
            case .radialGradient(let gradient):
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
                if let endpoints = shape.endpoints {
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
                if let pathBounds = shape.bounds {
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
            guard let renderImage = provider.createImage(from: image) else { return  [] }
            return [.draw(image: renderImage)]
        }

        func renderCommands(for text: String, at point: Point, attributes: TextAttributes, colorConverter: ColorConverter = DefaultColorConverter()) -> [RendererCommand<P.Types>] {
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

        func renderCommands(forClip shapes: [Shape], using rule: FillRule?) -> [RendererCommand<P.Types>] {
            guard !shapes.isEmpty else { return [] }

            let paths = shapes.map { provider.createPath(from: $0) }
            let clipPath = provider.createPath(from: paths)
            let rule = provider.createFillRule(from: rule ?? .nonzero)
            return [.setClip(path: clipPath, rule: rule)]
        }

        func makeMask(forMask layer: Layer?) -> P.Types.Mask? {
            guard let layer = layer else { return nil }

            var commands = layer.contents.flatMap {
                renderCommands(for: $0, colorConverter: GrayscaleMaskColorConverter())
            }
            guard commands.isEmpty == false else { return nil }

            commands.append(.scale(sx: provider.createFloat(from: scale), sy: provider.createFloat(from: scale)))
            return provider.createMask(from: commands, size: LayerTree.Size(size.width*scale, size.height*scale))
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
                renderCommands(for: $0, colorConverter: LuminanceColorConverter())
            }
            commands.append(contentsOf: drawMask)
            commands.append(.popTransparencyLayer)
            return commands
        }


        func renderCommands(forLinear gradient: LayerTree.LinearGradient,
                            endpoints: (start: LayerTree.Point, end: LayerTree.Point),
                            opacity: LayerTree.Float,
                            colorConverter: ColorConverter) -> [RendererCommand<P.Types>] {
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
                            colorConverter: ColorConverter) -> [RendererCommand<P.Types>] {
            let startCenter: LayerTree.Point
            let startRadius: LayerTree.Float
            let endCenter: LayerTree.Point
            let endRadius: LayerTree.Float

            switch gradient.units  {
            case .objectBoundingBox:
                let h = sqrt((bounds.width*bounds.width) + (bounds.height*bounds.height)) / 2
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

    static func logParsingError(for error: Swift.Error, filename: String?, parsing element: XML.Element? = nil) {
        let elementName = element.map { "<\($0.name)>" } ?? ""
        let filename = filename ?? ""
        switch error {
        case let XMLParser.Error.invalidDocument(error, element, line, column):
            let element = element.map { "<\($0)>" } ?? ""
            if let error = error {
                print("[parsing error]", filename, element, "line:", line, "column:", column, "error:", error, to: &.standardError)
            } else {
                print("[parsing error]", filename, element, "line:", line, "column:", column, to: &.standardError)
            }
        case let XMLParser.Error.invalidElement(name, error, line, column):
            if let line = line {
                print("[parsing error]", filename, "<\(name)>", "line:", line, "column:", column ?? -1, "error:", error, to: &.standardError)
            } else {
                print("[parsing error]", filename, "<\(name)>", "error:", error, to: &.standardError)
            }
        default:
            if let location = element?.parsedLocation {
                print("[parsing error]", filename, elementName, "line:", location.line, "column:", location.column, "error:", error, to: &.standardError)
            } else {
                print("[parsing error]", filename, elementName, "error:", error, to: &.standardError)
            }
        }
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
    func convertColor(using converter: ColorConverter) -> LayerTree.Gradient {
        let stops: [LayerTree.Gradient.Stop] = stops.map { stop in
            var stop = stop
            stop.color = converter.createColor(from: stop.color).withMultiplyingAlpha(stop.opacity)
            return stop
        }
        return LayerTree.Gradient(stops: stops)
    }
}

private func apply(colorConverter: ColorConverter, to stop: LayerTree.Gradient.Stop) -> LayerTree.Gradient.Stop {
    var stop = stop
    stop.color = colorConverter.createColor(from: stop.color).withMultiplyingAlpha(stop.opacity)
    return stop
}

private extension LayerTree.Rect {
    var center: LayerTree.Point {
        LayerTree.Point(
            origin.x + (size.width / 2),
            origin.y + (size.height / 2)
        )
    }
}

private extension LayerTree.Shape {

    var endpoints: (start: LayerTree.Point, end: LayerTree.Point)? {
        guard case .path(let p) = self else { return nil }
        return p.endpoints
    }

    var bounds: LayerTree.Rect? {
        guard case .path(let p) = self else { return nil }
        return p.bounds
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
