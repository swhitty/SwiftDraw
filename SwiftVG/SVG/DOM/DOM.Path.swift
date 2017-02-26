//
//  Path.swift
//  SwiftVG
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright © 2016 WhileLoop Pty Ltd. All rights reserved.
//

import Foundation

extension DOM {
    class Path: GraphicsElement {
        
        // segments[0] is always a .move
        var segments: [Segment]
        
        var fillRule: FillRule?
        
        init(x: Coordinate, y: Coordinate) {
            let s = Segment.move(Move(x, y), .absolute)
            segments = [s]
            super.init()
        }
        
        // A Path is made up of these segments
        enum Segment: Equatable {
            case move(Move, CoordinateSpace)
            case line(Line, CoordinateSpace)
            case horizontal(Horizontal, CoordinateSpace)
            case vertical(Vertical, CoordinateSpace)
            case cubic(Cubic, CoordinateSpace)
            case cubicSmooth(CubicSmooth, CoordinateSpace)
            case quadratic(Quadratic, CoordinateSpace)
            case quadraticSmooth(QuadraticSmooth, CoordinateSpace)
            case arc(Arc, CoordinateSpace)
            case close
            
            enum CoordinateSpace {
                case absolute
                case relative
            }
            
            static func ==(lhs: Segment, rhs: Segment) -> Bool {
                switch (lhs, rhs) {
                case (.move(let lVal), .move(let rVal)):
                    return lVal == rVal
                case (.line(let lVal), .line(let rVal)):
                    return lVal == rVal
                case (.horizontal(let lVal), .horizontal(let rVal)):
                    return lVal == rVal
                case (.vertical(let lVal), .vertical(let rVal)):
                    return lVal == rVal
                case (.cubic(let lVal), .cubic(let rVal)):
                    return lVal == rVal
                case (.cubicSmooth(let lVal), .cubicSmooth(let rVal)):
                    return lVal == rVal
                case (.quadratic(let lVal), .quadratic(let rVal)):
                    return lVal == rVal
                case (.quadraticSmooth(let lVal), .quadraticSmooth(let rVal)):
                    return lVal == rVal
                case (.arc(let lVal), .arc(let rVal)):
                    return lVal == rVal
                case (.close, .close): return true
                default:
                    return false
                }
            }
            
        }
        
        struct Move: Equatable {
            var x: Coordinate
            var y: Coordinate
            
            init(_ x: Coordinate, _ y: Coordinate) {
                self.x = x
                self.y = y
            }
            
            static func ==(lhs: Move, rhs: Move) -> Bool {
                return lhs.x == rhs.x &&
                    lhs.y == rhs.y
            }
        }
        
        struct Line: Equatable {
            var x: Coordinate
            var y: Coordinate
            
            init(_ x: Coordinate, _ y: Coordinate) {
                self.x = x
                self.y = y
            }
            
            static func ==(lhs: Line, rhs: Line) -> Bool {
                return lhs.x == rhs.x &&
                    lhs.y == rhs.y
            }
        }
        
        struct Horizontal: Equatable {
            var x: Coordinate
            
            init(_ x: Coordinate) {
                self.x = x
            }
            
            static func ==(lhs: Horizontal, rhs: Horizontal) -> Bool {
                return lhs.x == rhs.x
            }
        }
        
        struct Vertical: Equatable {
            var y: Coordinate
            
            init(_ y: Coordinate) {
                self.y = y
            }
            
            static func ==(lhs: Vertical, rhs: Vertical) -> Bool {
                return lhs.y == rhs.y
            }
        }
        
        struct Cubic: Equatable {
            var x: Coordinate
            var y: Coordinate
            var x1: Coordinate
            var y1: Coordinate
            var x2: Coordinate
            var y2: Coordinate
            
            init(_ x: Coordinate, _ y: Coordinate,
                 _ x1: Coordinate, _ y1: Coordinate,
                 _ x2: Coordinate, _ y2: Coordinate) {
                self.x = x
                self.y = y
                self.x1 = x1
                self.y1 = y1
                self.x2 = x2
                self.y2 = y2
            }
            
            static func ==(lhs: Cubic, rhs: Cubic) -> Bool {
                return lhs.x == rhs.x &&
                    lhs.y == rhs.y &&
                    lhs.x1 == rhs.x1 &&
                    lhs.y1 == rhs.y1 &&
                    lhs.x2 == rhs.x2 &&
                    lhs.y2 == rhs.y2
            }
        }
        
        struct CubicSmooth: Equatable {
            var x: Coordinate
            var y: Coordinate
            var x2: Coordinate
            var y2: Coordinate
            
            init(_ x: Coordinate, _ y: Coordinate,
                 _ x2: Coordinate, _ y2: Coordinate) {
                self.x = x
                self.y = y
                self.x2 = x2
                self.y2 = y2
            }
            
            static func ==(lhs: CubicSmooth, rhs: CubicSmooth) -> Bool {
                return lhs.x == rhs.x &&
                    lhs.y == rhs.y &&
                    lhs.x2 == rhs.x2 &&
                    lhs.y2 == rhs.y2
            }
        }
        
        struct Quadratic: Equatable {
            var x: Coordinate
            var y: Coordinate
            var x1: Coordinate
            var y1: Coordinate
            
            init(_ x: Coordinate, _ y: Coordinate,
                 _ x1: Coordinate, _ y1: Coordinate) {
                self.x = x
                self.y = y
                self.x1 = x1
                self.y1 = y1
            }
            
            static func ==(lhs: Quadratic, rhs: Quadratic) -> Bool {
                return lhs.x == rhs.x &&
                    lhs.y == rhs.y &&
                    lhs.x1 == rhs.x1 &&
                    lhs.y1 == rhs.y1
            }
        }
        
        struct QuadraticSmooth: Equatable {
            var x: Coordinate
            var y: Coordinate
            
            init(_ x: Coordinate, _ y: Coordinate) {
                self.x = x
                self.y = y
            }
            
            static func ==(lhs: QuadraticSmooth, rhs: QuadraticSmooth) -> Bool {
                return lhs.x == rhs.x &&
                    lhs.y == rhs.y
            }
        }
        
        struct Arc: Equatable {
            var x: Coordinate
            var y: Coordinate
            var rx: Coordinate
            var ry: Coordinate
            var rotate: Coordinate
            var large: Bool
            var sweep: Bool
            
            init(_ x: Coordinate, _ y: Coordinate,
                 _ rx: Coordinate, _ ry: Coordinate,
                 _ rotate: Coordinate, _ large: Bool, _ sweep: Bool) {
                self.x = x
                self.y = y
                self.rx = rx
                self.ry = ry
                self.rotate = rotate
                self.large = large
                self.sweep = sweep
            }
            
            static func ==(lhs: Arc, rhs: Arc) -> Bool {
                return lhs.x == rhs.x &&
                    lhs.y == rhs.y &&
                    lhs.rx == rhs.rx &&
                    lhs.ry == rhs.ry &&
                    lhs.rotate == rhs.rotate &&
                    lhs.large == rhs.large &&
                    lhs.sweep == rhs.sweep
            }
        }
    }
}

extension DOM.Path {
    
    typealias Coordinate = DOM.Coordinate
    typealias CoordinateSpace = DOM.Path.Segment.CoordinateSpace
    
    func move(x: Coordinate, y: Coordinate, space: CoordinateSpace = .absolute) {
        let s = Segment.move(Move(x, y), space)
        segments.append(s)
    }
    
    func line(x: Coordinate, y: Coordinate, space: CoordinateSpace = .absolute) {
        let s = Segment.line(Line(x, y), space)
        segments.append(s)
    }
    
    func horizontal(x: Coordinate, space: CoordinateSpace = .absolute) {
        let s = Segment.horizontal(Horizontal(x), space)
        segments.append(s)
    }
    
    func vertical(y: Coordinate, space: CoordinateSpace = .absolute) {
        let s = Segment.vertical(Vertical(y), space)
        segments.append(s)
    }
    
    func quadratic(x: Coordinate, y: Coordinate,
                   x1: Coordinate, y1: Coordinate,
                   space: CoordinateSpace = .absolute) {
        let q = Quadratic(x, y, x1, y1)
        let s = Segment.quadratic(q, space)
        segments.append(s)
    }
    
    func quadratic(x: Coordinate, y: Coordinate, space: CoordinateSpace = .absolute) {
        let s = Segment.quadraticSmooth(QuadraticSmooth(x, y), space)
        segments.append(s)
    }
    
    func cubic(x: Coordinate, y: Coordinate,
               x1: Coordinate, y1: Coordinate,
               x2: Coordinate, y2: Coordinate,
               space: CoordinateSpace = .absolute) {
        let c = Cubic(x, y, x1, y1, x2, y2)
        let s = Segment.cubic(c, space)
        segments.append(s)
    }
    
    func cubic(x: Coordinate, y: Coordinate,
               x2: Coordinate, y2: Coordinate,
               space: CoordinateSpace = .absolute) {
        let c = CubicSmooth(x, y, x2, y2)
        let s = Segment.cubicSmooth(c, space)
        segments.append(s)
    }
    
    func arc(x: Coordinate,
             y: Coordinate,
             rx: Coordinate,
             ry: Coordinate,
             rotate: Float,
             large: Bool,
             sweep: Bool,
             space: CoordinateSpace = .absolute) {
        
        let a = Arc(x, y, rx, ry, rotate, large, sweep)
        let s = Segment.arc(a, space)
        segments.append(s)
    }
    
    func close() {
        segments.append(.close)
    }
}
