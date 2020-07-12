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
  
  final class CommandGenerator<P: RendererTypeProvider>{
    
    let provider: P
    let size: LayerTree.Size
    let scale: LayerTree.Float
    
    init(provider: P, size: LayerTree.Size, scale: LayerTree.Float = 3.0) {
      self.provider = provider
      self.size = size
      self.scale = scale
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
      
      let opacityCommands = renderCommands(forOpacity: layer.opacity)
      let transformCommands = renderCommands(forTransforms: layer.transform)
      let clipCommands = renderCommands(forClip: layer.clip)
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
      
      let opacityCommands = renderCommands(forOpacity: layer.opacity)
      let transformCommands = renderCommands(forTransforms: layer.transform)
      let clipCommands = renderCommands(forClip: layer.clip)
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
      case .gradient(let fillGradient):
        commands.append(.pushState)
        commands.append(.setClip(path: path))

        let pathStart: LayerTree.Point
        let pathEnd: LayerTree.Point
        switch fillGradient.units  {
        case .objectBoundingBox:
          let pathBounds = provider.getBounds(from: path)
          pathStart = pathBounds.getPoint(offset: fillGradient.start)
          pathEnd = pathBounds.getPoint(offset: fillGradient.end)
        case .userSpaceOnUse:
          pathStart = fillGradient.start
          pathEnd = fillGradient.end
        }

        let converted = apply(colorConverter: colorConverter, to: fillGradient)
        let gradient = provider.createGradient(from: converted)
        let start = provider.createPoint(from: pathStart)
        let end = provider.createPoint(from: pathEnd)
        
        let apha = provider.createFloat(from: fill.opacity)
        commands.append(.setAlpha(apha))
        
        commands.append(.drawGradient(gradient, from: start, to: end))
        commands.append(.popState)
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
    
    func renderCommands(forClip shapes: [Shape]) -> [RendererCommand<P.Types>] {
      guard !shapes.isEmpty else { return [] }
      
      let paths = shapes.map { provider.createPath(from: $0) }
      let clipPath = provider.createPath(from: paths)
      
      return [.setClip(path: clipPath)]
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
  }
  
}

private extension LayerTree.Rect {
  
  func getPoint(offset: LayerTree.Point) -> LayerTree.Point {
    return LayerTree.Point(origin.x + size.width * offset.x,
                           origin.y + size.height * offset.y)
  }
}

private func apply(colorConverter: ColorConverter, to gradient: LayerTree.Gradient) -> LayerTree.Gradient {
  let converted = LayerTree.Gradient(start: gradient.start, end: gradient.end)
  converted.stops = gradient.stops.map { apply(colorConverter: colorConverter, to: $0) }
  return converted
}

private func apply(colorConverter: ColorConverter, to stop: LayerTree.Gradient.Stop) -> LayerTree.Gradient.Stop {
  var stop = stop
  stop.color = colorConverter.createColor(from: stop.color).withMultiplyingAlpha(stop.opacity)
  return stop
}
