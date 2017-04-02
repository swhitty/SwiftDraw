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
        
        self.defs = svg.defs
        var commands = [RendererCommand<T>]()
        let flip = Transform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: Float(svg.height))
        let t = provider.createTransform(from: flip)
        commands.append(.concatenate(transform: t))
        
        let state = createState(for: svg, with:  RendererState.defaultSvg)
        
        commands.append(contentsOf: createCommands(for: state, existing: nil, with: provider))
        
        commands.append(contentsOf: createCommands(for: svg as DOM.GraphicsElement,
                                                   with: provider,
                                                   domState: svg,
                                                   renderState: state))
        return commands
    }
    
    func createCommands<T: RendererTypeProvider>(for element: DOM.GraphicsElement,
                                                 with provider: T,
                                                 domState: PresentationAttributes,
                                                 renderState: RendererState) -> [RendererCommand<T>] {
        
        var commands = [RendererCommand<T>]()

        let newAtrributes = createAttributes(for: element, inheriting: domState)
        let newState = createState(for: newAtrributes, with: renderState)
        
        let stateCommands = createCommands(for: newState, existing: renderState, with: provider)
        if !stateCommands.isEmpty {
            commands.append(.pushState)
            commands.append(contentsOf: stateCommands)
        }
        
        if let transforms = element.transform {
            let cmds = createCommands(from: transforms, with: provider)
            commands.append(contentsOf: cmds)
        }
        
        //clip if required
        if let clipId = element.clipPath?.fragment,
           let clip = defs.clipPaths.first(where: { $0.id == clipId }) {
            let path = createClipPath(for: clip, with: provider)
            commands.append(.setClip(path: path))
        }
        
        //convert the element into a path to draw
        if let path = createPath(for: element, with: provider) {
            if newState.fillColor != .none {
                commands.append(.fill(path))
            }
            
            if newState.strokeColor != .none {
                commands.append(.stroke(path))
            }
        }
        
        //if element is <use>, then retrieve elemnt from defs
        if let use = element as? DOM.Use,
           let eId = use.href.fragment,
           let e = defs.elements[eId] {
    
            commands.append(contentsOf: createCommands(for: e,
                                                       with: provider,
                                                       domState: element,
                                                       renderState: newState))
            
        }
        
        if let container = element as? ContainerElement {
            for child in container.childElements {
                commands.append(contentsOf: createCommands(for: child,
                                                           with: provider,
                                                           domState: element,
                                                           renderState: newState))
            }
        }
        
        if !stateCommands.isEmpty {
            commands.append(.popState)
        }
        
        return commands
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
