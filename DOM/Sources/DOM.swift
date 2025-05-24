//
//  DOM.swift
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

package enum DOM { /* namespace */ }

package extension DOM {
    typealias Float = Swift.Float
    typealias Coordinate = Swift.Float
    typealias Length = Swift.Int
    typealias Opacity = Swift.Float
    typealias Bool = Swift.Bool
    typealias URL = Foundation.URL
}

extension DOM {
    package struct Point: Equatable {
        package var x: Coordinate
        package var y: Coordinate

        package init(_ x: Coordinate, _ y: Coordinate) {
            self.x = x
            self.y = y
        }
    }
    
    package enum Fill: Equatable {
        case url(URL)
        case color(DOM.Color)
        
        package func getColor() throws -> DOM.Color {
            switch self {
            case .url:
                throw Error.missing("Color")
            case .color(let c):
                return c
            }
        }
    }
    
    package enum FillRule: String {
        case nonzero
        case evenodd
    }
    
    package enum DisplayMode: String {
        case none
        case inline
        case block
    }
    
    package enum LineCap: String {
        case butt
        case round
        case square
    }
    
    package enum LineJoin: String {
        case miter
        case round
        case bevel
    }

    package enum TextAnchor: String {
        case start
        case middle
        case end
    }

    package enum Transform: Equatable {
        case matrix(a: Float, b: Float, c: Float, d: Float, e: Float, f: Float)
        case translate(tx: Float, ty: Float)
        case scale(sx: Float, sy: Float)
        case rotate(angle: Float)
        case rotatePoint(angle: Float, cx: Float, cy: Float)
        case skewX(angle: Float)
        case skewY(angle: Float)
    }

    package enum Unit {
        case pixel
        case inch
        case centimeter
        case millimeter
        case point
        case pica
    }

    package enum Error: Swift.Error {
        case missing(String)
    }
}

package extension DOM.Unit {
    var rawValue: String {
        switch self {
        case .pixel:
            return "px"
        case .inch:
            return "in"
        case .centimeter:
            return "cm"
        case .millimeter:
            return "mm"
        case .point:
            return "pt"
        case .pica:
            return "pc"
        }
    }
}

package extension Double {
    func apply(unit: DOM.Unit) -> Double {
        switch unit {
        case .pixel:
            return self
        case .inch:
            return self * 96
        case .centimeter:
            return self * 37.795
        case .millimeter:
            return self * 3.7795
        case .point:
            return self * 1.3333
        case .pica:
            return self * 16
        }
    }
}
