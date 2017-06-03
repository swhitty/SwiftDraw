//
//  LayerTree.Color.swift
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
    }
}

extension LayerTree.Color {
    
    init(_ color: DOM.Color) {
        self =  LayerTree.Color.create(from: color)
    }
    
    static func create(from color: DOM.Color) -> LayerTree.Color {
        switch(color){
        case .none:
            return .none
        case .keyword(let c):
            return LayerTree.Color(c.rgbi)
        case .rgbi(let c):
            return LayerTree.Color(c)
        case .hex(let c):
            return LayerTree.Color(c)
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
    
    func withAlpha(_ alpha: Float) -> LayerTree.Color {
        guard alpha > 0.0 else { return .none }
        
        switch self {
        case .none:
            return .none
        case .rgba(r: let r, g: let g, b: let b, a: _):
            return .rgba(r: r,
                         g: g,
                         b: b,
                         a: alpha)
        }
    }
    
    func withMultiplyingAlpha(_ alpha: Float) -> LayerTree.Color {
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
    
    func luminanceToAlpha() -> LayerTree.Color {
        let alpha: Float
        
        switch self {
        case .none:
            alpha = 0
        case .rgba(let r, let g, let b, let a):
            //sRGB Luminance to alpha
            alpha = ((r*0.2126) + (g*0.7152) + (b*0.0722)) * a
        }
        return LayerTree.Color.rgba(r: 0, g: 0, b: 0, a: 1.0).withAlpha(alpha)
    }
}

