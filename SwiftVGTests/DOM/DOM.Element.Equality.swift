//
//  DOM.Equality.swift
//  SwiftVG
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright © 2016 WhileLoop Pty Ltd. All rights reserved.
//

@testable import SwiftVG


extension DOM {
    
    static func createLine() -> DOM.Line {
        return DOM.Line(x1: 0, y1: 1, x2: 3, y2: 4)
    }
    
    static func createCircle() -> DOM.Circle {
        return DOM.Circle(cx: 0, cy: 1, r: 2)
    }
    
    static func createEllipse() -> DOM.Ellipse {
        return DOM.Ellipse(cx: 0, cy: 1, rx: 2, ry: 3)
    }
    
    static func createRect() -> DOM.Rect {
        return DOM.Rect(x: 0, y: 1, width: 2, height: 3)
    }
    
    static func createPolygon() -> DOM.Polygon {
        return DOM.Polygon(0, 1, 2, 3, 4, 5)
    }
    
    static func createPolyline() -> DOM.Polyline {
        return DOM.Polyline(0, 1, 2, 3, 4, 5)
    }
    
    static func createText() -> DOM.Text {
        return DOM.Text(x: 0, y: 1, value: "The quick brown fox")
    }
    
    static func createPath() -> DOM.Path {
        let path = DOM.Path(x: 0, y: 1)
        path.move(x: 10, y: 10)
        path.horizontal(x: 20)
        return path
    }
    
    static func createGroup() -> DOM.Group {
        let group = DOM.Group()
        group.childElements.append(createLine())
        group.childElements.append(createPolygon())
        group.childElements.append(createCircle())
        group.childElements.append(createPath())
        group.childElements.append(createRect())
        group.childElements.append(createEllipse())
        return group
    }
}

// Equatable just for tests

extension DOM.GraphicsElement: Equatable {
    public static func ==(lhs: DOM.GraphicsElement, rhs: DOM.GraphicsElement) -> Bool {
        let toString: (Any) -> String = { var text = ""; dump($0, to: &text); return text }
        return toString(lhs) == toString(rhs)
    }
}

extension DOM.Polyline {
    // requires even number of elements
    convenience init(_ p: DOM.Coordinate...) {
        
        var points = Array<DOM.Point>()
        
        for index in stride(from: 0, to: points.count, by: 2) {
            points.append(DOM.Point(p[index], p[index + 1]))
        }
        
        self.init(points: points)
    }
}

extension DOM.Polygon {
    // requires even number of elements
    convenience init(_ p: DOM.Coordinate...) {
        
        var points = Array<DOM.Point>()
        
        for index in stride(from: 0, to: points.count, by: 2) {
            points.append(DOM.Point(p[index], p[index + 1]))
        }
        
        self.init(points: points)
    }
}

extension XML.Element {
    convenience init(_ name: String, style: String) {
        self.init(name: name, attributes: ["style": style])
    }
}
