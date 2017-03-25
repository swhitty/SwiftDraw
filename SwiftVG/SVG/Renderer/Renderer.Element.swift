//
//  Renderer.Element.swift
//  SwiftVG
//
//  Created by Simon Whitty on 25/3/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

import CoreGraphics

extension Renderer {
    
    func createPath(from element: DOM.GraphicsElement) -> Path? {
        if let line = element as? DOM.Line {
            return createPath(line: line)
        } else if let circle = element as? DOM.Circle {
            return createPath(circle: circle)
        } else if let ellipse = element as? DOM.Ellipse {
            return createPath(ellipse: ellipse)
        } else if let rect = element as? DOM.Rect {
            return createPath(rect: rect)
        } else if let polyline = element as? DOM.Polyline {
            return createPath(polyline: polyline)
        } else if let polygon = element as? DOM.Polygon {
            return createPath(polygon: polygon)
        } else if let path = element as? DOM.Path {
            return try? createPath(path: path)
        }
        
        return nil
    }

    func createPath(line: DOM.Line) -> Path {
        let p1 = CGPoint(line.x1, line.y1)
        let p2 = CGPoint(line.x2, line.y2)
        
        let path = Path()
        path.segments.append(.move(p1))
        path.segments.append(.line(p2))
        return path
    }
    
    func createPath(circle: DOM.Circle) -> Path {
        let x = CGFloat(circle.cx - circle.r)
        let y = CGFloat(circle.cy - circle.r)
        let width = CGFloat(circle.r*2)
      
        let cg = CGMutablePath()
        
        cg.addCurve(to: CGPoint.zero, control1: CGPoint(x: 1, y: 1), control2: CGPoint(x: 10, y: 10))
        
        return Path(cg)
       // cg.addEllipse(in: CGRect(x: x, y: y, width: width, height: width))
        
        return Path(cg)
    }
    
    func createPath(ellipse: DOM.Ellipse) -> Path {
        let x = CGFloat(ellipse.cx - ellipse.rx)
        let y = CGFloat(ellipse.cy - ellipse.ry)
        let width = CGFloat(ellipse.rx*2)
        let height = CGFloat(ellipse.ry*2)
        
        let r = CGRect(x: x, y: y, width: width, height: height)
        let cg = CGMutablePath()
        cg.addEllipse(in: r)
        return Path(cg)
    }
    
    func createPath(rect: DOM.Rect) -> Path {
        let r = CGRect(x: CGFloat(rect.x ?? 0),
                       y: CGFloat(rect.x ?? 0),
                       width: CGFloat(rect.width),
                       height: CGFloat(rect.height))
        
        let rx = CGFloat(rect.rx ?? 0)
        let ry = CGFloat(rect.ry ?? 0)

        let cg = CGMutablePath()
        cg.addRoundedRect(in: r, cornerWidth: rx, cornerHeight: ry)
        return Path(cg)
    }
    
    func createPath(polyline: DOM.Polyline) -> Path {
        
        let path = Path()
        
        for p in polyline.points {
            if path.segments.isEmpty {
                path.segments.append(.move(CGPoint(p.x, p.y)))
            } else {
               path.segments.append(.line(CGPoint(p.x, p.y)))
            }
        }
        
        return path
    }
    
    func createPath(polygon: DOM.Polygon) -> Path {
        let path = Path()
        
        for p in polygon.points {
            let point = CGPoint(p.x, p.y)
            
            if path.segments.isEmpty {
                path.segments.append(.move(point))
            } else {
                path.segments.append(.line(point))
            }
        }
        
        path.segments.append(.close)
        return path
    }
}

private extension CGPoint {
    init(_ x: DOM.Float, _ y: DOM.Float) {
        self.init(x: CGFloat(x), y: CGFloat(y))
    }
}
