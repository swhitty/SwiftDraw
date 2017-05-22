//
//  Builder.Transform.swift
//  SwiftVG
//
//  Created by Simon Whitty on 28/3/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

import CoreGraphics

extension Builder {
    
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

    func createTransformCommands<T: RendererTypeProvider>(from transforms: [DOM.Transform],
                                                          using provider: T) -> [RendererCommand<T>] {
        
        var commands = [RendererCommand<T>]()
        
        for t in transforms {
            commands.append(contentsOf: createCommand(for: t, with: provider))
        }
        
        return commands
    }
    
    func createCommand<T: RendererTypeProvider>(for transform: DOM.Transform,
                        with provider: T) -> [RendererCommand<T>] {
        
        switch transform {
        case .matrix(let m):
            let t = Transform(a: Float(m.a),
                              b: Float(m.b),
                              c: Float(m.c),
                              d: Float(m.d),
                              tx: Float(m.e),
                              ty: Float(m.f))
            return [.concatenate(transform: provider.createTransform(from: t))]
            
        case .translate(let t):
            let tx = provider.createFloat(from: Float(t.tx))
            let ty = provider.createFloat(from: Float(t.ty))
            return [.translate(tx: tx, ty: ty)]
            
        case .scale(let s):
            let sx = provider.createFloat(from: Float(s.sx))
            let sy = provider.createFloat(from: Float(s.sy))
            return [.scale(sx: sx, sy: sy)]
            
        case .rotate(let angle):
            let angle = provider.createFloat(from: Float(angle)*Float.pi/180.0)
            return [.rotate(angle: angle)]
            
        case .rotatePoint(let r):
            let angle = provider.createFloat(from: Float(r.angle)*Float.pi/180.0)
            let tx1 = provider.createFloat(from: Float(r.cx))
            let ty1 = provider.createFloat(from: Float(r.cy))
            let tx2 = provider.createFloat(from: -Float(r.cx))
            let ty2 = provider.createFloat(from: -Float(r.cy))
            return [.translate(tx: tx1, ty: ty1),
                    .rotate(angle: angle),
                    .translate(tx: tx2, ty: ty2)]
            
        case .skewX(let angle):
            let radians = Float(angle)*Float.pi/180.0
            let t = Transform(a: 1,
                              b: 0,
                              c: tan(radians),
                              d: 1,
                              tx: 0,
                              ty: 0)
            return [.concatenate(transform: provider.createTransform(from: t))]
            
        case .skewY(let angle):
            let radians = Float(angle)*Float.pi/180.0
            let t = Transform(a: 1,
                              b: tan(radians),
                              c: 0,
                              d: 1,
                              tx: 0,
                              ty: 0)
            return [.concatenate(transform: provider.createTransform(from: t))]
            
        }

    }
    
    
}
