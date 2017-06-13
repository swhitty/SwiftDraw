//
//  LayerTree.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 3/6/17.
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

struct LayerTree {

    typealias Float = Swift.Float
    typealias LineCap = DOM.LineCap
    typealias LineJoin = DOM.LineJoin
    typealias FillRule = DOM.FillRule
    
    enum Error: Swift.Error {
        case unsupported(Any)
    }
    
    struct Point: Hashable {
        var x: Float
        var y: Float
        
        init(_ x: Float, _ y: Float) {
            self.x = x
            self.y = y
        }
        
        init(_ x: Int, _ y: Int) {
            self.x = Float(x)
            self.y = Float(y)
        }
        
        static var zero: Point {
            return Point(0, 0)
        }
        
        var hashValue: Int {
            return (21 &* x.hashValue) &+ (31 &* y.hashValue)
        }
        
        static func ==(lhs: Point, rhs: Point) -> Bool {
            return lhs.x == rhs.x && lhs.y == rhs.y
        }
    }
    
    struct Size: Equatable {
        var width: Float
        var height: Float
        
        init(_ width: Float, _ height: Float) {
            self.width = width
            self.height = height
        }
        
        init(_ width: Int, _ height: Int) {
            self.width = Float(width)
            self.height = Float(height)
        }
        
        static var zero: Size {
            return Size(0, 0)
        }
        
        static func ==(lhs: Size, rhs: Size) -> Bool {
            return lhs.width == rhs.width && lhs.height == rhs.height
        }
    }
    
    struct Rect: Equatable {
        var origin: Point
        var size: Size
        
        init(x: Float, y: Float, width: Float, height: Float) {
            self.origin = Point(x, y)
            self.size = Size(width, height)
        }
        
        init(x: Int, y: Int, width: Int, height: Int) {
            self.origin = Point(x, y)
            self.size = Size(width, height)
        }
        
        var x: Float {
            get { return origin.x }
            set { origin.x = newValue }
        }
        
        var y: Float {
            get { return origin.y }
            set { origin.y = newValue }
        }
        
        var width: Float {
            get { return size.width }
            set { size.width = newValue }
        }
        
        var height: Float {
            get { return size.height }
            set { size.height = newValue }
        }
        
        static var zero: Rect {
            return Rect(x: 0, y: 0, width: 0, height: 0)
        }
        
        static func ==(lhs: Rect, rhs: Rect) -> Bool {
            return lhs.origin == rhs.origin && lhs.size == rhs.size
        }
    }
    
    enum BlendMode {
        case normal
        case copy
        case sourceIn /* R = S*Da */
    }
}
