//
//  CGRenderer.Path.swift
//  SwiftVG
//
//  Created by Simon Whitty on 10/3/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

import CoreGraphics

extension CGRenderer {
    class Path {
        var segments: [Segment] = []
        
        enum Segment {
            case move(CGPoint)
            case line(CGPoint)
            case cubic(CGPoint, CGPoint, CGPoint)
            case close
        }
    }
}


extension CGRenderer.Path {

    var lastControl: CGPoint? {
        guard let lastSegment = segments.last else { return nil }
        switch lastSegment {
        case .cubic(_, _, let p): return p
        default: return nil
        }
    }
    
    var last: CGPoint? {
        
        guard let lastSegment = segments.last else { return nil }
        
        switch lastSegment {
        case .move(let p): return p
        case .line(let p): return p
        case .cubic(let p, _, _): return p
        case .close: return nil  //traverse segments
        }
        
    }
    
}

extension CGRenderer {

    func createPath(from path: DOM.Path) throws -> Path {
        let cgpath = Path()
        
        for s in path.segments {
            let segment = try createSegment(from: s,
                                            last: cgpath.last ?? CGPoint.zero,
                                            previous: cgpath.lastControl)
            cgpath.segments.append(segment)
        }

        return cgpath
    }
    
    func createSegment(from segment: DOM.Path.Segment, last point: CGPoint, previous control: CGPoint?) throws -> Path.Segment {
        if let s = createMove(from: segment, last: point) {
            return s
        } else if let s = createLine(from: segment, last: point) {
            return s
        } else if let s = createHorizontal(from: segment, last: point) {
            return s
        } else if let s = createVertical(from: segment, last: point) {
            return s
        } else if let s = createCubic(from: segment, last: point) {
            return s
        } else if let s = createCubicSmooth(from: segment, last: point, previous: control ?? point) {
            return s
        } else if let s = createQuadratic(from: segment, last: point) {
            return s
        } else if let s = createQuadraticSmooth(from: segment, last: point, previous: control ?? point) {
            return s
        } else if let s = createArc(from: segment, last: point) {
            return s
        } else if let s = createClose(from: segment) {
            return s
        }
    
        throw Error.unsupported(segment)
    }
    
    func createMove(from segment: DOM.Path.Segment, last point: CGPoint) -> Path.Segment? {
        guard case .move(let m) = segment else { return nil }
        
        let p = CGPoint(m.x, m.y)
        
        switch m.space {
        case .relative: return .move(p.absolute(from: point))
        case .absolute: return .move(p)
        }
    }
    
    func createLine(from segment: DOM.Path.Segment, last point: CGPoint) -> Path.Segment? {
        guard case .line(let l) = segment else { return nil }
        
        let p = CGPoint(l.x, l.y)
        
        switch l.space {
        case .relative: return .line(p.absolute(from: point))
        case .absolute: return .line(p)
        }
    }
    
    func createHorizontal(from segment: DOM.Path.Segment, last point: CGPoint) -> Path.Segment? {
        guard case .horizontal(let h) = segment else { return nil }
        
        switch h.space {
        case .relative: return .line(CGPoint(CGFloat(h.x) + point.x , point.y))
        case .absolute: return .line(CGPoint(h.x, point.y))
        }
    }
    
    func createVertical(from segment: DOM.Path.Segment, last point: CGPoint) -> Path.Segment? {
        guard case .vertical(let v) = segment else { return nil }
        
        switch v.space {
        case .relative: return .line(CGPoint(point.x , CGFloat(v.y) + point.y))
        case .absolute: return .line(CGPoint(point.x, v.y))
        }
    }
    
    func createCubic(from segment: DOM.Path.Segment, last point: CGPoint) -> Path.Segment? {
        guard case .cubic(let c) = segment else { return nil }
        
        let p = CGPoint(c.x, c.y)
        let cp1 = CGPoint(c.x1, c.y1)
        let cp2 = CGPoint(c.x2, c.y2)
        
        switch c.space {
        case .relative: return .cubic(p.absolute(from: point),
                                      cp1.absolute(from: point),
                                      cp2.absolute(from: point))
        case .absolute: return .cubic(p, cp1, cp2)
        }
    }
    
    func createCubicSmooth(from segment: DOM.Path.Segment, last point: CGPoint, previous control: CGPoint) -> Path.Segment? {
        guard case .cubicSmooth(let c) = segment else { return nil }
        
        let delta = CGPoint(x: point.x - control.x,
                            y: point.y - control.y)
        
        let p = CGPoint(c.x, c.y)
        let cp1 = CGPoint(x: point.x + delta.x,
                          y: point.y + delta.y)
        let cp2 = CGPoint(c.x2, c.y2)
        
        switch c.space {
        case .relative: return .cubic(p.absolute(from: point),
                                      cp1,
                                      cp2.absolute(from: point))
        case .absolute: return .cubic(p, cp1, cp2)
        }
    }
    
    func createQuadratic(from segment: DOM.Path.Segment, last point: CGPoint) -> Path.Segment? {
        guard case .quadratic(let q) = segment else { return nil }
        
        var p = CGPoint(q.x, q.y)
        var cp1 = CGPoint(q.x1, q.y1)
        
        if q.space == .relative {
            p = p.absolute(from: point)
            cp1 = cp1.absolute(from: point)
        }
        
        return createCubic(from: point, to: p, quadratic: cp1)
    }
    
    func createCubic(from origin: CGPoint, to final: CGPoint, quadratic controlPoint: CGPoint) -> Path.Segment? {
        //Approximate a quadratic curve using cubic curve.
        //Converting the quadratic control point into 2 cubic control points
        
        let ratio = CGFloat(2.0/3.0)
        
        
        let cp1 = CGPoint(x: origin.x + (controlPoint.x - origin.x) * ratio,
                          y: origin.y + (controlPoint.y - origin.y) * ratio)
        
        
        let cpX = (final.x - origin.x)*CGFloat(1.0/3.0)
        
        let cp2 = CGPoint(x: cp1.x + cpX,
                          y: cp1.y)
    
        return .cubic(final, cp1, cp2)
    }
    
    func createQuadraticSmooth(from segment: DOM.Path.Segment, last point: CGPoint, previous control: CGPoint) -> Path.Segment? {
        guard case .quadraticSmooth(let q) = segment else { return nil }
        
        let delta = CGPoint(x: point.x - control.x,
                            y: point.y - control.y)
        
        let cp1 = CGPoint(x: point.x + delta.x,
                         y: point.y + delta.y)
        
        let final = q.space == .absolute ? CGPoint(q.x, q.y) : CGPoint(q.x, q.y).absolute(from: point)
        let cpX = (final.x - point.x)*CGFloat(1.0/3.0)
        let cp2 = CGPoint(x: cp1.x + cpX,
                          y: cp1.y)
            
        return .cubic(final, cp1, cp2)
    }
    
    func createArc(from segment: DOM.Path.Segment, last point: CGPoint) -> Path.Segment? {
        //guard case .arc(let a) = segment else { return nil }
        return nil;
    }
    
    func createClose(from segment: DOM.Path.Segment) -> Path.Segment? {
        guard case .close = segment else { return nil }
        return .close
    }
}


private extension CGPoint {
    init(_ x: DOM.Float, _ y: DOM.Float) {
        self.init(x: CGFloat(x), y: CGFloat(y))
    }
    init(_ x: CGFloat, _ y: DOM.Float) {
        self.init(x: x, y: CGFloat(y))
    }
    init(_ x: DOM.Float, _ y: CGFloat) {
        self.init(x: CGFloat(x), y: y)
    }
    init(_ x: CGFloat, _ y: CGFloat) {
        self.init(x: x, y: y)
    }
    
    func absolute(from base: CGPoint) -> CGPoint {
        return CGPoint(x: base.x + x, y: base.y + y)
    }
}
