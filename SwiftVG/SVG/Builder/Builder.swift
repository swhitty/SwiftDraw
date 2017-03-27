//
//  Builder.swift
//  SwiftVG
//
//  Created by Simon Whitty on 26/3/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

import Foundation

class Builder {
    
    typealias Float = Swift.Float
  
    enum Error: Swift.Error {
        case unsupported(Any)
    }
    
    enum Color: Equatable {
        case none
        case rgba(r: Float, g: Float, b: Float, a: Float)
        
        static func ==(lhs: Color, rhs: Color) -> Bool {
            switch (lhs, rhs) {
            case (.none, .none):
                return true
            case (.rgba(let lVal), .rgba(let rVal)):
                return lVal == rVal
            default:
                return false
            }
        }
        
        func withMultiplyingAlpha(_ alpha: Float) -> Color {
            
            switch self {
            case .none:
                return .none
            case .rgba(r: let r, g: let g, b: let b, a: let a):
                let newAlpha = a * alpha
                if newAlpha > 0 {
                    return .rgba(r: r,
                                 g: g,
                                 b: b,
                                 a: newAlpha)
                } else {
                    return .none
                }
            }
        }
    }
    
    struct Point: Equatable {
        var x: Float
        var y: Float
        
        init(_ x: Float, _ y: Float) {
            self.x = x
            self.y = y
        }
        
        static var zero: Point {
            return Point(0, 0)
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
        
        static func ==(lhs: Rect, rhs: Rect) -> Bool {
            return lhs.origin == rhs.origin && lhs.size == rhs.size
        }
    }
    
    struct Transform: Equatable {
        var a: Float
        var b: Float
        var c: Float
        var d: Float
        var tx: Float
        var ty: Float
        
        init() {
            self.a = 0
            self.b = 0
            self.c = 0
            self.d = 0
            self.tx = 0
            self.ty = 0
        }
        
        init(a: Float, b: Float, c: Float, d: Float, tx: Float, ty: Float) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
            self.tx = tx
            self.ty = ty
        }
        
        static var identity: Transform {
            return Transform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)
        }
    
        static func ==(lhs: Transform, rhs: Transform) -> Bool {
            return lhs.a == rhs.a &&
                   lhs.b == rhs.b &&
                   lhs.c == rhs.c &&
                   lhs.d == rhs.d &&
                   lhs.tx == rhs.tx &&
                   lhs.ty == rhs.ty
        }
    }
}


extension Builder.Color {
    
    init(_ color: DOM.Color) {
        self =  Builder.Color.create(from: color)
    }
    
    static func create(from color: DOM.Color) -> Builder.Color {
        switch(color){
        case .none:
            return .none
        case .keyword(let c):
            return Builder.Color(c.rgbi)
        case .rgbi(let c):
            return Builder.Color(c)
        case .hex(let c):
            return Builder.Color(c)
        case .rgbf(let c):
            return .rgba(r: Float(c.0),
                         g: Float(c.1),
                         b: Float(c.2),
                         a: 1.0)
        }
    }
    
    init(_ rgbi: (UInt8, UInt8, UInt8)) {
        self = .rgba(r: Float(rgbi.0)/255.0,
                     g: Float(rgbi.1)/255.0,
                     b: Float(rgbi.2)/255.0,
                     a: 1.0)
    }
}
