//
//  File.swift
//  SwiftVG
//
//  Created by Simon Whitty on 25/3/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

import Foundation
import AppKit

class ImageRenderer {
    
    class func svgNamed(_ name: String,
                        in bundle: Bundle = Bundle.main) -> DOM.Svg? {
        
        guard let url = bundle.url(forResource: name, withExtension: nil) else {
            return nil
        }
        
        return svgUrl(url)
    }
    
    class func svgUrl(_ url: URL) -> DOM.Svg? {
        guard let element = try? XML.SAXParser.parse(contentsOf: url),
            let svg = try? XMLParser().parseSvg(element) else {
                return nil
        }
        
        return svg
    }
    
    func draw(_ svg: DOM.Svg, in ctx: CGContext) {
        
        //flip context so 0,0 is top left
        let transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: CGFloat(svg.height))
        ctx.concatenate(transform)

        
        draw(svg as DOM.GraphicsElement, in: ctx)
    }
    

    
    
    func draw(_ element: DOM.GraphicsElement, in ctx: CGContext) {
        
        ctx.saveGState()
        
        if let fill = element.fill {
            ctx.setFillColor(cgColor(fill))
        }
        
        if let stroke = element.stroke {
            ctx.setStrokeColor(cgColor(stroke))
        }
        
        if let strokeWidth = element.strokeWidth {
            ctx.setLineWidth(CGFloat(strokeWidth))
        }
        
        if let transform = element.transform?.first {
            ctx.concatenate(cgTransform(transform))
        }
        if let path = element as? DOM.Path {
            draw(path, in: ctx)
        }
        
        if let container = element as? ContainerElement {
            for el in container.childElements {
                draw(el, in: ctx)
            }
        }
        
        
        ctx.restoreGState()
    }
    
    func draw(_ path: DOM.Path, in ctx: CGContext) {
        let p = cgPath(path)
        ctx.addPath(p)
        ctx.strokePath()
        ctx.fillPath()
    }
    
    
    func cgColor(_ color: DOM.Color) -> CGColor {
        switch(color){
        case .none:
            return CGColor(red: 0, green: 0, blue: 0, alpha: 0)
        case .keyword(let c):
            return cgColor(c.rgbi)
        case .rgbi(let c):
            return cgColor(c)
        case .hex(let c):
            return cgColor(c)
        case .rgbf(let r, let g, let b):
            return CGColor(red: CGFloat(r),
                           green: CGFloat(g),
                           blue: CGFloat(b), alpha: 1.0)
        }
    }
    
    func cgColor(keyword color: DOM.Color.Keyword) -> CGColor {
        return cgColor(color.rgbi)
    }
    
    func cgColor(_ rgbi: (UInt8, UInt8, UInt8)) -> CGColor {
            return CGColor(red: CGFloat(rgbi.0)/255.0,
                           green: CGFloat(rgbi.1)/255.0,
                           blue: CGFloat(rgbi.2)/255.0, alpha: 1.0)
    }
    
    func cgPath(_ path: DOM.Path) -> CGPath {
        guard let renderPath = try? CGRenderer().createPath(from: path) else {
            return CGMutablePath()
        }
        
        let pa = CGMutablePath()
        for s in renderPath.segments {
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
    
    func cgTransform(_ transform: DOM.Transform) -> CGAffineTransform {
        switch transform {
        case .translate(let tx, let ty):
            return CGAffineTransform(translationX: CGFloat(tx), y: CGFloat(ty))
        default:
            return .identity

        }
        
        
    }
    
}

