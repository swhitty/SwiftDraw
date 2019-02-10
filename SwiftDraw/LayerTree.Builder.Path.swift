//
//  LayerTree.Builder.Path.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 4/6/17.
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

//converts DOM.Path -> LayerTree.Path

extension LayerTree.Builder {
    
    typealias Path = LayerTree.Path
    typealias Point = LayerTree.Point

    static func createPath(from element: DOM.Path) throws -> LayerTree.Path {
        let path = Path()
        
        for s in element.segments {
            let segment = try createSegment(from: s,
                                            last: path.last ?? Point.zero,
                                            previous: path.lastControl)
            path.segments.append(segment)
        }
        
        return path
    }
    
    static func createSegment(from segment: DOM.Path.Segment, last point: Point, previous control: Point?) throws -> Path.Segment {
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
        
        throw LayerTree.Error.unsupported(segment)
    }
    
    static func createMove(from segment: DOM.Path.Segment, last point: Point) -> Path.Segment? {
        guard case .move(to: let m) = segment else { return nil }
        
        let p = Point(m.x, m.y)
        
        switch m.space {
        case .relative: return .move(to: p.absolute(from: point))
        case .absolute: return .move(to: p)
        }
    }
    
    static func createLine(from segment: DOM.Path.Segment, last point: Point) -> Path.Segment? {
        guard case .line(let l) = segment else { return nil }
        
        let p = Point(l.x, l.y)
        
        switch l.space {
        case .relative: return .line(to: p.absolute(from: point))
        case .absolute: return .line(to: p)
        }
    }
    
    static func createHorizontal(from segment: DOM.Path.Segment, last point: Point) -> Path.Segment? {
        guard case .horizontal(let h) = segment else { return nil }
        
        switch h.space {
        case .relative: return .line(to: Point(h.x + point.x , point.y))
        case .absolute: return .line(to: Point(h.x, point.y))
        }
    }
    
    static func createVertical(from segment: DOM.Path.Segment, last point: Point) -> Path.Segment? {
        guard case .vertical(let v) = segment else { return nil }
        
        switch v.space {
        case .relative: return .line(to: Point(point.x , v.y + point.y))
        case .absolute: return .line(to: Point(point.x, v.y))
        }
    }
    
    static func createCubic(from segment: DOM.Path.Segment, last point: Point) -> Path.Segment? {
        guard case .cubic(let c) = segment else { return nil }
        
        let p = Point(c.x, c.y)
        let cp1 = Point(c.x1, c.y1)
        let cp2 = Point(c.x2, c.y2)
        
        switch c.space {
        case .relative: return .cubic(to: p.absolute(from: point),
                                      control1: cp1.absolute(from: point),
                                      control2: cp2.absolute(from: point))
        case .absolute: return .cubic(to: p, control1: cp1, control2: cp2)
        }
    }
    
    static func createCubicSmooth(from segment: DOM.Path.Segment, last point: Point, previous control: Point) -> Path.Segment? {
        guard case .cubicSmooth(let c) = segment else { return nil }
        
        let delta = Point(point.x - control.x,
                          point.y - control.y)
        
        let p = Point(c.x, c.y)
        let cp1 = Point(point.x + delta.x,
                        point.y + delta.y)
        let cp2 = Point(c.x2, c.y2)
        
        switch c.space {
        case .relative: return .cubic(to: p.absolute(from: point),
                                      control1: cp1,
                                      control2: cp2.absolute(from: point))
        case .absolute: return .cubic(to: p, control1: cp1, control2: cp2)
        }
    }
    
    static func createQuadratic(from segment: DOM.Path.Segment, last point: Point) -> Path.Segment? {
        guard case .quadratic(let q) = segment else { return nil }
        
        var p = Point(q.x, q.y)
        var cp1 = Point(q.x1, q.y1)
        
        if q.space == .relative {
            p = p.absolute(from: point)
            cp1 = cp1.absolute(from: point)
        }
        
        return createCubic(from: point, to: p, quadratic: cp1)
    }
    
    static func createCubic(from origin: Point, to final: Point, quadratic controlPoint: Point) -> Path.Segment {
        //Approximate a quadratic curve using cubic curve.
        //Converting the quadratic control point into 2 cubic control points
        
        let ratio = Float(2.0/3.0)
        
        let cp1 = Point(origin.x + (controlPoint.x - origin.x) * ratio,
                        origin.y + (controlPoint.y - origin.y) * ratio)
        
        
        let cpX = (final.x - origin.x)*Float(1.0/3.0)
        
        let cp2 = Point(cp1.x + cpX,
                        cp1.y)
        
        return .cubic(to: final, control1: cp1, control2: cp2)
    }
    
    static func createQuadraticSmooth(from segment: DOM.Path.Segment, last point: Point, previous control: Point) -> Path.Segment? {
        guard case .quadraticSmooth(let q) = segment else { return nil }
        
        let delta = Point(point.x - control.x,
                          point.y - control.y)
        
        let cp1 = Point(point.x + delta.x,
                        point.y + delta.y)
        
        let final = q.space == .absolute ? Point(q.x, q.y) : Point(q.x, q.y).absolute(from: point)
        let cpX = (final.x - point.x)*Float(1.0/3.0)
        let cp2 = Point(cp1.x + cpX,
                        cp1.y)
        
        return .cubic(to: final, control1: cp1, control2: cp2)
    }
    
    static func createArc(from segment: DOM.Path.Segment, last point: Point) -> Path.Segment? {
        guard case .arc(let a) = segment else { return nil }

        //arc is currently unsupported so we simply create a line to the destination without any arc.
        let p = Point(a.x, a.y)

        switch a.space {
        case .relative: return .line(to: p.absolute(from: point))
        case .absolute: return .line(to: p)
        }
    }
    
    static func createClose(from segment: DOM.Path.Segment) -> Path.Segment? {
        guard case .close = segment else { return nil }
        return .close
    }
    
}

extension LayerTree.Point {
    func absolute(from base: LayerTree.Point) -> LayerTree.Point {
        return LayerTree.Point(base.x + x, base.y + y)
    }
}

extension LayerTree.Path {
    var lastControl: LayerTree.Point? {
        guard let lastSegment = segments.last else { return nil }
        switch lastSegment {
        case .cubic(_, _, let p): return p
        default: return nil
        }
    }
    
    var last: LayerTree.Point? {
        guard let last = segments.last?.last else {
            return lastStart
        }

        return last
    }

    var lastStart: LayerTree.Point? {
        let rev = segments.reversed()
        guard
            let closeIdx = rev.index(where: { $0.isClose }),
            closeIdx != rev.startIndex else {
                return segments.first?.last
        }

        let point = rev.index(before: closeIdx)
        return rev[point].last
    }
}

private extension LayerTree.Path.Segment {

    var isClose: Bool {
        guard case .close = self else {
            return false
        }
        return true
    }

    var last: LayerTree.Point? {
        switch self {
        case .move(to: let p): return p
        case .line(let p): return p
        case .cubic(let p, _, _): return p
        case .close: return nil
        }
    }
}
