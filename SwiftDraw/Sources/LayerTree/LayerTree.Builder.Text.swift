//
//  LayerTree.Builder.Text.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 26/8/22.
//  Copyright 2022 Simon Whitty
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

// Convert a DOM.SVG into a layer tree

import SwiftDrawDOM
import Foundation
#if canImport(CoreText)
import CoreText
#endif

extension LayerTree.Builder {

    /// A run of characters placed on the line, with the state of its innermost `<tspan>`
    struct TextRunPlacement {
        var string: String
        var state: State
        /// The start of the run on the baseline, before `text-anchor` and the baseline shift
        var origin: LayerTree.Point
        var advance: LayerTree.Float = 0
        /// `rotate` of a single character in degrees, about its origin
        var rotate: LayerTree.Float = 0
    }

    /// SVG 2 §11.5.3 text chunk: runs drawn one after the other from an absolute position.
    /// `text-anchor` shifts the chunk as a whole.
    struct TextChunk {
        var runs = [TextRunPlacement]()

        var anchor: DOM.TextAnchor {
            runs.first?.state.textAnchor ?? .start
        }

        /// SVG 2 §11.5.2 "Apply anchoring": the chunk spans from the leftmost to the rightmost edge
        /// of its runs (a negative `dx` can move a run before the first), and that span is aligned
        /// to the chunk's first position.
        var shift: LayerTree.Float {
            guard let x = runs.first?.origin.x else { return 0 }
            var minX = LayerTree.Float.infinity
            var maxX = -LayerTree.Float.infinity
            for run in runs {
                let edges = [run.origin.x, run.origin.x + run.advance]
                minX = min(minX, edges.min()!)
                maxX = max(maxX, edges.max()!)
            }
            switch anchor {
            case .start: return x - minX
            case .middle: return x - (minX + maxX) / 2
            case .end: return x - maxX
            }
        }
    }

    /// An addressable character (a grapheme cluster) of the text, with the state of its innermost
    /// `<tspan>` and its resolved position adjustments (SVG 2 §11.5.2)
    struct TextCharacter {
        var character: Character
        var state: State
        /// the text node it belongs to: characters of one node share their state
        var run: Int
        var x: LayerTree.Float?
        var y: LayerTree.Float?
        var dx: LayerTree.Float = 0
        var dy: LayerTree.Float = 0
        var rotate: LayerTree.Float = 0
    }

    /// The addressable characters of `text`, in order, each with the `x`, `y`, `dx`, `dy` and `rotate`
    /// that apply to it. A list indexes the characters of its element, descendants included; a
    /// descendant's own list overrides it for the characters it covers. Characters past the end of a
    /// list take no value, except for `rotate`, whose last value repeats. A `<tspan>` with
    /// `display="none"` has no addressable characters.
    func makeTextCharacters(for text: DOM.Text, with state: State) -> [TextCharacter] {
        struct Lists {
            var range: Range<Int>
            var x: [DOM.Coordinate]
            var y: [DOM.Coordinate]
            var dx: [DOM.Coordinate]
            var dy: [DOM.Coordinate]
            var rotate: [DOM.Float]
        }
        var characters = [TextCharacter]()
        // in document order, so an ancestor's lists are applied before its descendants'
        var lists = [Lists]()
        var runCount = 0

        func collect(_ runs: [DOM.TextRun], state: State) {
            for run in runs {
                switch run {
                case .text(let string):
                    runCount += 1
                    for character in string {
                        characters.append(TextCharacter(character: character, state: state, run: runCount))
                    }
                case .span(let span):
                    let spanState = createState(for: span, inheriting: state)
                    guard spanState.display != .none else { continue }
                    let index = lists.count
                    let start = characters.count
                    lists.append(Lists(range: start..<start, x: span.xList, y: span.yList,
                                       dx: span.dxList, dy: span.dyList, rotate: span.rotateList))
                    collect(span.runs, state: spanState)
                    lists[index].range = start..<characters.count
                }
            }
        }

        lists.append(Lists(range: 0..<0, x: text.xList, y: text.yList,
                           dx: text.dxList, dy: text.dyList, rotate: text.rotateList))
        collect(text.runs, state: state)
        lists[0].range = 0..<characters.count

        for list in lists {
            func apply(_ values: [DOM.Coordinate], _ keyPath: WritableKeyPath<TextCharacter, LayerTree.Float?>) {
                for (offset, value) in zip(list.range, values) {
                    characters[offset][keyPath: keyPath] = LayerTree.Float(value)
                }
            }
            func apply(_ values: [DOM.Coordinate], _ keyPath: WritableKeyPath<TextCharacter, LayerTree.Float>) {
                for (offset, value) in zip(list.range, values) {
                    characters[offset][keyPath: keyPath] = LayerTree.Float(value)
                }
            }
            apply(list.x, \.x)
            apply(list.y, \.y)
            apply(list.dx, \.dx)
            apply(list.dy, \.dy)
            if let last = list.rotate.last {
                for (offset, index) in list.range.enumerated() {
                    characters[index].rotate = LayerTree.Float(offset < list.rotate.count ? list.rotate[offset] : last)
                }
            }
        }
        return characters
    }

    /// The characters of `text` laid out on one line, split into text chunks. Each character starts
    /// where the previous one's advance ends, moved by its `dx` and `dy`; an absolute `x` or `y`
    /// starts a new chunk there. Characters of one text node that are not positioned or rotated on
    /// their own are drawn together as a run, so their kerning and ligatures are kept.
    func makeTextChunks(for text: DOM.Text, with state: State) -> [TextChunk] {
        var chunks = [TextChunk]()
        var current = TextChunk()
        var pen = LayerTree.Point.zero

        // consecutive runs in the same font are measured together, as browsers and resvg shape them,
        // so kerning applies across a change of colour: each run ends where the joined text would.
        // A `dx` or `dy` moves the pen without breaking the shaping; a new chunk is shaped on its own.
        var shaped: (font: LayerTree.TextAttributes, text: String, advance: LayerTree.Float)?
        var pending: (string: String, state: State, run: Int, rotate: LayerTree.Float)?

        func place(_ string: String, state: State, rotate: LayerTree.Float) {
            var font = makeTextAttributes(with: state)
            font.color = .none
            font.anchor = .start
            font.baseline = .auto
            let advance = Self.makeAdvance(for: string, with: font)
            var origin = pen
            if let previous = shaped, previous.font == font {
                let text = previous.text + string
                let total = Self.makeAdvance(for: text, with: font)
                pen.x += total - previous.advance
                origin.x = pen.x - advance
                shaped = (font, text, total)
            } else {
                pen.x += advance
                shaped = (font, string, advance)
            }
            // the run's advance as placed: from its origin to where the shaped text ends
            current.runs.append(TextRunPlacement(string: string, state: state, origin: origin,
                                                 advance: pen.x - origin.x, rotate: rotate))
        }

        func flush() {
            guard let run = pending else { return }
            place(run.string, state: run.state, rotate: run.rotate)
            pending = nil
        }

        for character in makeTextCharacters(for: text, with: state) {
            // a font-size of 0 draws nothing (CoreText would fall back to its default size)
            guard character.state.fontSize > 0 else { continue }
            let isAbsolute = character.x != nil || character.y != nil
            let isAdjusted = isAbsolute || character.dx != 0 || character.dy != 0 || character.rotate != 0

            if let run = pending, run.run == character.run, run.rotate == 0, !isAdjusted {
                pending?.string.append(character.character)
                continue
            }
            flush()
            if isAbsolute {
                shaped = nil
                if !current.runs.isEmpty {
                    chunks.append(current)
                    current = TextChunk()
                }
                pen = LayerTree.Point(character.x ?? pen.x, character.y ?? pen.y)
            }
            pen.x += character.dx
            pen.y += character.dy
            pending = (String(character.character), character.state, character.run, character.rotate)
        }
        flush()
        if !current.runs.isEmpty {
            chunks.append(current)
        }
        return chunks
    }

    /// Every run of the text, each drawn with its own state. A single run is returned as is, several
    /// within a layer; nil when nothing is drawn.
    /// - Parameter isClip: the text is part of a `<clipPath>`: its glyphs are filled white, whatever their paint
    func makeTextContents(from text: DOM.Text, with state: State, isClip: Bool = false) -> LayerTree.Layer.Contents? {
        var contents = [LayerTree.Layer.Contents]()
        for chunk in makeTextChunks(for: text, with: state) {
            let shift = chunk.shift
            for run in chunk.runs {
                // SVG 1.1 §11.6.2: a hidden run is not drawn, but keeps its advance
                guard run.state.visibility == .visible else { continue }
                var state = run.state
                if isClip {
                    state.fill = .color(.keyword(.white))
                    state.fillOpacity = 1
                    state.stroke = .color(.none)
                }
                let point = LayerTree.Point(run.origin.x + shift, run.origin.y)
                guard let runContents = makeTextRunContents(run.string, at: point, with: state) else { continue }
                if run.rotate == 0 {
                    contents.append(runContents)
                } else {
                    // `rotate` turns the glyph about its origin, clockwise in degrees
                    let layer = LayerTree.Layer()
                    layer.transform = [.translate(tx: point.x, ty: point.y),
                                       .rotate(radians: run.rotate * .pi / 180),
                                       .translate(tx: -point.x, ty: -point.y)]
                    layer.appendContents(runContents)
                    contents.append(.layer(layer))
                }
            }
        }

        switch contents.count {
        case 0:
            return nil
        case 1:
            return contents[0]
        default:
            let layer = LayerTree.Layer()
            contents.forEach(layer.appendContents)
            return .layer(layer)
        }
    }

    /// One run of characters starting at `point` on the line, shifted to the baseline of its state
    func makeTextRunContents(_ string: String, at point: LayerTree.Point, with state: State) -> LayerTree.Layer.Contents? {
        // state already holds the cascaded font-family, font-size, font-weight, font-style and text-anchor
        let att = makeTextAttributes(with: state)
        var point = point
        point.y += Self.makeBaselineOffset(with: att)

#if canImport(CoreText)
        // text painted with a paint server or a stroke is drawn as its glyph outlines, through the
        // shape pipeline, so it gets gradients, patterns, strokes and the text's bounding box for free
        if needsOutlines(for: state),
           let outlines = CGProvider().createPath(from: string, at: point, with: att) {
            var state = state
            // glyph outlines are designed for nonzero; fill-rule does not apply to text in browsers
            state.fillRule = .nonzero
            return makeShapeContents(from: .path(outlines.makePath()), with: state)
        }
#endif
        return .text(string, point, att)
    }

    static func makeXOffset(width: Double, anchor: DOM.TextAnchor) -> LayerTree.Float {
        switch anchor {
        case .start:
           return 0
        case .middle:
            return LayerTree.Float(-width / 2)
        case .end:
            return LayerTree.Float(-width)
        }
    }

#if canImport(CoreText)
    /// The advance width of `text` in the font of `attributes`, kerned
    static func makeAdvance(for text: String, with attributes: LayerTree.TextAttributes) -> LayerTree.Float {
        let font = CGProvider.createFont(for: attributes)
        return LayerTree.Float(text.toWidth(font: font.font, synthesis: font.synthesis(for:)))
    }

    static func makeBaselineOffset(with attributes: LayerTree.TextAttributes) -> LayerTree.Float {
        makeYOffset(font: CGProvider.createFont(for: attributes).font, baseline: attributes.baseline)
    }
#else
    static func makeAdvance(for text: String, with attributes: LayerTree.TextAttributes) -> LayerTree.Float {
        0
    }

    static func makeBaselineOffset(with attributes: LayerTree.TextAttributes) -> LayerTree.Float {
        0
    }
#endif

#if canImport(CoreText)
    static func makeOffset(for text: String, with attributes: LayerTree.TextAttributes) -> LayerTree.Size {
        let font = CGProvider.createFont(for: attributes)
        let width = text.toWidth(font: font.font, synthesis: font.synthesis(for:))
        return LayerTree.Size(
            makeXOffset(width: width, anchor: attributes.anchor),
            makeYOffset(font: font.font, baseline: attributes.baseline)
        )
    }

    static func makeYOffset(font: CTFont, baseline: DOM.TextBaseline) -> LayerTree.Float {
        switch baseline {
        case .central:
            let capHeight = CTFontGetCapHeight(font)
            return LayerTree.Float(capHeight / 2)
        case .alphabetic, .auto:
            return 0
        case .hanging:
            let leading = CTFontGetLeading(font)
            let ascent = CTFontGetAscent(font) - leading
            return LayerTree.Float(-ascent)
        case .middle:
            let xHeight = CTFontGetXHeight(font)
            return LayerTree.Float(xHeight / 2)
        }
    }
#else
    static func makeOffset(for text: String, with attributes: LayerTree.TextAttributes) -> LayerTree.Size {
        return .zero
    }
#endif

}

extension DOM.FontFamily {

    var fontName: String {
        switch self {
        case .name(let s):
            return s
        case .keyword(.serif):
            return "Times"
        case .keyword(.sansSerif):
            return "Helvetica"
        case .keyword(.monospace):
            return "Courier"
        case .keyword(.fantasy):
            return "Papyrus"
        case .keyword(.cursive):
            return "Apple Chancery"
        }
    }
}
