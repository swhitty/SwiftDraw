//
//  Builder.Command.swift
//  SwiftVG
//
//  Created by Simon Whitty on 27/3/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

import Foundation


extension Builder {
    
    func createCommands<T: RendererTypeProvider>(for svg: DOM.Svg, with provider: T) -> [RendererCommand<T>] {
        
        let width = Float(svg.width)
        let height = Float(svg.height)
        
        self.defs = svg.defs
        var commands = [RendererCommand<T>]()
        let flip = Transform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: height)
        let t = provider.createTransform(from: flip)
        commands.append(.concatenate(transform: t))
        
        if let viewBox = svg.viewBox {

            if viewBox.width != width || viewBox.height != height {
                let sx = provider.createFloat(from: width / viewBox.width)
                let sy = provider.createFloat(from: height / viewBox.height)
                commands.append(.scale(sx: sx, sy: sy))
            }
            
            if viewBox.x != 0 || viewBox.y != 0 {
                let tx = provider.createFloat(from: -viewBox.x)
                let ty = provider.createFloat(from: -viewBox.y)
                commands.append(.translate(tx: tx, ty: ty))
            }
        }
        
        commands.append(contentsOf: createCommands(for: svg as DOM.GraphicsElement,
                                                   inheriting: State(),
                                                   using: provider))
        return commands
    }
    
    func createCommands<T: RendererTypeProvider>(for element: DOM.GraphicsElement,
                                                 inheriting parentState: State,
                                                 using provider: T) -> [RendererCommand<T>] {
        
        var commands = [RendererCommand<T>]()
        
        let didBeginMask: Bool
        
        let transformCommands = createCommands(from: element.transform ?? [], with: provider)
        
        //mask if required
        if let maskId = element.mask?.fragment,
            let mask = defs.masks.first(where: { $0.id == maskId }) {
            
            commands.append(.pushTransparencyLayer)
            commands.append(.pushState)
            commands.append(contentsOf: transformCommands)
            didBeginMask = true
            commands.append(.setBlend(mode: provider.createBlendMode(from: .copy)))
            
            for child in mask.childElements {
                if let fill = child.fill,
                    let path = createPath(for: child, with: provider) {
                    let color = Builder.Color(fill).luminanceToAlpha()
                    commands.append(.setFill(color: provider.createColor(from: color)))
                    commands.append(.fill(path))
                }
            }
            
            commands.append(.popState)
            commands.append(.setBlend(mode: provider.createBlendMode(from: .sourceIn)))
        } else {
            didBeginMask = false
        }
        
        let state = createState(for: element, inheriting: parentState)
        
        if !transformCommands.isEmpty {
            commands.append(.pushState)
            commands.append(contentsOf: transformCommands)
        }
        
        //clip if required
        if let clipId = element.clipPath?.fragment,
           let clip = defs.clipPaths.first(where: { $0.id == clipId }) {
            let path = createClipPath(for: clip, with: provider)
            commands.append(.setClip(path: path))
        }

        //convert the element into a path to fill, then stroke if required
        if let path = createPath(for: element, with: provider) {
            commands.append(contentsOf: createFillCommands(for: path, with: state, using: provider))
            commands.append(contentsOf: createStrokeCommands(for: path, with: state, using: provider))
        }
        
        //if element is <use>, then retrieve elemnt from defs
        if let use = element as? DOM.Use,
           let eId = use.href.fragment,
           let e = defs.elements[eId] {
            commands.append(contentsOf: createCommands(for: e,
                                                       inheriting: state,
                                                       using: provider))
        }
        
        if let container = element as? ContainerElement {
            for child in container.childElements {
                commands.append(contentsOf: createCommands(for: child,
                                                           inheriting: state,
                                                           using: provider))
            }
        }
    
        if !transformCommands.isEmpty {
            commands.append(.popState)
        }
        
        if didBeginMask {
            commands.append(.popTransparencyLayer)
        }
        
        return commands
    }
    
    func createFillCommands<T: RendererTypeProvider>(for path: T.Path,
                                                     with state: State,
                                                     using provider: T) -> [RendererCommand<T>] {
        
        let fill = Builder.Color(state.fill)
        guard fill != .none else { return [] }
        let color = provider.createColor(from: fill)
        
        return [.setFill(color: color), .fill(path)]
    }
    
    func createStrokeCommands<T: RendererTypeProvider>(for path: T.Path,
                                                       with state: State,
                                                       using provider: T) -> [RendererCommand<T>] {
        
        let stroke = Builder.Color(state.stroke)
        guard stroke != .none else { return [] }
        let color = provider.createColor(from: stroke)
        let width = provider.createFloat(from: state.strokeWidth)
        
        return [.setLine(width: width) , .setStroke(color: color), .stroke(path)]
    }
    
    
    func createPath<T: RendererTypeProvider>(for element: DOM.GraphicsElement, with provider: T) -> T.Path? {
        if let line = element as? DOM.Line {
            let start = provider.createPoint(from: Point(line.x1, line.y1))
            let end = provider.createPoint(from: Point(line.x2, line.y2))
            
            return provider.createLine(from: start, to: end)
            
        } else if let circle = element as? DOM.Circle {
            
            let rect = Rect(x: circle.cx - circle.r,
                            y: circle.cy - circle.r,
                            width: circle.r*2,
                            height: circle.r*2)
            
            return provider.createEllipse(within: provider.createRect(from: rect))
            
        } else if let ellipse = element as? DOM.Ellipse {
            
            let rect = Rect(x: ellipse.cx - ellipse.rx,
                            y: ellipse.cy - ellipse.ry,
                            width: ellipse.rx*2,
                            height: ellipse.ry*2)
            
            return provider.createEllipse(within: provider.createRect(from: rect))
            
        } else if let r = element as? DOM.Rect {
            let rect = Rect(x: r.x ?? 0,
                            y: r.y ?? 0,
                            width: r.width,
                            height: r.height)
            
            let corner = Size(r.rx ?? 0, r.ry ?? 0)
            return provider.createRect(from: provider.createRect(from: rect),
                                       radii: corner)

        } else if let polyline = element as? DOM.Polyline {
            
            let p = polyline.points.map({ Point($0.x, $0.y)})
            let pp = p.map { provider.createPoint(from: $0) }
            return provider.createLine(between: pp)
            
        } else if let polygon = element as? DOM.Polygon {
            let p = polygon.points.map({ Point($0.x, $0.y)})
            let pp = p.map { provider.createPoint(from: $0) }
            return provider.createPolygon(between: pp)
            
        } else if let p = element as? DOM.Path,
                  let path = try? createPath(path: p) {
            
            return provider.createPath(from: path)
        }
        
        return nil
    }
    
       func createClipPath<T: RendererTypeProvider>(for clip: DOM.ClipPath, with provider: T) -> T.Path {
        
            var paths = Array<T.Path>()
        
            for element in clip.childElements {
                if let p = createPath(for: element, with: provider) {
                    paths.append(p)
                }
            }
    
            return provider.createPath(from: paths)
        }
    
    
}
