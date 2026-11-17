//
//  LayerTree.Builder.Shape.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 21/11/18.
//  Copyright 2020 WhileLoop Pty Ltd. All rights reserved.
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

import SwiftDrawDOM
import Foundation

extension LayerTree.Builder {

    static func makeShape(from element: DOM.GraphicsElement) -> LayerTree.Shape? {
        if let line = element as? DOM.Line {
            let from = Point(line.x1, line.y1)
            let to = Point(line.x2, line.y2)
            return .line(between: [from, to])
        } else if let circle = element as? DOM.Circle {
            // SVG 2 §10.3–10.5: a zero (or negative) size disables rendering
            guard circle.r > 0 else { return nil }
            return .ellipse(within: makeRect(from: circle))
        } else if let ellipse = element as? DOM.Ellipse {
            guard ellipse.rx > 0, ellipse.ry > 0 else { return nil }
            return .ellipse(within: makeRect(from: ellipse))
        } else if let rect = element as? DOM.Rect {
            guard rect.width > 0, rect.height > 0 else { return nil }
            let radii = makeRadii(rx: rect.rx, ry: rect.ry, width: rect.width, height: rect.height)
            return .rect(within: makeRect(from: rect), radii: radii)
        } else if let polyline = element as? DOM.Polyline {
            return .line(between: polyline.points.map { Point($0.x, $0.y) })
        } else if let polygon = element as? DOM.Polygon {
            return .polygon(between: polygon.points.map { Point($0.x, $0.y) })
        } else if let domPath = element as? DOM.Path,
            let path = try? createPath(from: domPath)
        {
            return .path(path)
        }

        return nil;
    }

    static func makeRect(from rect: DOM.Rect) -> LayerTree.Rect {
        return LayerTree.Rect(
            x: rect.x ?? 0,
            y: rect.y ?? 0,
            width: rect.width,
            height: rect.height
        )
    }

    static func makeRect(from ellipse: DOM.Ellipse) -> LayerTree.Rect {
        let cx = ellipse.cx ?? 0
        let cy = ellipse.cy ?? 0
        return LayerTree.Rect(
            x: cx - ellipse.rx,
            y: cy - ellipse.ry,
            width: ellipse.rx * 2,
            height: ellipse.ry * 2
        )
    }

    static func makeRect(from circle: DOM.Circle) -> LayerTree.Rect {
        let cx = circle.cx ?? 0
        let cy = circle.cy ?? 0
        return LayerTree.Rect(
            x: cx - circle.r,
            y: cy - circle.r,
            width: circle.r * 2,
            height: circle.r * 2
        )
    }

    /// SVG 2 §10.2: an auto (or negative) `rx` uses `ry` and vice versa,
    /// and each is clamped to half the width or height.
    static func makeRadii(rx: DOM.Float?, ry: DOM.Float?, width: DOM.Float, height: DOM.Float) -> LayerTree.Size {
        let rx = rx.flatMap { $0 >= 0 ? $0 : nil }
        let ry = ry.flatMap { $0 >= 0 ? $0 : nil }
        return LayerTree.Size(
            min(rx ?? ry ?? 0, width / 2),
            min(ry ?? rx ?? 0, height / 2)
        )
    }
}
