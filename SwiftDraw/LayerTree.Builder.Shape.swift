//
//  LayerTree.Builder.Shape.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 21/11/18.
//  Copyright © 2018 WhileLoop Pty Ltd. All rights reserved.
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

extension LayerTree.Builder {

    static func makeRect(from rect: DOM.Rect) -> LayerTree.Rect {
        return LayerTree.Rect(x: rect.x ?? 0,
                              y: rect.y ?? 0,
                              width: rect.width,
                              height: rect.height)
    }

    static func makeRect(from ellipse: DOM.Ellipse) -> LayerTree.Rect {
        return LayerTree.Rect(x: ellipse.cx - ellipse.rx,
                              y: ellipse.cy - ellipse.ry,
                              width: ellipse.rx * 2,
                              height: ellipse.ry * 2)
    }

    static func makeRect(from circle: DOM.Circle) -> LayerTree.Rect {
        return LayerTree.Rect(x: circle.cx - circle.r,
                              y: circle.cy - circle.r,
                              width: circle.r * 2,
                              height: circle.r * 2)
    }

}
