//
//  Builder.Path.swift
//  SwiftVG
//
//  Created by Simon Whitty on 26/3/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//


extension Builder {
    
    class Path {
        var segments: [Segment] = []
        
        enum Segment {
            case move(Point)
            case line(Point)
            case cubic(Point, Point, Point)
            case close
        }
    }
}

extension Builder.Point {
    func absolute(from base: Builder.Point) -> Builder.Point {
        return Builder.Point(base.x + x, base.y + y)
    }
}

extension Builder.Path.Segment: Equatable {
    static func ==(lhs: Builder.Path.Segment, rhs: Builder.Path.Segment) -> Bool {
        switch (lhs, rhs) {
        case (.move(let lVal), .move(let rVal)):
            return lVal == rVal
        case (.line(let lVal), .line(let rVal)):
            return lVal == rVal
        case (.cubic(let lVal), .cubic(let rVal)):
            return lVal == rVal
        case (.close, .close):
            return true
        default:
            return false
        }
    }
}

extension Builder.Path {
    
    typealias Point = Builder.Point
    
    var lastControl: Point? {
        guard let lastSegment = segments.last else { return nil }
        switch lastSegment {
        case .cubic(_, _, let p): return p
        default: return nil
        }
    }
    
    var last: Point? {
        
        guard let lastSegment = segments.last else { return nil }
        
        switch lastSegment {
        case .move(let p): return p
        case .line(let p): return p
        case .cubic(let p, _, _): return p
        case .close: return nil  //traverse segments
        }
    }
}

extension Builder {
    
    func createPath(path domPath: DOM.Path) throws -> Path {
        let path = Path()
        
        for s in domPath.segments {
            let segment = try createSegment(from: s,
                                            last: path.last ?? Point.zero,
                                            previous: path.lastControl)
            path.segments.append(segment)
        }
        
        return path
    }
    
    func createSegment(from segment: DOM.Path.Segment, last point: Point, previous control: Point?) throws -> Path.Segment {
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
    
    func createMove(from segment: DOM.Path.Segment, last point: Point) -> Path.Segment? {
        guard case .move(let m) = segment else { return nil }
        
        let p = Point(m.x, m.y)
        
        switch m.space {
        case .relative: return .move(p.absolute(from: point))
        case .absolute: return .move(p)
        }
    }
    
    func createLine(from segment: DOM.Path.Segment, last point: Point) -> Path.Segment? {
        guard case .line(let l) = segment else { return nil }
        
        let p = Point(l.x, l.y)
        
        switch l.space {
        case .relative: return .line(p.absolute(from: point))
        case .absolute: return .line(p)
        }
    }
    
    func createHorizontal(from segment: DOM.Path.Segment, last point: Point) -> Path.Segment? {
        guard case .horizontal(let h) = segment else { return nil }
        
        switch h.space {
        case .relative: return .line(Point(h.x + point.x , point.y))
        case .absolute: return .line(Point(h.x, point.y))
        }
    }
    
    func createVertical(from segment: DOM.Path.Segment, last point: Point) -> Path.Segment? {
        guard case .vertical(let v) = segment else { return nil }
        
        switch v.space {
        case .relative: return .line(Point(point.x , v.y + point.y))
        case .absolute: return .line(Point(point.x, v.y))
        }
    }
    
    func createCubic(from segment: DOM.Path.Segment, last point: Point) -> Path.Segment? {
        guard case .cubic(let c) = segment else { return nil }
        
        let p = Point(c.x, c.y)
        let cp1 = Point(c.x1, c.y1)
        let cp2 = Point(c.x2, c.y2)
        
        switch c.space {
        case .relative: return .cubic(p.absolute(from: point),
                                      cp1.absolute(from: point),
                                      cp2.absolute(from: point))
        case .absolute: return .cubic(p, cp1, cp2)
        }
    }
    
    func createCubicSmooth(from segment: DOM.Path.Segment, last point: Point, previous control: Point) -> Path.Segment? {
        guard case .cubicSmooth(let c) = segment else { return nil }
        
        let delta = Point(point.x - control.x,
                          point.y - control.y)
        
        let p = Point(c.x, c.y)
        let cp1 = Point(point.x + delta.x,
                        point.y + delta.y)
        let cp2 = Point(c.x2, c.y2)
        
        switch c.space {
        case .relative: return .cubic(p.absolute(from: point),
                                      cp1,
                                      cp2.absolute(from: point))
        case .absolute: return .cubic(p, cp1, cp2)
        }
    }
    
    func createQuadratic(from segment: DOM.Path.Segment, last point: Point) -> Path.Segment? {
        guard case .quadratic(let q) = segment else { return nil }
        
        var p = Point(q.x, q.y)
        var cp1 = Point(q.x1, q.y1)
        
        if q.space == .relative {
            p = p.absolute(from: point)
            cp1 = cp1.absolute(from: point)
        }
        
        return createCubic(from: point, to: p, quadratic: cp1)
    }
    
    func createCubic(from origin: Point, to final: Point, quadratic controlPoint: Point) -> Path.Segment {
        //Approximate a quadratic curve using cubic curve.
        //Converting the quadratic control point into 2 cubic control points
        
        let ratio = Float(2.0/3.0)
        
        let cp1 = Point(origin.x + (controlPoint.x - origin.x) * ratio,
                        origin.y + (controlPoint.y - origin.y) * ratio)
        
        
        let cpX = (final.x - origin.x)*Float(1.0/3.0)
        
        let cp2 = Point(cp1.x + cpX,
                        cp1.y)
        
        return .cubic(final, cp1, cp2)
    }
    
    func createQuadraticSmooth(from segment: DOM.Path.Segment, last point: Point, previous control: Point) -> Path.Segment? {
        guard case .quadraticSmooth(let q) = segment else { return nil }
        
        let delta = Point(point.x - control.x,
                          point.y - control.y)
        
        let cp1 = Point(point.x + delta.x,
                        point.y + delta.y)
        
        let final = q.space == .absolute ? Point(q.x, q.y) : Point(q.x, q.y).absolute(from: point)
        let cpX = (final.x - point.x)*Float(1.0/3.0)
        let cp2 = Point(cp1.x + cpX,
                        cp1.y)
        
        return .cubic(final, cp1, cp2)
    }
    
    func createArc(from segment: DOM.Path.Segment, last point: Point) -> Path.Segment? {
        //guard case .arc(let a) = segment else { return nil }
        return nil;
    }
    
    func createClose(from segment: DOM.Path.Segment) -> Path.Segment? {
        guard case .close = segment else { return nil }
        return .close
    }
}

