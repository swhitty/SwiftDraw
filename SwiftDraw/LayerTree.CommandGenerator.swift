//
//  LayerTree.CommandGenerator.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 5/6/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
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
    
    final class CommandGenerator<P: RendererTypeProvider>{
        
        let provider: P
        
        init(provider: P) {
            self.provider = provider
        }
        
        func renderCommands(for layer: Layer) -> [RendererCommand<P.Types>] {
            guard layer.opacity > 0.0 else { return [] }
            
            let opacityCommands = renderCommands(forOpacity: layer.opacity)
            let transformCommands = renderCommands(forTransforms: layer.transform)
            let clipCommands = renderCommands(forClip: layer.clip)
            let maskCommands = renderCommands(forMask: layer.mask)
            
            //TODO: handle layer.mask
            // render to transparanency layer then composite contents on top.
            
            var commands = [RendererCommand<P.Types>]()
            
            if !opacityCommands.isEmpty ||
               !transformCommands.isEmpty ||
               !clipCommands.isEmpty ||
               !maskCommands.isEmpty {
                commands.append(.pushState)
            }
            
            commands.append(contentsOf: transformCommands)
            commands.append(contentsOf: maskCommands)
            commands.append(contentsOf: opacityCommands)
            commands.append(contentsOf: clipCommands)
  

            //render all of the layer contents
            for contents in layer.contents {
                commands.append(contentsOf: renderCommands(for: contents))
            }
            
            //clean up state
            if !maskCommands.isEmpty {
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
        
        func renderCommands(for contents: Layer.Contents, colorConverter: ColorConverter = DefaultColorConverter()) -> [RendererCommand<P.Types>] {
            switch contents {
            case .shape(let shape, let stroke, let fill):
                return renderCommands(for: shape, stroke: stroke, fill: fill, colorConverter: colorConverter)
            case .image(let image):
                return renderCommands(for: image)
            case .text(let text, let point, let att):
                return renderCommands(for: text, at: point, attributes: att, colorConverter: colorConverter)
            case .layer(let layer):
                return renderCommands(for: layer)
            }
        }
        
        func renderCommands(for shape: Shape,
                            stroke: StrokeAttributes,
                            fill: FillAttributes,
                            colorConverter: ColorConverter = DefaultColorConverter()) -> [RendererCommand<P.Types>] {
            var commands = [RendererCommand<P.Types>]()
            let path = provider.createPath(from: shape)
            
            if fill.color != .none {
                let converted = colorConverter.createColor(from: fill.color)
                let color = provider.createColor(from: converted)
                let rule = provider.createFillRule(from: fill.rule)
                commands.append(.setFill(color: color))
                commands.append(.fill(path, rule: rule))
            } else if let fillPattern = fill.pattern {
                var patternCommands = [RendererCommand<P.Types>]()
                for contents in fillPattern.contents {
                    patternCommands.append(contentsOf: renderCommands(for: contents))
                }

                let pattern = provider.createPattern(from: fillPattern, contents: patternCommands)
                let rule = provider.createFillRule(from: fill.rule)
                commands.append(.setFillPattern(pattern))
                commands.append(.fill(path, rule: rule))
            } else if let fillGradient = fill.gradient {

                print("fill \(fillGradient)")
            }

            if stroke.color != .none,
               stroke.width > 0.0 {
                let converted = colorConverter.createColor(from: stroke.color)
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
            case .translate(let t):
                let tx = provider.createFloat(from: t.tx)
                let ty = provider.createFloat(from: t.ty)
                return .translate(tx: tx, ty: ty)
            case .scale(let s):
                let sx = provider.createFloat(from: s.sx)
                let sy = provider.createFloat(from: s.sy)
                return .scale(sx: sx, sy: sy)
            case .rotate(let r):
                let radians = provider.createFloat(from: r)
                return .rotate(angle: radians)
            }
        }
        
        func renderCommands(forClip shapes: [Shape]) -> [RendererCommand<P.Types>] {
            guard !shapes.isEmpty else { return [] }
            
            let paths = shapes.map{ provider.createPath(from: $0) }
            let clipPath = provider.createPath(from: paths)
            
            return [.setClip(path: clipPath)]
        }
        
        func renderCommands(forMask layer: Layer?) -> [RendererCommand<P.Types>] {
            guard let layer = layer else { return [] }
            
            let modeCopy = provider.createBlendMode(from: .copy)
            let modeSourceIn = provider.createBlendMode(from: .sourceIn)
            
            var commands = [RendererCommand<P.Types>]()
            commands.append(.pushTransparencyLayer)
            commands.append(.setBlend(mode: modeCopy))
           
            let drawMask = layer.contents.flatMap{
                renderCommands(for: $0, colorConverter: LuminanceColorConverter())
            }
            commands.append(contentsOf: drawMask)
            
            commands.append(.setBlend(mode: modeSourceIn))
            return commands
        }
    }
    
}
