//
//  LayerTree.Shape.swift
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

extension LayerTree {
    enum Shape: Equatable {
        case line(between: [Point])
        case rect(within: Rect, radii: Size)
        case ellipse(within: Rect)
        case polygon(between: [Point])
        case path(Path)
        
        static func ==(lhs: Shape, rhs: Shape) -> Bool {
            switch (lhs, rhs) {
            case (.line(let lVal), .line(let rVal)):
                return lVal == rVal
            case (.rect(let lVal), .rect(let rVal)):
                return lVal == rVal
            case (.ellipse(let lVal), .ellipse(let rVal)):
                return lVal == rVal
            case (.polygon(let lVal), .polygon(let rVal)):
                return lVal == rVal
            case (.path(let lVal), .path(let rVal)):
                return lVal == rVal
            default:
                return false
            }
        }
    }
}

extension LayerTree.Shape {
    var customDescription: String {
        switch self {
        case .line: return "Line"
        case .rect: return "Rect"
        case .ellipse: return "Ellipse"
        case .polygon: return "Polygon"
        case .path: return "Path"
        }
    }
}

