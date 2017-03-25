//
//  Renderer.Color.swift
//  SwiftVG
//
//  Created by Simon Whitty on 25/3/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

import CoreGraphics

extension Renderer {
    
    enum Color {
        case none
        case rgba(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)
    }
    
    func createColor(from color: DOM.Color) -> Color {
        switch(color){
        case .none:
            return .none
        case .keyword(let c):
            return createColor(from: c.rgbi)
        case .rgbi(let c):
            return createColor(from: c)
        case .hex(let c):
            return createColor(from: c)
        case .rgbf(let r, let g, let b):
            return .rgba(r: CGFloat(r),
                         g: CGFloat(g),
                         b: CGFloat(b),
                         a: 1.0)
        }
    }
    
    func createColor(from rgbi: (UInt8, UInt8, UInt8)) -> Color {
        return .rgba(r: CGFloat(rgbi.0)/255.0,
                     g: CGFloat(rgbi.1)/255.0,
                     b: CGFloat(rgbi.2)/255.0,
                     a: 1.0)
    }
}

extension Renderer.Color {
    
    var cgColor: CGColor {
        switch self {
        case .none: return cgColor(r: 0, g: 0, b: 0, a: 0)
        case .rgba(let c): return cgColor(r: c.r, g: c.g, b: c.b, a: c.a)
        }
        
    }
    
    private func cgColor(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) -> CGColor {
        #if os(iOS)
            return CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(),
                           components: [r, g, b, a])!
        #else
            return CGColor(red: r,
                           green: g,
                           blue: b,
                           alpha: a)
        #endif
    }
}
