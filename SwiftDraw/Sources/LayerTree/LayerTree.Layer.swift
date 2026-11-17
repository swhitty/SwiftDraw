//
//  LayerTree.Layer.swift
//  SwiftDraw
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
import struct Foundation.Data

extension LayerTree {
    final class Layer: Hashable {
        var `class`: String? = nil
        var contents: [Contents] = []
        var opacity: Float = 1.0
        var transform: [Transform] = []
        var clip: [ClipShape] = []
        var clipRule: FillRule?
        var clipUnits: ClipUnits = .userSpaceOnUse
        var mask: Layer?
        // how this layer masks when it is used as a mask
        var maskType: MaskType = .luminance
        /// The mask stands for a clip path one clipping path cannot express (SD8): renderers
        /// without masks may draw the content unclipped instead of dropping it.
        var maskIsClip = false
        var filters: [FilterPrimitive] = []
        var filterRegion = FilterRegion()
        /// The elements `<feImage>` primitives of `filters` draw, by primitive index (Filter Effects 1 §9.15),
        /// in the layer's user space
        var filterImages: [Int: Layer] = [:]
        /// The contents are one shape's fill, stroke and markers in a `paint-order` other than the
        /// default, with the shape split into a fill-only and a stroke-only `.shape`.
        var isPaintOrdered = false
        /// The bounding box of the text this layer draws, in its user space (SVG 2 §8.10), where a
        /// filter needs it for an objectBoundingBox region. nil when not measured.
        var textBounds: Rect?

        enum MaskType: Hashable {
            case luminance
            /// luminance of the contents' colours in linear light (`color-interpolation: linearRGB`)
            case linearLuminance
            case alpha
        }

        enum Contents: Hashable {
            case shape(Shape, StrokeAttributes, FillAttributes)
            case image(Image)
            case text(String, Point, TextAttributes)
            /// glyphs placed one by one, where the text is not laid out as its font would on its own
            case glyphs(GlyphRun)
            case layer(Layer)
        }

        func appendContents(_ contents: Contents) {
            switch contents {
            case .layer(let l):
                //if layer is simple, we can ignore all other properties
                if let simple = l.simpleContents {
                    self.contents.append(simple)
                } else {
                    self.contents.append(.layer(l))
                }
            default:
                self.contents.append(contents)
            }
        }

        var simpleContents: Contents? {
            guard contents.count == 1,
                let first = contents.first,
                `class` == nil,
                opacity == 1.0,
                transform == [],
                clip == [],
                mask == nil,
                filters == [],
                filterImages.isEmpty,
                textBounds == nil
            else { return nil }

            return first
        }

        func hash(into hasher: inout Hasher) {
            `class`.hash(into: &hasher)
            opacity.hash(into: &hasher)
            transform.hash(into: &hasher)
            clip.hash(into: &hasher)
            clipUnits.hash(into: &hasher)
            mask.hash(into: &hasher)
            maskIsClip.hash(into: &hasher)
            maskType.hash(into: &hasher)
            filters.hash(into: &hasher)
            filterRegion.hash(into: &hasher)
            filterImages.hash(into: &hasher)
            isPaintOrdered.hash(into: &hasher)
            textBounds.hash(into: &hasher)
        }

        static func == (lhs: Layer, rhs: Layer) -> Bool {
            return lhs.class == rhs.class && lhs.contents == rhs.contents && lhs.opacity == rhs.opacity
                && lhs.transform == rhs.transform && lhs.clip == rhs.clip && lhs.clipRule == rhs.clipRule
                && lhs.clipUnits == rhs.clipUnits && lhs.mask == rhs.mask && lhs.maskIsClip == rhs.maskIsClip
                && lhs.maskType == rhs.maskType && lhs.filters == rhs.filters && lhs.filterRegion == rhs.filterRegion
                && lhs.filterImages == rhs.filterImages && lhs.isPaintOrdered == rhs.isPaintOrdered
                && lhs.textBounds == rhs.textBounds
        }
    }

    struct StrokeAttributes: Hashable {
        var color: Stroke
        var width: Float
        var cap: LineCap
        var join: LineJoin
        var miterLimit: Float
        var dashArray: [Float] = []
        var dashOffset: Float = 0
        /// stroke-opacity for paint servers; a colour carries it in its alpha.
        var opacity: Float = 1.0
        /// The box objectBoundingBox paint servers resolve against, when it is not the shape's own
        /// (the whole text for each of its runs, SVG 2 §8.10)
        var boundingBox: Rect?

        enum Stroke: Hashable {
            case color(Color)
            case pattern(Pattern)
            case linearGradient(LinearGradient)
            case radialGradient(RadialGradient)

            static var none: Stroke { .color(.none) }
        }
    }

    struct FillAttributes: Hashable {
        var fill: Fill = .color(.none)
        var opacity: Float = 1.0
        var rule: FillRule
        /// The box objectBoundingBox paint servers resolve against, when it is not the shape's own
        /// (the whole text for each of its runs, SVG 2 §8.10)
        var boundingBox: Rect?

        init(color: Color, rule: FillRule) {
            self.fill = .color(color)
            self.rule = rule
        }

        init(pattern: Pattern, rule: FillRule, opacity: Float) {
            self.fill = .pattern(pattern)
            self.rule = rule
            self.opacity = opacity
        }

        init(linear gradient: LinearGradient, rule: FillRule, opacity: Float) {
            self.fill = .linearGradient(gradient)
            self.rule = rule
            self.opacity = opacity
        }

        init(radial gradient: RadialGradient, rule: FillRule, opacity: Float) {
            self.fill = .radialGradient(gradient)
            self.rule = rule
            self.opacity = opacity
        }

        enum Fill: Hashable {
            case color(Color)
            case pattern(Pattern)
            case linearGradient(LinearGradient)
            case radialGradient(RadialGradient)

            static var none: Fill { .color(.none) }
        }
    }

    /// Glyphs of one face, each at its own origin: text the builder laid out character by character
    /// (spacing, per-character positions) from the font's shaping, so its kerning and contextual forms
    /// are kept. Renderers draw a run as one path of its glyph outlines.
    struct GlyphRun: Hashable {
        /// the fill colour and the requested font, size, weight and slant
        var attributes: TextAttributes
        /// PostScript name of the face the glyph ids are in: one of the requested fonts, or one the
        /// shaper fell back to for characters they lack
        var fontName: String
        var glyphs: [UInt16]
        /// the origin of each glyph on the baseline, in user space
        var positions: [Point]
        /// `lengthAdjust="spacingAndGlyphs"`: each glyph is stretched horizontally about its origin
        var scaleX: Float = 1
    }

    struct TextAttributes: Hashable {
        var color: Color
        var font: [Font]
        var size: Float
        /// CSS weight (1–1000) and slant, used to pick a system font's face and to decide whether its
        /// bold or oblique is synthesized. `@font-face` fonts are already the matching face.
        var weight: Int = 400
        var isItalic: Bool = false
        var anchor: DOM.TextAnchor
        var baseline: DOM.TextBaseline

        enum Font: Hashable {
            case truetype(Data)
            /// A family name ("Helvetica"), or a face's PostScript name ("Helvetica-Bold")
            case name(String)
            /// One installed face by PostScript name, from `local()` in `@font-face`: used as named,
            /// never re-weighted
            case postScript(String)
            /// An `@font-face` face drawn with synthesized bold or oblique, because it lacks the weight or
            /// slant asked for (CSS Fonts 4 §5.2, `font-synthesis`)
            indirect case synthesized(Font, FontSynthesis)
        }
    }

    /// Faux bold and oblique, drawn on a face's glyph outlines as WebKit does: bold adds a copy of each
    /// glyph offset horizontally by 1/36 of the font size (and widens its advance as much), oblique skews
    /// each glyph by 14° about the baseline.
    struct FontSynthesis: OptionSet, Hashable {
        let rawValue: Int
        static let bold = FontSynthesis(rawValue: 1 << 0)
        static let oblique = FontSynthesis(rawValue: 1 << 1)

        /// Bold is synthesized from a face lighter than 600 when 600 or heavier is asked for
        static let boldThreshold = 600
        /// The synthesized bold offset, as a fraction of the font size
        static let boldOffsetRatio: Float = 1 / 36
        /// The synthesized oblique angle, in degrees
        static let obliqueAngle: Float = 14

        /// The synthesis needed to draw a face of `faceWeight` and slant as one of `weight` and slant
        init(weight: Int, isItalic: Bool, faceWeight: Int, faceIsItalic: Bool) {
            self = []
            if weight >= Self.boldThreshold && faceWeight < Self.boldThreshold { insert(.bold) }
            if isItalic && !faceIsItalic { insert(.oblique) }
        }

        init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }
}

extension LayerTree.Layer.Contents: CustomDebugStringConvertible {

    var debugDescription: String {
        switch self {
        case .image:
            return "image"
        case .layer(let l):
            return "layer-\(l.contents.map(\.debugDescription).joined(separator: ", "))"
        case .shape(let s, _, _):
            return "shape-\(s.debugDescription)"
        case .text:
            return "text"
        case .glyphs:
            return "glyphs"
        }
    }
}

extension LayerTree.Shape: CustomDebugStringConvertible {

    var debugDescription: String {
        switch self {
        case .ellipse: return "ellipse"
        case .rect: return "rect"
        case .line: return "line"
        case .path: return "path"
        case .polygon: return "polygon"
        }
    }
}
