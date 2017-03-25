//
//  Renderer.Command.swift
//  SwiftVG
//
//  Created by Simon Whitty on 25/3/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

import CoreGraphics


extension Renderer {
    
    enum Command {
        case pushState
        case popState
        
        case concatenate(transform: CGAffineTransform)
        case translate(dx: CGFloat, dy: CGFloat)
        
        case setFill(color: Color)
        case setStroke(color: Color)
        case setLine(width: CGFloat)
        
        case stroke(Path)
        case fill(Path)
    }
    
    func perform(_ commands: [Command], in ctx: CGContext) {
        for command in commands {
            perform(command, in: ctx)
        }
    }
    
    func perform(_ command: Command, in ctx: CGContext) {
    
        switch command {
        case .pushState: ctx.saveGState()
        case .popState: ctx.restoreGState()
            
        case .concatenate(let transform): ctx.concatenate(transform)
        case .translate(let dx, let dy): ctx.translateBy(x: dx, y: dy)
        
        case .setFill(color: let c): ctx.setFillColor(c.cgColor)
        case .setStroke(color: let c): ctx.setStrokeColor(c.cgColor)
        case .setLine(width: let w): ctx.setLineWidth(w)
            
        case .stroke(let path): perform(stroke: path, in: ctx)
        case .fill(let path): perform(fill: path, in: ctx)
        }
    }
    
    func perform(stroke path: Path, in ctx: CGContext) {
        let cgPath = createCGPath(from: path)
        ctx.addPath(cgPath)
        ctx.strokePath()
    }
    
    func perform(fill path: Path, in ctx: CGContext) {
        let cgPath = createCGPath(from: path)
        ctx.addPath(cgPath)
        ctx.fillPath(using: .evenOdd)
        //.winding
    }
    
    func createCGPath(from path: Path) -> CGPath {
        let pa = CGMutablePath()
        for s in path.segments {
            switch s {
            case .move(let p):
                pa.move(to: p)
            case .line(let p):
                pa.addLine(to: p)
            case .cubic(let p, let cp1, let cp2):
                pa.addCurve(to: p, control1: cp1, control2: cp2)
            case .close:
                pa.closeSubpath()
            }
        }
        return pa
    }
    
    
    func createCommands(from svg: DOM.Svg) -> [Command] {
        var commands = [Command]()
        let flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: CGFloat(svg.height))
        
        commands.append(.concatenate(transform: flip))
        commands.append(contentsOf: createCommands(from: svg as DOM.GraphicsElement))
        return commands
    }
    
    func createCommands(from element: DOM.GraphicsElement) -> [Command] {
        var commands = [Command]()
        
        commands.append(.pushState)
        
        if let fill = element.fill {
            commands.append(.setFill(color: createColor(from: fill)))
        }
        
        if let stroke = element.stroke {
            commands.append(.setStroke(color: createColor(from: stroke)))
        }
        
        if let strokeWidth = element.strokeWidth {
            commands.append(.setLine(width: CGFloat(strokeWidth)))
        }
        
        if let transform = element.transform?.first {
            if case .translate(let t) = transform {
                commands.append(.translate(dx: CGFloat(t.tx), dy: CGFloat(t.ty)))
            }
        }
        
        //convert the element into a path to draw
        if let path = createPath(from: element) {
            commands.append(.fill(path))
            commands.append(.stroke(path))
        }
        
        if let container = element as? ContainerElement {
            for child in container.childElements {
                commands.append(contentsOf: createCommands(from: child))
            }
        }
        
        commands.append(.popState)
        return commands
    }
}
