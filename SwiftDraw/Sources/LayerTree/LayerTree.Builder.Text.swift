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
        /// from the origin to the end of its last character, without the spacing after it
        var advance: LayerTree.Float = 0
        /// the leftmost start and rightmost end of its characters' cells on the line: with `dx` within
        /// the run, a character can start before the run's origin
        var extent: ClosedRange<LayerTree.Float>?
        /// `rotate` of a single character in degrees, about its origin
        var rotate: LayerTree.Float = 0
        /// Its glyphs, each placed on the line (before `text-anchor` and the baseline shift), when its
        /// characters are not laid out as the font would on its own: spacing or `dx` / `dy` within
        /// it, or a rotated character. nil draws `string` as text.
        var glyphs: [PlacedGlyph]?

        var horizontalExtent: ClosedRange<LayerTree.Float> {
            if let extent { return extent }
            let end = origin.x + advance
            return min(origin.x, end)...max(origin.x, end)
        }
    }

    struct PlacedGlyph: Equatable {
        var fontName: String
        var glyph: UInt16
        var position: LayerTree.Point
        /// `lengthAdjust="spacingAndGlyphs"`: the glyph is stretched horizontally about its origin
        var scaleX: LayerTree.Float = 1
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
                let extent = run.horizontalExtent
                minX = min(minX, extent.lowerBound)
                maxX = max(maxX, extent.upperBound)
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
        collectTextCharacters(for: text, with: state).characters
    }

    /// The `textLength` of `<text>` or a `<tspan>`: the advance its characters are fitted to
    struct TextLength: Equatable {
        /// its characters, as indices of `makeTextCharacters`
        var range: Range<Int>
        var length: LayerTree.Float
        var adjust: DOM.LengthAdjust
    }

    /// Every `textLength` of the text, innermost first (SVG 2 §11.5.2 "Resolve text length")
    func makeTextLengths(for text: DOM.Text, with state: State) -> [TextLength] {
        collectTextCharacters(for: text, with: state).lengths
    }

    private func collectTextCharacters(
        for text: DOM.Text,
        with state: State
    ) -> (characters: [TextCharacter], lengths: [TextLength]) {
        struct Lists {
            var range: Range<Int>
            var x: [DOM.Coordinate]
            var y: [DOM.Coordinate]
            var dx: [DOM.Coordinate]
            var dy: [DOM.Coordinate]
            var rotate: [DOM.Float]
        }
        // when an element's characters are complete: descendants first
        var lengths = [TextLength]()
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
                    lists.append(
                        Lists(
                            range: start..<start,
                            x: span.xList,
                            y: span.yList,
                            dx: span.dxList,
                            dy: span.dyList,
                            rotate: span.rotateList
                        )
                    )
                    collect(span.runs, state: spanState)
                    lists[index].range = start..<characters.count
                    if let length = span.textLength {
                        lengths.append(
                            TextLength(
                                range: start..<characters.count,
                                length: LayerTree.Float(length),
                                adjust: span.lengthAdjust ?? .spacing
                            )
                        )
                    }
                }
            }
        }

        lists.append(
            Lists(
                range: 0..<0,
                x: text.xList,
                y: text.yList,
                dx: text.dxList,
                dy: text.dyList,
                rotate: text.rotateList
            )
        )
        collect(text.runs, state: state)
        lists[0].range = 0..<characters.count
        if let length = text.textLength {
            lengths.append(
                TextLength(
                    range: 0..<characters.count,
                    length: LayerTree.Float(length),
                    adjust: text.lengthAdjust ?? .spacing
                )
            )
        }

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
        return (characters, lengths)
    }

    /// The characters of `text` laid out on one line, split into text chunks. Each character starts
    /// where the previous one's advance (and `letter-spacing` / `word-spacing`) ends, moved by its `dx`
    /// and `dy`; an absolute `x` or `y` starts a new chunk there.
    ///
    /// Characters are shaped together while they share a font, across text nodes and `dx` / `dy`,
    /// so kerning applies between them; each chunk is shaped on its own. A text node's characters
    /// that flow as the font lays them out are kept together as one run of text. Those with spacing
    /// or `dx` / `dy` between them, or rotated, are placed glyph by glyph from the shaping.
    func makeTextChunks(for text: DOM.Text, with state: State) -> [TextChunk] {
        let (characters, lengths) = collectTextCharacters(for: text, with: state)
        // a font-size of 0 draws nothing (CoreText would fall back to its default size): such
        // characters keep their index, for the lists and text lengths, but are not laid out
        let isDrawn = characters.map { $0.state.fontSize > 0 }
        var shaped = Array(repeating: ShapedCharacter(advance: 0, glyphs: []), count: characters.count)
        let drawnIndices = characters.indices.filter { isDrawn[$0] }
        for (index, shape) in zip(drawnIndices, makeShapedCharacters(for: drawnIndices.map { characters[$0] })) {
            shaped[index] = shape
        }

        var chunks = [TextChunk]()
        var current = TextChunk()
        var pen = LayerTree.Point.zero

        struct Segment {
            var string: String
            var state: State
            var run: Int
            var rotate: LayerTree.Float
            /// `lengthAdjust="spacingAndGlyphs"`: the horizontal scale of its glyphs
            var scale: LayerTree.Float
            var origin: LayerTree.Point
            var glyphs = [PlacedGlyph]()
            /// laid out as the font would on its own: drawn as text
            var isNatural = true
            /// where its last character ends, before the spacing after it
            var end: LayerTree.Float
            /// the spacing after its last character
            var spacing: LayerTree.Float = 0
            /// the leftmost start and rightmost end of its characters
            var extent: ClosedRange<LayerTree.Float>
        }
        var segment: Segment?

        func flush() {
            guard let s = segment else { return }
            current.runs.append(
                TextRunPlacement(
                    string: s.string,
                    state: s.state,
                    origin: s.origin,
                    advance: s.end - s.origin.x,
                    extent: s.extent,
                    rotate: s.rotate,
                    glyphs: s.isNatural ? nil : s.glyphs
                )
            )
            segment = nil
        }

        // CSS Text 3 §8.2: no letter-spacing within cursive scripts, whose letters join. Spaces and
        // punctuation beside a cursive letter belong to its run, so they take none either.
        let isCursive = characters.indices.map { index -> Bool in
            let character = characters[index].character
            if Self.isCursive(character) { return true }
            guard !character.isLetter && !character.isNumber else { return false }
            let previous = index > 0 && Self.isCursive(characters[index - 1].character)
            let next = index + 1 < characters.count && Self.isCursive(characters[index + 1].character)
            return previous || next
        }
        // CSS Text 3 §8: the spacing after each typographic character
        var spacings = characters.indices.map { index -> LayerTree.Float in
            let character = characters[index]
            var spacing = isCursive[index] ? 0 : character.state.letterSpacing
            if Self.isWordSeparator(character.character) {
                spacing += character.state.wordSpacing
            }
            return spacing
        }
        let advances = shaped.map(\.advance)
        let fitted = Self.makeFittedSpacing(
            lengths,
            characters: characters,
            isDrawn: isDrawn,
            advances: advances,
            spacings: spacings
        )
        spacings = fitted.spacings
        let scales = fitted.scales

        for (index, (character, shape)) in zip(characters, shaped).enumerated() {
            guard isDrawn[index] else { continue }
            let scale = scales[index]
            let isAbsolute = character.x != nil || character.y != nil
            let isMoved = character.dx != 0 || character.dy != 0
            if isAbsolute {
                flush()
                if !current.runs.isEmpty {
                    chunks.append(current)
                    current = TextChunk()
                }
                pen = LayerTree.Point(character.x ?? pen.x, character.y ?? pen.y)
            }
            pen.x += character.dx
            pen.y += character.dy

            if var s = segment, s.run == character.run, s.rotate == 0, character.rotate == 0,
                s.scale == scale, !isAbsolute
            {
                // spacing or a move between two characters: they are no longer where the font puts them
                if s.spacing != 0 || isMoved { s.isNatural = false }
                segment = s
            } else {
                flush()
                segment = Segment(
                    string: "",
                    state: character.state,
                    run: character.run,
                    rotate: character.rotate,
                    scale: scale,
                    origin: pen,
                    isNatural: character.rotate == 0 && scale == 1,
                    end: pen.x,
                    extent: pen.x...pen.x
                )
            }

            segment?.string.append(character.character)
            segment?.glyphs.append(
                contentsOf: shape.glyphs.map {
                    PlacedGlyph(
                        fontName: $0.fontName,
                        glyph: $0.glyph,
                        position: LayerTree.Point(pen.x + $0.offset.x * scale, pen.y + $0.offset.y),
                        scaleX: scale
                    )
                }
            )
            let advance = shape.advance * scale
            let cell = min(pen.x, pen.x + advance)...max(pen.x, pen.x + advance)
            pen.x += advance
            segment?.end = pen.x
            if let extent = segment?.extent {
                segment?.extent = min(extent.lowerBound, cell.lowerBound)...max(extent.upperBound, cell.upperBound)
            }

            let spacing = spacings[index]
            pen.x += spacing
            segment?.spacing = spacing
        }
        flush()
        if !current.runs.isEmpty {
            chunks.append(current)
        }
        return chunks
    }

    /// SVG 2 §11.5.2 "Resolve text length": fits the characters of each element with a `textLength`,
    /// innermost first, by changing the spacing after each of its characters (`spacing`), or by
    /// scaling their advances, the spacing between them and their glyphs (`spacingAndGlyphs`). The
    /// characters after the element move with it. An element whose characters a descendant already
    /// fitted, or that starts a new text chunk within itself, keeps its natural length.
    static func makeFittedSpacing(
        _ lengths: [TextLength],
        characters: [TextCharacter],
        isDrawn: [Bool],
        advances: [LayerTree.Float],
        spacings: [LayerTree.Float]
    )
        -> (spacings: [LayerTree.Float], scales: [LayerTree.Float])
    {
        var spacings = spacings
        var scales = Array(repeating: LayerTree.Float(1), count: characters.count)
        var isFitted = Array(repeating: false, count: characters.count)

        for length in lengths {
            let range = length.range.clamped(to: characters.indices)
            guard !range.contains(where: { isFitted[$0] }),
                !range.dropFirst().contains(where: { characters[$0].x != nil || characters[$0].y != nil })
            else { continue }
            let members = range.filter { isDrawn[$0] }
            guard !members.isEmpty else { continue }
            // the space between consecutive characters: the spacing after one and the dx of the next
            let gaps = zip(members, members.dropFirst()).map { spacings[$0] + characters[$1].dx }
            let natural = members.reduce(0) { $0 + advances[$1] * scales[$1] } + gaps.reduce(0, +)

            switch length.adjust {
            case .spacing:
                guard members.count > 1 else { continue }
                let delta = (length.length - natural) / LayerTree.Float(members.count - 1)
                // the gap follows the last character too, moving the text after the element on
                // (as resvg; within the element only the gaps between its characters count)
                for member in members {
                    spacings[member] += delta
                }
            case .spacingAndGlyphs:
                guard natural > 0 else { continue }
                let scale = length.length / natural
                for member in members {
                    scales[member] *= scale
                }
                for (member, gap) in zip(members, gaps) {
                    spacings[member] += gap * (scale - 1)
                }
            }
            for index in range {
                isFitted[index] = true
            }
        }
        return (spacings, scales)
    }

    /// The glyphs of each character, shaped together while consecutive characters share a font
    /// (across text nodes, with their kerning), each text chunk on its own.
    func makeShapedCharacters(for characters: [TextCharacter]) -> [ShapedCharacter] {
        var result = [ShapedCharacter]()
        var group = [TextCharacter]()
        var groupFont: (LayerTree.TextAttributes, Bool)?

        func shape() {
            guard let (font, ligatures) = groupFont else { return }
            let characters = group.map(\.character)
            let runs = Self.makeShapedText(String(characters), with: font, ligatures: ligatures)
            result.append(contentsOf: Self.makeShapedCharacters(runs, for: characters))
            group = []
        }

        for character in characters {
            var font = makeTextAttributes(with: character.state)
            font.color = .none
            font.anchor = .start
            font.baseline = .auto
            // CSS Text 3 §8.2: letter-spacing turns optional ligatures off
            let key = (font, character.state.letterSpacing == 0)
            let isAbsolute = character.x != nil || character.y != nil
            if let current = groupFont, current.0 == key.0, current.1 == key.1, !isAbsolute {
                group.append(character)
            } else {
                shape()
                groupFont = key
                group = [character]
            }
        }
        shape()
        return result
    }

    /// Every run of the text, each drawn with its own state. A single run is returned as is, several
    /// within a layer; nil when nothing is drawn.
    /// - Parameter isClip: the text is part of a `<clipPath>`: its glyphs are filled white, whatever their paint
    func makeTextContents(from text: DOM.Text, with state: State, isClip: Bool = false) -> LayerTree.Layer.Contents? {
        let chunks = makeTextChunks(for: text, with: state)
        // SVG 2 §8.10: paint servers in objectBoundingBox units fill the whole text's box, so every run
        // of a gradient continues where the previous one ends. Measured only when a run needs it.
        var bounds: LayerTree.Rect??
        func textBounds() -> LayerTree.Rect? {
            if let bounds { return bounds }
            let measured = Self.makeTextBounds(for: chunks, builder: self)
            bounds = .some(measured)
            return measured
        }

        var contents = [LayerTree.Layer.Contents]()
        for chunk in chunks {
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
                let glyphs = run.glyphs?.map {
                    PlacedGlyph(
                        fontName: $0.fontName,
                        glyph: $0.glyph,
                        position: LayerTree.Point($0.position.x + shift, $0.position.y),
                        scaleX: $0.scaleX
                    )
                }
                if let runContents = makeTextRunContents(
                    run.string,
                    glyphs: glyphs,
                    at: point,
                    with: state,
                    rotate: run.rotate,
                    for: text,
                    bounds: textBounds
                ) {
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

    /// `rotate` of a glyph: clockwise in degrees about `point`
    static func makeRotation(_ degrees: LayerTree.Float, about point: LayerTree.Point) -> [LayerTree.Transform] {
        [
            .translate(tx: point.x, ty: point.y),
            .rotate(radians: degrees * .pi / 180),
            .translate(tx: -point.x, ty: -point.y),
        ]
    }

    /// SVG 2 §8.10 bounding box of text: the union of its glyph cells, each run's advance by its font's
    /// ascent and descent (as resvg and browsers measure it, not the ink of the glyphs). Hidden runs
    /// count too. nil when there is nothing to measure, or no CoreText to measure it with.
    func makeTextBounds(for text: DOM.Text, with state: State) -> LayerTree.Rect? {
        guard text.textPath == nil else { return nil }
        return Self.makeTextBounds(for: makeTextChunks(for: text, with: state), builder: self)
    }

    static func makeTextBounds(for chunks: [TextChunk], builder: LayerTree.Builder) -> LayerTree.Rect? {
        #if canImport(CoreText)
        var result: LayerTree.Rect?
        for chunk in chunks {
            let shift = chunk.shift
            for run in chunk.runs {
                let attributes = builder.makeTextAttributes(with: run.state)
                let font = CGProvider.createFont(for: attributes).font
                let ascent = LayerTree.Float(CTFontGetAscent(font))
                let descent = LayerTree.Float(CTFontGetDescent(font))
                let origin = LayerTree.Point(run.origin.x + shift, run.origin.y)
                let baseline = origin.y + makeBaselineOffset(with: attributes, shifts: run.state.baselineShifts)
                let extent = run.horizontalExtent
                var cell = LayerTree.Rect(
                    x: extent.lowerBound + shift,
                    y: baseline - ascent,
                    width: extent.upperBound - extent.lowerBound,
                    height: ascent + descent
                )
                if run.rotate != 0 {
                    cell = cell.applying(
                        makeRotation(run.rotate, about: LayerTree.Point(origin.x, baseline)).toMatrix()
                    )
                }
                result = result.map { $0.union(cell) } ?? cell
            }
        }
        return result
        #else
        return nil
        #endif
    }

    /// One run of characters starting at `point` on the line, shifted to the baseline of its state.
    /// Its fill and stroke follow `paint-order`; `bounds` is the text's box for objectBoundingBox paint.
    /// - Parameter rotate: `rotate` of a single glyph, clockwise in degrees about its origin
    /// - Parameter glyphs: the run's glyphs placed one by one, on the line before the baseline shift;
    ///   nil draws `string` as text from `point`
    func makeTextRunContents(
        _ string: String,
        glyphs: [PlacedGlyph]? = nil,
        at point: LayerTree.Point,
        with state: State,
        rotate: LayerTree.Float = 0,
        for text: DOM.Text? = nil,
        bounds: () -> LayerTree.Rect? = { nil }
    ) -> LayerTree.Layer.Contents? {
        // state already holds the cascaded font-family, font-size, font-weight, font-style and text-anchor
        let att = makeTextAttributes(with: state)
        let baseline = Self.makeBaselineOffset(with: att, shifts: state.baselineShifts)
        var point = point
        point.y += baseline
        let rotation = rotate == 0 ? [] : Self.makeRotation(rotate, about: point)
        let glyphRuns = glyphs.map { Self.makeGlyphRuns($0, attributes: att, baseline: baseline) }

        #if canImport(CoreText)
        // text painted with a paint server or a stroke is drawn as its glyph outlines, through the
        // shape pipeline, so it gets gradients, patterns, strokes and the text's bounding box for free
        if needsOutlines(for: state),
            let outlines = glyphRuns.map(Self.makeGlyphOutlines)
                ?? CGProvider().createPath(from: string, at: point, with: att)
        {
            var state = state
            // glyph outlines are designed for nonzero; fill-rule does not apply to text in browsers
            state.fillRule = .nonzero
            // the outlines are turned rather than drawn in a turned layer: the paint stays in the
            // text's user space, where the text's bounding box is
            var path = outlines.makePath()
            if !rotation.isEmpty {
                path = path.applying(matrix: rotation.toMatrix())
            }
            let shape = LayerTree.Shape.path(path)
            let contents = makeShapeContents(from: shape, with: state, boundingBox: bounds())
            guard let text else { return contents }
            return makePaintedContents(contents, for: text, with: state)
        }
        #endif
        let contents: LayerTree.Layer.Contents
        if let glyphRuns {
            guard !glyphRuns.isEmpty else { return nil }
            if glyphRuns.count == 1 {
                contents = .glyphs(glyphRuns[0])
            } else {
                let layer = LayerTree.Layer()
                glyphRuns.forEach { layer.appendContents(.glyphs($0)) }
                contents = .layer(layer)
            }
        } else {
            contents = .text(string, point, att)
        }
        guard !rotation.isEmpty else { return contents }
        let layer = LayerTree.Layer()
        layer.transform = rotation
        layer.appendContents(contents)
        return .layer(layer)
    }

    /// Placed glyphs in runs of one face, shifted to the baseline
    static func makeGlyphRuns(
        _ glyphs: [PlacedGlyph],
        attributes: LayerTree.TextAttributes,
        baseline: LayerTree.Float
    ) -> [LayerTree.GlyphRun] {
        var runs = [LayerTree.GlyphRun]()
        for glyph in glyphs {
            let position = LayerTree.Point(glyph.position.x, glyph.position.y + baseline)
            if let last = runs.last, last.fontName == glyph.fontName, last.scaleX == glyph.scaleX {
                runs[runs.count - 1].glyphs.append(glyph.glyph)
                runs[runs.count - 1].positions.append(position)
            } else {
                runs.append(
                    LayerTree.GlyphRun(
                        attributes: attributes,
                        fontName: glyph.fontName,
                        glyphs: [glyph.glyph],
                        positions: [position],
                        scaleX: glyph.scaleX
                    )
                )
            }
        }
        return runs
    }

    #if canImport(CoreText)
    static func makeGlyphOutlines(_ runs: [LayerTree.GlyphRun]) -> CGPath? {
        let path = CGMutablePath()
        for run in runs {
            if let outline = CGProvider.createGlyphPath(from: run) {
                path.addPath(outline)
            }
        }
        return path
    }
    #endif

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

    static func makeBaselineOffset(
        with attributes: LayerTree.TextAttributes,
        shifts: [BaselineShiftEntry] = []
    ) -> LayerTree.Float {
        let font = CGProvider.createFont(for: attributes).font
        var offset = makeYOffset(font: font, baseline: attributes.baseline)
        for entry in shifts {
            offset -= makeBaselineShift(entry.shift, font: font, fontSize: entry.fontSize)
        }
        return offset
    }

    /// How far `baseline-shift` raises the text (CSS Inline 3 §4.3, SVG 1.1 §10.9.2): `sub` and
    /// `super` by the font's own subscript and superscript offsets (its OS/2 table), percentages of
    /// the font-size it was declared at.
    static func makeBaselineShift(
        _ shift: DOM.BaselineShift,
        font: CTFont,
        fontSize: LayerTree.Float
    ) -> LayerTree.Float {
        switch shift {
        case .baseline, .inherit:
            return 0
        case .sub:
            return -(makeScriptOffsets(font: font, fontSize: fontSize)?.sub ?? fontSize * 0.2)
        case .super:
            return makeScriptOffsets(font: font, fontSize: fontSize)?.super ?? fontSize / 3
        case .length(.absolute(let value)):
            return value
        case .length(.em(let value)):
            return value * fontSize
        case .length(.percentage(let value)):
            return value / 100 * fontSize
        }
    }

    /// `ySubscriptYOffset` and `ySuperscriptYOffset` of the font's OS/2 table, at `fontSize`
    static func makeScriptOffsets(
        font: CTFont,
        fontSize: LayerTree.Float
    ) -> (sub: LayerTree.Float, super: LayerTree.Float)? {
        guard let table = CTFontCopyTable(font, CTFontTableTag(kCTFontTableOS2), []) as Data?,
            table.count >= 26
        else { return nil }
        func int16(_ offset: Int) -> LayerTree.Float {
            let index = table.startIndex + offset
            return LayerTree.Float(Int16(bitPattern: UInt16(table[index]) << 8 | UInt16(table[index + 1])))
        }
        let unitsPerEm = LayerTree.Float(CTFontGetUnitsPerEm(font))
        guard unitsPerEm > 0 else { return nil }
        return (int16(16) / unitsPerEm * fontSize, int16(24) / unitsPerEm * fontSize)
    }
    #else
    static func makeAdvance(for text: String, with attributes: LayerTree.TextAttributes) -> LayerTree.Float {
        0
    }

    static func makeBaselineOffset(
        with attributes: LayerTree.TextAttributes,
        shifts: [BaselineShiftEntry] = []
    ) -> LayerTree.Float {
        // no font metrics: only the shifts that are lengths
        shifts.reduce(0) { offset, entry in
            switch entry.shift {
            case .length(.absolute(let value)): offset - value
            case .length(.em(let value)): offset - value * entry.fontSize
            case .length(.percentage(let value)): offset - value / 100 * entry.fontSize
            case .baseline, .inherit, .sub, .super: offset
            }
        }
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

    /// How far down the glyphs move so that `baseline` of the font sits on the text's `y`, from the
    /// font's ascent, descent and x-height, as resvg and browsers derive the baselines a font does
    /// not list (CSS Inline 3 §4.2).
    static func makeYOffset(font: CTFont, baseline: DOM.TextBaseline) -> LayerTree.Float {
        let ascent = LayerTree.Float(CTFontGetAscent(font))
        let descent = LayerTree.Float(CTFontGetDescent(font))
        switch baseline {
        case .auto, .alphabetic, .inherit:
            return 0
        case .textBeforeEdge:
            return ascent
        case .textAfterEdge, .ideographic:
            return -descent
        case .central:
            // the middle of the em box
            return (ascent - descent) / 2
        case .middle:
            return LayerTree.Float(CTFontGetXHeight(font)) / 2
        case .hanging:
            return ascent * 0.8
        case .mathematical:
            return ascent * 0.5
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
