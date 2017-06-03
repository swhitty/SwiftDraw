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
    }
}
