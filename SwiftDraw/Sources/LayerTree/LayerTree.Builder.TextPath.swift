//
//  LayerTree.Builder.TextPath.swift
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
//

import SwiftDrawDOM
import Foundation
#if canImport(CoreText)
import CoreText
#endif

// SVG 1.1 §10.13 text on a path: each glyph is placed at the point on the path at the midpoint of
// its advance, rotated to the path's direction there. Glyphs whose midpoint is off either end of the
// path are not drawn. The placed glyphs become outlines, so every renderer draws them as shapes.

extension LayerTree.Builder {

    /// The path text is laid out along: SVG 2 `path`, else the shape `href` references, in the user
    /// space of the `<text>` (with the referenced element's own `transform` applied).
    func makeTextPathGeometry(for textPath: DOM.TextPath) -> LayerTree.Path? {
        if let path = textPath.path {
            return try? Self.createPath(from: path)
        }
        guard let id = textPath.href?.fragmentID,
            let element = svg.firstGraphicsElement(with: id),
            let shape = Self.makeShape(from: element)
        else { return nil }

        let path = shape.path
        let transform = createTransforms(from: DOM.presentationAttributes(for: element, styles: svg.styles))
        guard !transform.isEmpty else { return path }
        return path.applying(matrix: transform.toMatrix())
    }

    /// The distance along the path the text starts at, before `text-anchor` shifts it
    static func makeStartOffset(_ offset: DOM.TextPath.Offset?, pathLength: LayerTree.Float) -> LayerTree.Float {
        switch offset {
        case .length(let length):
            return LayerTree.Float(length)
        case .percentage(let percent):
            return LayerTree.Float(percent) / 100 * pathLength
        case nil:
            return 0
        }
    }

    /// Where a glyph goes: about its own origin on the baseline (y down), shifted by `dy`
    /// perpendicular to the path, it is centred on the point at `midpoint` along the path and turned
    /// to the path's direction there. nil when the midpoint is off either end of the path.
    static func makeGlyphTransform(
        midpoint: LayerTree.Float,
        advance: LayerTree.Float,
        dy: LayerTree.Float = 0,
        along measure: LayerTree.Path.Measure,
        side: DOM.TextPath.Side = .left
    ) -> LayerTree.Transform.Matrix? {
        // SVG 2 side="right": the path is traced from its end, so the text sits on its other side
        let distance = side == .right ? measure.length - midpoint : midpoint
        guard midpoint >= 0, midpoint <= measure.length,
            let (point, tangent) = measure.position(at: distance)
        else { return nil }
        let angle = side == .right ? tangent + .pi : tangent

        return LayerTree.Transform.translate(tx: -advance / 2, ty: dy).toMatrix()
            .concatenated(LayerTree.Transform.rotate(radians: angle).toMatrix())
            .concatenated(LayerTree.Transform.translate(tx: point.x, ty: point.y).toMatrix())
    }

    /// - Parameter isClip: the text is part of a `<clipPath>`: its glyphs are filled white, whatever their paint
    func makeTextPathContents(
        from textPath: DOM.TextPath,
        with state: State,
        isClip: Bool = false
    ) -> LayerTree.Layer.Contents? {
        #if canImport(CoreText)
        guard let path = makeTextPathGeometry(for: textPath) else { return nil }
        let measure = LayerTree.Path.Measure(path)
        guard measure.length > 0 else { return nil }

        // the runs of text, each with the state of its innermost <tspan>, laid out one after the other.
        // Like WebKit, glyphs on a path are not kerned: each advances by its own width.
        struct Run {
            var state: State
            var glyphs: [String.Glyph]
            var x: CGFloat
            var dy: LayerTree.Float
        }
        var runs = [Run]()
        var width = CGFloat(0)

        func layout(_ textRuns: [DOM.TextRun], state: State) {
            for textRun in textRuns {
                switch textRun {
                case .text(let string):
                    // a font-size of 0 draws nothing (CoreText would fall back to its default size)
                    guard !string.isEmpty, state.fontSize > 0 else { continue }
                    let attributes = makeTextAttributes(with: state)
                    let font = CGProvider.createFont(for: attributes)
                    let glyphs = string.toGlyphs(
                        font: font.font,
                        kerning: false,
                        synthesis: font.synthesis(for:)
                    )
                    runs.append(
                        Run(
                            state: state,
                            glyphs: glyphs,
                            x: width,
                            dy: Self.makeBaselineOffset(with: attributes, shifts: state.baselineShifts)
                        )
                    )
                    width += glyphs.reduce(0) { $0 + $1.advance }
                case .span(let span):
                    // a <tspan> with display="none" is not drawn and takes no space
                    let spanState = createState(for: span, inheriting: state)
                    guard spanState.display != .none else { continue }
                    layout(span.runs, state: spanState)
                }
            }
        }

        let pathState = createState(for: textPath, inheriting: state)
        layout(textPath.runs, state: pathState)

        // the anchor of the text chunk is that of the <textPath>
        let start =
            Self.makeStartOffset(textPath.startOffset, pathLength: measure.length)
            + Self.makeXOffset(width: Double(width), anchor: pathState.textAnchor)
        let side = textPath.side ?? .left

        let layer = LayerTree.Layer()
        for run in runs where run.state.visibility == .visible {
            let outlines = CGMutablePath()
            for glyph in run.glyphs {
                let midpoint = start + LayerTree.Float(run.x + glyph.x + glyph.advance / 2)
                guard
                    let m = Self.makeGlyphTransform(
                        midpoint: midpoint,
                        advance: LayerTree.Float(glyph.advance),
                        dy: run.dy,
                        along: measure,
                        side: side
                    )
                else { continue }
                let transform = CGAffineTransform(
                    a: CGFloat(m.a),
                    b: CGFloat(m.b),
                    c: CGFloat(m.c),
                    d: CGFloat(m.d),
                    tx: CGFloat(m.tx),
                    ty: CGFloat(m.ty)
                )
                outlines.addPath(glyph.path, transform: transform)
            }
            guard !outlines.isEmpty else { continue }
            var state = run.state
            if isClip {
                state.fill = .color(.keyword(.white))
                state.fillOpacity = 1
                state.fillRule = .nonzero
                state.stroke = .color(.none)
            }
            layer.appendContents(makeShapeContents(from: .path(outlines.makePath()), with: state))
        }
        return layer.contents.isEmpty ? nil : .layer(layer)
        #else
        return nil
        #endif
    }
}
