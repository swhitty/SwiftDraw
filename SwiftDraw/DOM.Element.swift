//
//  DOM.Element.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright 2020 Simon Whitty
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

protocol ContainerElement {
    var childElements: [DOM.GraphicsElement] { get set }
}

protocol ElementAttributes {
    var id: String?  { get set }
    var `class`: String?  { get set }
}

extension DOM {
    
    class Element {}
    
    class GraphicsElement: Element, ElementAttributes, @unchecked Sendable {
        var id: String?
        var `class`: String?
        
        var attributes = PresentationAttributes()
        var style = PresentationAttributes()
    }
    
    final class Line: GraphicsElement, @unchecked Sendable {
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
    
    final class Circle: GraphicsElement, @unchecked Sendable {
        var cx: Coordinate?
        var cy: Coordinate?
        var r: Coordinate
        
        init(cx: Coordinate?, cy: Coordinate?, r: Coordinate) {
            self.cx = cx
            self.cy = cy
            self.r = r
            super.init()
        }
    }
    
    final class Ellipse: GraphicsElement, @unchecked Sendable {
        var cx: Coordinate?
        var cy: Coordinate?
        var rx: Coordinate
        var ry: Coordinate
        
        init(cx: Coordinate?, cy: Coordinate?, rx: Coordinate, ry: Coordinate) {
            self.cx = cx
            self.cy = cy
            self.rx = rx
            self.ry = ry
            super.init()
        }
    }
    
    final class Rect: GraphicsElement, @unchecked Sendable {
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
    
    final class Polyline: GraphicsElement, @unchecked Sendable {
        var points: [Point]
        
        init(points: [Point]) {
            self.points = points
            super.init()
        }
    }
    
    final class Polygon: GraphicsElement, @unchecked Sendable {
        var points: [Point]
        
        init(points: [Point]) {
            self.points = points
            super.init()
        }
    }
    
    final class Group: GraphicsElement, ContainerElement, @unchecked Sendable {
        var childElements = [GraphicsElement]()
    }
}
