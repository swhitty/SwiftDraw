//
//  LayerTree.Transform.swift
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

import Darwin


extension LayerTree {
    struct Transform: Equatable {
        var a: Float
        var b: Float
        var c: Float
        var d: Float
        var tx: Float
        var ty: Float
        
        init() {
            self.init(a: 0, b: 0, c: 0, d: 0, tx: 0, ty: 0)
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
        
        func concatenated(_ other: Transform) -> Transform {
            let (t, m) = (self, other)
            return Transform(a: (t.a * m.a) + (t.b * m.c),
                             b: (t.a * m.b) + (t.b * m.d),
                             c: (t.c * m.a) + (t.d * m.c),
                             d: (t.c * m.b) + (t.d * m.d),
                             tx: (t.tx * m.a) + (t.ty * m.c) + m.tx,
                             ty: (t.tx * m.b) + (t.ty * m.d) + m.ty)
        }
    }
}

extension LayerTree.Transform {
    init(tx: Float, ty: Float) {
        self.init(a: 0, b: 0, c: 0, d: 0, tx: tx, ty: ty)
    }
    
    init(sx: Float, sy: Float) {
        self.init(a: sx, b: 0, c: 0, d: sy, tx: 0, ty: 0)
    }
    
    init(rotate radians: Float) {
        let sine = sin(radians)
        let cosine = cos(radians)
        self.init(a: cosine, b: sine, c: -sine, d: cosine, tx: 0, ty: 0)
    }
    
    init(rotate radians: Float, around point: LayerTree.Point) {
        let t1 = LayerTree.Transform(tx: point.x, ty: point.y)
        let r = LayerTree.Transform(rotate: radians)
        let t2 = LayerTree.Transform(tx: -point.x, ty: -point.y)
        self = t1.concatenated(r).concatenated(t2)
    }

    init(skewX radians: Float) {
        self.init(a: 1, b: 0, c: tan(radians), d: 1, tx: 0, ty: 0)
    }
    
    init(skewY radians: Float) {
        self.init(a: 1, b: tan(radians), c: 0, d: 1, tx: 0, ty: 0)
    }
}
