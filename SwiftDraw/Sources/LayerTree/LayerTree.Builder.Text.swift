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
    }

    /// SVG 1.1 §10.4 text chunk: runs drawn one after the other from an absolute position.
    /// `text-anchor` shifts the chunk as a whole by its advance.
    struct TextChunk {
        var runs = [TextRunPlacement]()
        /// where the pen is after the last run
        var end: LayerTree.Float = 0

        var anchor: DOM.TextAnchor {
            runs.first?.state.textAnchor ?? .start
        }

        var advance: LayerTree.Float {
            guard let start = runs.first?.origin.x else { return 0 }
            return end - start
        }
    }

    /// The runs of `text` laid out on one line, split into text chunks. Each run starts where the
    /// previous one's advance ends; an absolute `x` or `y` on a `<tspan>` starts a new chunk there.
    /// A `<tspan>` with `display="none"` takes no space. Only the first value of each position list
    /// is applied for now.
    func makeTextChunks(for text: DOM.Text, with state: State) -> [TextChunk] {
        var chunks = [TextChunk]()
        var current = TextChunk()
        var pen = LayerTree.Point(LayerTree.Float(text.x ?? 0) + LayerTree.Float(text.dxList.first ?? 0),
                                  LayerTree.Float(text.y ?? 0) + LayerTree.Float(text.dyList.first ?? 0))

        // consecutive runs in the same font are measured together, as browsers and resvg shape them,
        // so kerning applies across a change of colour: each run ends where the joined text would.
        // A `dx` or `dy` moves the pen without breaking the shaping.
        var shaped: (font: LayerTree.TextAttributes, text: String, advance: LayerTree.Float)?

        func layout(_ runs: [DOM.TextRun], state: State) {
            for run in runs {
                switch run {
                case .text(let string):
                    // a font-size of 0 draws nothing (CoreText would fall back to its default size)
                    guard !string.isEmpty, state.fontSize > 0 else { continue }
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
                    current.runs.append(TextRunPlacement(string: string, state: state, origin: origin))
                    current.end = pen.x
                case .span(let span):
                    let spanState = createState(for: span, inheriting: state)
                    guard spanState.display != .none else { continue }
                    let x = span.xList.first
                    let y = span.yList.first
                    if x != nil || y != nil {
                        // a text chunk is shaped on its own
                        shaped = nil
                        if !current.runs.isEmpty {
                            chunks.append(current)
                            current = TextChunk()
                        }
                        pen = LayerTree.Point(x.map { LayerTree.Float($0) } ?? pen.x,
                                              y.map { LayerTree.Float($0) } ?? pen.y)
                    }
                    pen.x += LayerTree.Float(span.dxList.first ?? 0)
                    pen.y += LayerTree.Float(span.dyList.first ?? 0)
                    layout(span.runs, state: spanState)
                }
            }
        }

        layout(text.runs, state: state)
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
            let shift = Self.makeXOffset(width: Double(chunk.advance), anchor: chunk.anchor)
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
                if let runContents = makeTextRunContents(run.string, at: point, with: state) {
                    contents.append(runContents)
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
