//
//  DOM.Marker.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 15/11/26.
//  Copyright 2026 Simon Whitty
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

package extension DOM {

    /// SVG 2 §11.6: graphics drawn at the vertices of a path, line, polyline or polygon.
    /// Never rendered directly; its contents inherit from the `<marker>`, not the shape.
    final class Marker: GraphicsElement, ContainerElement {
        package var childElements = [GraphicsElement]()

        package var markerWidth: Coordinate?
        package var markerHeight: Coordinate?
        package var refX: Coordinate?
        package var refY: Coordinate?
        package var orient: Orient?
        package var markerUnits: Units?
        package var viewBox: SVG.ViewBox?
        package var preserveAspectRatio: PreserveAspectRatio?
        /// Holders of the presentation attributes of the marker's ancestors, outermost first, which its
        /// contents inherit; empty for markers built in code.
        package var ancestors = [GraphicsElement]()

        package init(id: String, childElements: [GraphicsElement] = []) {
            super.init()
            self.id = id
            self.childElements = childElements
        }

        package enum Units: String, Sendable {
            case strokeWidth
            case userSpaceOnUse
        }

        package enum Orient: Equatable, Sendable {
            case auto
            case autoStartReverse
            /// degrees
            case angle(Float)
        }
    }
}
