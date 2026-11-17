//
//  DOM.Symbol.swift
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

package extension DOM {

    /// `<symbol>`: a template that is never drawn on its own, only by a `<use>` that references it.
    /// The `<use>` establishes a new viewport mapped through the symbol's `viewBox` (SVG 2 §5.5).
    final class Symbol: GraphicsElement, ContainerElement {
        package var viewBox: SVG.ViewBox?
        package var preserveAspectRatio: PreserveAspectRatio?
        // SVG 2: the point of the viewBox placed at the x, y of the <use>; nil keeps SVG 1.1 placement
        package var refX: Coordinate?
        package var refY: Coordinate?
        package var overflow: Overflow?
        // SVG 2 §5.6: the viewport position (added to the x, y of the <use>) and size, used when
        // the <use> sets no width or height; percentages resolve when parsed
        package var x: Coordinate?
        package var y: Coordinate?
        package var width: Coordinate?
        package var height: Coordinate?

        package var childElements = [GraphicsElement]()

        package enum Overflow: String, Sendable {
            case visible
            case hidden
            case scroll
            case auto
        }

        /// The UA stylesheet sets `overflow: hidden` on symbols; `visible` and `auto` show the overflow.
        package var clipsToViewport: Bool {
            switch overflow ?? .hidden {
            case .visible, .auto: return false
            case .hidden, .scroll: return true
            }
        }
    }
}
