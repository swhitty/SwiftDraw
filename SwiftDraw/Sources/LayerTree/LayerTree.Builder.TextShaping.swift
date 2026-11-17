//
//  LayerTree.Builder.TextShaping.swift
//  SwiftDraw
//
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

import SwiftDrawDOM
import Foundation
#if canImport(CoreText)
import CoreText
#endif

// Text is laid out in Swift: the shaper only says which glyphs a string becomes in a font, where
// the font puts them (with its kerning) and which characters they come from. Spacing, per-character
// positions and anchoring are applied to those positions by the builder.
extension LayerTree.Builder {

    /// A glyph of shaped text
    struct ShapedGlyph: Equatable {
        var glyph: UInt16
        /// its origin along the line from the start of the text, kerned, y up (marks may be raised)
        var x: LayerTree.Float
        var y: LayerTree.Float = 0
        var advance: LayerTree.Float
        /// the UTF-16 offset in the text of the character it comes from
        var index: Int
    }

    /// Glyphs of one face, in line order
    struct ShapedRun: Equatable {
        /// PostScript name of the face: a requested font, or one the shaper fell back to
        var fontName: String
        var glyphs: [ShapedGlyph]
    }

    /// A glyph of a character, about the character's origin on the baseline (y down)
    struct CharacterGlyph: Equatable {
        var fontName: String
        var glyph: UInt16
        var offset: LayerTree.Point
    }

    /// A typographic character (grapheme cluster) of shaped text: its glyphs and its advance. A
    /// character drawn by the glyph of a ligature that starts earlier has none, and no advance.
    struct ShapedCharacter: Equatable {
        var advance: LayerTree.Float
        var glyphs: [CharacterGlyph]
    }

    /// The glyphs of each character of `text` (grapheme clusters, as Swift's `Character`), from the
    /// glyphs the shaper produced for it.
    static func makeShapedCharacters(_ runs: [ShapedRun], for text: String) -> [ShapedCharacter] {
        makeShapedCharacters(runs, for: Array(text))
    }

    /// The glyphs of each of `characters`, shaped as one string. The characters are taken as given:
    /// joined, two of them can merge into one grapheme (a tspan starting with a combining mark),
    /// and each still gets its own glyphs.
    static func makeShapedCharacters(_ runs: [ShapedRun], for characters: [Character]) -> [ShapedCharacter] {
        // UTF-16 offset of the start of each character
        var starts = [Int]()
        var offset = 0
        for character in characters {
            starts.append(offset)
            offset += character.utf16.count
        }
        var glyphs = Array(repeating: [(String, ShapedGlyph)](), count: starts.count)
        for run in runs {
            for glyph in run.glyphs {
                // the last character starting at or before the glyph's index
                var lower = 0, upper = starts.count
                while upper - lower > 1 {
                    let mid = (lower + upper) / 2
                    if starts[mid] <= glyph.index { lower = mid } else { upper = mid }
                }
                guard lower < glyphs.count else { continue }
                glyphs[lower].append((run.fontName, glyph))
            }
        }
        // a character's glyphs are placed about its leftmost one; a mark with no advance of its own (a
        // combining character in a tspan of its own) is placed from where the characters before it
        // end, so it keeps its place over its base
        var end = LayerTree.Float(0)
        return glyphs.map { glyphs in
            let advance = glyphs.reduce(0) { $0 + $1.1.advance }
            let start = advance == 0 ? end : glyphs.map(\.1.x).min() ?? end
            end += advance
            return ShapedCharacter(
                advance: advance,
                glyphs: glyphs.map {
                    CharacterGlyph(fontName: $0.0, glyph: $0.1.glyph, offset: LayerTree.Point($0.1.x - start, -$0.1.y))
                }
            )
        }
    }

    /// CSS Text 3 §8.2: `letter-spacing` is not applied to cursive scripts, whose letters join
    static func isCursive(_ character: Character) -> Bool {
        character.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x0600...0x06FF, 0x0700...0x074F, 0x0750...0x077F, 0x07C0...0x07FF,
                0x0860...0x086F, 0x08A0...0x08FF, 0x1800...0x18AF,
                0xFB50...0xFDFF, 0xFE70...0xFEFF:
                return true
            default:
                return false
            }
        }
    }

    /// CSS Text 3 §8.1: the word-separator characters `word-spacing` is added after
    static func isWordSeparator(_ character: Character) -> Bool {
        switch character {
        case " ", "\u{00A0}", "\u{1361}", "\u{10100}", "\u{10101}", "\u{1039F}", "\u{1091F}":
            return true
        default:
            return false
        }
    }

    #if canImport(CoreText)
    /// Shapes `text` in the font of `attributes`: its glyphs in line order, in runs of one face each.
    /// The only place text is shaped; `makeAdvance` and `makeYOffset` are the only other places that
    /// ask CoreText for widths and metrics.
    /// - Parameter ligatures: false keeps only the ligatures the script requires
    static func makeShapedText(
        _ text: String,
        with attributes: LayerTree.TextAttributes,
        ligatures: Bool = true
    ) -> [ShapedRun] {
        let font = CGProvider.createFont(for: attributes)
        let line = text.toLine(font: font.font, ligatures: ligatures)
        let glyphRuns = CTLineGetGlyphRuns(line)
        var runs = [ShapedRun]()
        // synthesized bold widens each glyph's advance, moving the glyphs after it
        var boldAdvance = CGFloat(0)
        for runIndex in 0..<CFArrayGetCount(glyphRuns) {
            let run = unsafeBitCast(CFArrayGetValueAtIndex(glyphRuns, runIndex), to: CTRun.self)
            let face = text.resolveRunFont(attributes: CTRunGetAttributes(run) as NSDictionary, fallback: font.font)
            let boldOffset = font.synthesis(for: face).contains(.bold) ? String.syntheticBoldOffset(for: face) : 0
            let count = CTRunGetGlyphCount(run)
            guard count > 0 else { continue }
            var ids = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            var advances = [CGSize](repeating: .zero, count: count)
            var indices = [CFIndex](repeating: 0, count: count)
            let all = CFRange(location: 0, length: 0)
            CTRunGetGlyphs(run, all, &ids)
            CTRunGetPositions(run, all, &positions)
            CTRunGetAdvances(run, all, &advances)
            CTRunGetStringIndices(run, all, &indices)
            var glyphs = [ShapedGlyph]()
            for i in 0..<count {
                glyphs.append(
                    ShapedGlyph(
                        glyph: UInt16(ids[i]),
                        x: LayerTree.Float(positions[i].x + boldAdvance),
                        y: LayerTree.Float(positions[i].y),
                        advance: LayerTree.Float(advances[i].width + boldOffset),
                        index: indices[i]
                    )
                )
                boldAdvance += boldOffset
            }
            runs.append(ShapedRun(fontName: CTFontCopyPostScriptName(face) as String, glyphs: glyphs))
        }
        return runs
    }
    #else
    static func makeShapedText(
        _ text: String,
        with attributes: LayerTree.TextAttributes,
        ligatures: Bool = true
    ) -> [ShapedRun] {
        []
    }
    #endif
}
