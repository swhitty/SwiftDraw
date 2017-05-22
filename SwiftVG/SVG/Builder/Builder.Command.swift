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
        
        //TODO: merge Use and Switch element resolution.
        if let use = element as? DOM.Use {
            
            let transformCommands = createTransformCommands(from: element.transform ?? [], using: provider)
            
            if !transformCommands.isEmpty {
                commands.append(.pushState)
                commands.append(contentsOf: transformCommands)
            }
            
            let cmds = createUseCommands(for: use, inheriting: parentState, using: provider)
            commands.append(contentsOf: cmds)
            
            if !transformCommands.isEmpty {
                commands.append(.popState)
            }
        } else if let sw = element as? DOM.Switch {
            
            //TODO: handle first element that can be rendered.
            if let el = sw.childElements.first {
                let transformCommands = createTransformCommands(from: element.transform ?? [], using: provider)
                
                if !transformCommands.isEmpty {
                    commands.append(.pushState)
                    commands.append(contentsOf: transformCommands)
                }
                
                //ensure render state is inherited from Switch element
                let swState = createState(for: sw, inheriting: parentState)
                let cmds = createDrawCommands(for: el, inheriting: swState, using: provider)
                commands.append(contentsOf: cmds)
                
                if !transformCommands.isEmpty {
                    commands.append(.popState)
                }
            }
        }
        else {
            let cmds = createDrawCommands(for: element, inheriting: parentState, using: provider)
            commands.append(contentsOf: cmds)
    
            
            
        }
        
        return commands
    }
        
    func createUseCommands<T: RendererTypeProvider>(for use: DOM.Use,
                        inheriting parentState: State,
                        using provider: T) -> [RendererCommand<T>] {
        
        guard let eId = use.href.fragment,
              let e = defs.elements[eId] else {
                //cannot render
            return []
        }
        
        //ensure linked element inherits attributes from <use> element
        let state = createState(for: use, inheriting: parentState)
        return createDrawCommands(for: e, inheriting: state, using: provider)
    }

    func createDrawCommands<T: RendererTypeProvider>(for element: DOM.GraphicsElement,
                                                     inheriting parentState: State,
                                                     using provider: T) -> [RendererCommand<T>] {
        
        var commands = [RendererCommand<T>]()
        
        let transformCommands = createTransformCommands(from: element.transform ?? [], using: provider)
        let clipCommands = createClipCommands(for: element, using: provider)
        let maskCommands = createMaskCommands(for: element, using: provider)
        
        commands.append(contentsOf: maskCommands)
        
        if !transformCommands.isEmpty ||
           !clipCommands.isEmpty {
            commands.append(.pushState)
        }
        
        commands.append(contentsOf: transformCommands)
        commands.append(contentsOf: clipCommands)

    
        //inherit the attributes from the parent element,
        //but override with any attributes explictly set with the current element
        let state = createState(for: element, inheriting: parentState)
        
        //convert the element into a path to fill, then stroke if required
        if let path = createPath(for: element, with: provider) {
            commands.append(contentsOf: createFillCommands(for: path, with: state, using: provider))
            commands.append(contentsOf: createStrokeCommands(for: path, with: state, using: provider))
        }
        
        if let container = element as? ContainerElement {
            for child in container.childElements {
                commands.append(contentsOf: createCommands(for: child,
                                                           inheriting: state,
                                                           using: provider))
            }
        }
        
        if !transformCommands.isEmpty ||
            !clipCommands.isEmpty {
            commands.append(.popState)
        }
        
        if !maskCommands.isEmpty {
            commands.append(.popTransparencyLayer)
        }
        
        return commands
    }
    
    func createClipCommands<T: RendererTypeProvider>(for element: DOM.GraphicsElement,
                                                     using provider: T) -> [RendererCommand<T>] {
        guard let clipId = element.clipPath?.fragment,
              let clip = defs.clipPaths.first(where: { $0.id == clipId }) else { return [] }
   
        
        var paths = Array<T.Path>()
        for el in clip.childElements {
            if let p = createPath(for: el, with: provider) {
                paths.append(p)
            }
        }
        let clipPath = provider.createPath(from: paths)
        return [.setClip(path: clipPath)]
    }
    
    func createMaskCommands<T: RendererTypeProvider>(for element: DOM.GraphicsElement,
                                                     using provider: T) -> [RendererCommand<T>] {
        
        guard let maskId = element.mask?.fragment,
              let mask = defs.masks.first(where: { $0.id == maskId }) else { return [] }
        
        var commands = [RendererCommand<T>]()
        commands.append(.pushTransparencyLayer)
        commands.append(.pushState)
        if let t = element.transform {
            //apply the same transform to mask as the original element
            commands.append(contentsOf: createTransformCommands(from: t, using: provider))
        }
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
        
        return commands
    }
    
    func createFillCommands<T: RendererTypeProvider>(for path: T.Path,
                                                     with state: State,
                                                     using provider: T) -> [RendererCommand<T>] {
        
        let fill = Builder.Color(state.fill).withAlpha(state.fillOpacity)
 
        guard fill != .none else { return [] }
        let color = provider.createColor(from: fill)
        
        return [.setFill(color: color), .fill(path)]
    }
    
    func createStrokeCommands<T: RendererTypeProvider>(for path: T.Path,
                                                       with state: State,
                                                       using provider: T) -> [RendererCommand<T>] {
        
        let stroke = Builder.Color(state.stroke).withAlpha(state.strokeOpacity)
        guard stroke != .none else { return [] }
        let color = provider.createColor(from: stroke)
        let width = provider.createFloat(from: state.strokeWidth)
        let cap = provider.createLineCap(from: state.strokeLineCap)
        let join = provider.createLineJoin(from: state.strokeLineJoin)
        let limit = provider.createFloat(from: state.strokeLineMiterLimit)
        
        return [.setLineCap(cap),
                .setLineJoin(join),
                .setLine(width: width),
                .setLineMiter(limit: limit),
                .setStroke(color: color),
                .stroke(path)]
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
