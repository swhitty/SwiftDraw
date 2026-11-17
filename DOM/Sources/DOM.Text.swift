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
        /// Every value of `x` and `y`, one per character (SVG 1.1 §10.4); `x` and `y` are the first.
        package var xList: [Coordinate] = []
        package var yList: [Coordinate] = []
        /// `dx` and `dy`, one per character
        package var dxList: [Coordinate] = []
        package var dyList: [Coordinate] = []
        /// `rotate` in degrees, one per character; the last value applies to the remaining characters
        package var rotateList: [Float] = []
        /// `textLength` and `lengthAdjust`: the advance the text is fitted to
        package var textLength: Coordinate?
        package var lengthAdjust: LengthAdjust?
        /// The characters of the text: the plain text of `runs`
        package var value: String
        /// The character data and `<tspan>` children, in document order, with white space already
        /// collapsed. Text built from `value` alone is a single run.
        package var runs: [TextRun]
        /// The text is laid out along a path instead (its runs replace `value`)
        package var textPath: TextPath?

        package init(x: Coordinate? = nil, y: Coordinate? = nil, value: String) {
            self.x = x
            self.y = y
            self.value = value
            self.runs = [.text(value)]
        }

        package init(runs: [TextRun]) {
            self.value = TextRun.plainText(of: runs)
            self.runs = runs
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
        /// Absolute `x` and `y`, relative `dx` and `dy`, and `rotate`: lists with one value per character
        /// (SVG 2 §11.5.2). They override the lists of the span's ancestors for its own characters.
        /// An absolute position starts a new text chunk.
        package var xList: [Coordinate] = []
        package var yList: [Coordinate] = []
        package var dxList: [Coordinate] = []
        package var dyList: [Coordinate] = []
        package var rotateList: [Float] = []
        /// `textLength` and `lengthAdjust`: the advance the span's characters are fitted to
        package var textLength: Coordinate?
        package var lengthAdjust: LengthAdjust?
        /// `xml:space` or CSS `white-space` of the span; nil inherits
        package var whiteSpace: WhiteSpace?

        package init(runs: [TextRun] = []) {
            self.runs = runs
        }
    }

    /// SVG 2 §11.5.4 `lengthAdjust`: how text is fitted to its `textLength`
    enum LengthAdjust: String {
        /// the space between the characters changes
        case spacing
        /// the glyphs are stretched or squeezed horizontally too
        case spacingAndGlyphs
    }

    /// How white space in character data is handled: `xml:space="default"` (CSS `white-space: normal`)
    /// collapses it, `xml:space="preserve"` (`white-space: pre`) keeps every space.
    enum WhiteSpace: Equatable {
        case collapse
        case preserve
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
