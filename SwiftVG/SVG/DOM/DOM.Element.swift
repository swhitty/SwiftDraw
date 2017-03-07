//
//  DOM.Element.swift
//  SwiftVG
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright © 2016 WhileLoop Pty Ltd. All rights reserved.
//

import Foundation

protocol ContainerElement {
    var childElements: Array<DOM.GraphicsElement> { get set }
}

protocol PresentationAttributes {
    var opacity: DOM.Float?  { get set }
    var display: DOM.DisplayMode?  { get set }
    
    var stroke: DOM.Color?  { get set }
    var strokeWidth: DOM.Float?  { get set }
    var strokeOpacity: DOM.Float?  { get set }
    var strokeLineCap: DOM.LineCap?  { get set }
    var strokeLineJoin: DOM.LineJoin?  { get set }
    var strokeDashArray: [DOM.Float]?  { get set }
    
    var fill: DOM.Color?  { get set }
    var fillOpacity: DOM.Float?  { get set }
    var fillRule: DOM.FillRule?  { get set }
    
    var transform: [DOM.Transform]?  { get set }
    var clipPath: URL?  { get set }
    var mask: URL?  { get set }
}

extension DOM {
    class Element {}
    
    class GraphicsElement: Element, PresentationAttributes {
        var id: String?
        
        var opacity: DOM.Float?
        var display: DOM.DisplayMode?
        
        var stroke: DOM.Color?
        var strokeWidth: DOM.Float?
        var strokeOpacity: DOM.Float?
        var strokeLineCap: DOM.LineCap?
        var strokeLineJoin: DOM.LineJoin?
        var strokeDashArray: [DOM.Float]?
        
        var fill: DOM.Color?
        var fillOpacity: DOM.Float?
        var fillRule: DOM.FillRule?
        
        var transform: [DOM.Transform]?
        var clipPath: URL?
        var mask: URL?
    }
    
    class Line: GraphicsElement {
        var x1: Coordinate
        var y1: Coordinate
        var x2: Coordinate
        var y2: Coordinate
        
        init(x1: Coordinate, y1: Coordinate, x2: Coordinate, y2: Coordinate) {
            self.x1 = x1
            self.y1 = y1
            self.x2 = x2
            self.y2 = y2
            super.init()
        }
    }
    
    class Circle: GraphicsElement {
        var cx: Coordinate
        var cy: Coordinate
        var r: Coordinate
        
        init(cx: Coordinate, cy: Coordinate, r: Coordinate) {
            self.cx = cx
            self.cy = cy
            self.r = r
            super.init()
        }
    }
    
    class Ellipse: GraphicsElement {
        var cx: Coordinate
        var cy: Coordinate
        var rx: Coordinate
        var ry: Coordinate
        
        init(cx: Coordinate, cy: Coordinate, rx: Coordinate, ry: Coordinate) {
            self.cx = cx
            self.cy = cy
            self.rx = rx
            self.ry = ry
            super.init()
        }
    }
    
    class Rect: GraphicsElement {
        var x: Coordinate?
        var y: Coordinate?
        var width: Coordinate
        var height: Coordinate
        
        var rx: Coordinate?
        var ry: Coordinate?
        
        init(x: Coordinate? = nil, y: Coordinate? = nil, width: Coordinate, height: Coordinate) {
            self.x = x
            self.y = y
            self.width = width
            self.height = height
            super.init()
        }
    }
    
    class Polyline: GraphicsElement {
        var points: [Point]
        
        init(points: [Point]) {
            self.points = points
            super.init()
        }
    }
    
    class Polygon: GraphicsElement {
        var points: [Point]
        
        init(points: [Point]) {
            self.points = points
            super.init()
        }
    }
    
    class Group: GraphicsElement, ContainerElement {
        var childElements = [GraphicsElement]()
    }
}
