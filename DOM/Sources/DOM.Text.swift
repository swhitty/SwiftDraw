//
//  DOM.Text.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright 2020 Simon Whitty
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

    final class Text: GraphicsElement {
        package var x: Coordinate?
        package var y: Coordinate?
        package var value: String
        /// The text is laid out along a path instead (its runs replace `value`)
        package var textPath: TextPath?

        package init(x: Coordinate? = nil, y: Coordinate? = nil, value: String) {
            self.x = x
            self.y = y
            self.value = value
        }
    }

    /// SVG 1.1 §10.13 `<textPath>`: text laid out along the path `href` references, or (SVG 2) its own `path`.
    final class TextPath: GraphicsElement {
        package var href: URL?
        package var path: Path?
        package var startOffset: Offset?
        package var side: Side?
        package var runs: [TextRun]

        package init(href: URL? = nil, runs: [TextRun] = []) {
            self.href = href
            self.runs = runs
        }

        /// `startOffset`: a distance along the path, or a percentage of its length
        package enum Offset: Equatable {
            case length(Float)
            case percentage(Float)
        }

        package enum Side: String {
            case left
            case right
        }
    }

    /// A `<tspan>` within text content: its own presentation attributes over its runs.
    final class TextSpan: GraphicsElement {
        package var runs: [TextRun]

        package init(runs: [TextRun] = []) {
            self.runs = runs
        }
    }

    /// Character data and `<tspan>` elements, in document order
    enum TextRun {
        case text(String)
        case span(TextSpan)
    }
    
    final class Anchor: GraphicsElement, ContainerElement {
        package var href: URL?
        package var childElements = [GraphicsElement]()
    }
}
