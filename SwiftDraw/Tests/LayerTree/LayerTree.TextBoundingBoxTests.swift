//
//  LayerTree.TextBoundingBoxTests.swift
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

import Foundation
import SwiftDrawDOM
@testable import SwiftDraw
import Testing
#if canImport(CoreText)
import CoreText
#endif

/// The bounding box of text (SVG 2 §8.10) for paint servers and clips, stroke attributes and
/// paint-order on outlined text, and exact cubics for quadratic glyph outlines
struct LayerTreeTextBoundingBoxTests {

    private func parse(_ body: String) throws -> DOM.SVG {
        try DOM.SVG.parse(
            xml: """
                <svg xmlns="http://www.w3.org/2000/svg" width="200" height="200" font-family="Helvetica" font-size="20">
                  <linearGradient id="g"><stop offset="0" stop-color="red"/><stop offset="1" stop-color="blue"/></linearGradient>
                  \(body)
                </svg>
                """
        )
    }

    private func shapes(in layer: LayerTree.Layer) -> [(LayerTree.StrokeAttributes, LayerTree.FillAttributes)] {
        layer.contents.flatMap { contents -> [(LayerTree.StrokeAttributes, LayerTree.FillAttributes)] in
            switch contents {
            case let .shape(_, stroke, fill): [(stroke, fill)]
            case .layer(let child): shapes(in: child)
            default: []
            }
        }
    }

    private func layers(in layer: LayerTree.Layer) -> [LayerTree.Layer] {
        [layer]
            + layer.contents.flatMap { contents -> [LayerTree.Layer] in
                guard case .layer(let child) = contents else { return [] }
                return layers(in: child)
            }
    }

    @Test
    func shapeContentsKeepAnExplicitBoundingBox() throws {
        let svg = try parse("")
        let builder = LayerTree.Builder(svg: svg)
        var state = LayerTree.Builder.State()
        state.fill = .url(try #require(URL(string: "#g")))
        state.stroke = .url(try #require(URL(string: "#g")))
        let box = LayerTree.Rect(x: 0, y: 0, width: 100, height: 50)
        let shape = LayerTree.Shape.rect(within: LayerTree.Rect(x: 10, y: 10, width: 10, height: 10), radii: .zero)

        guard case let .shape(_, stroke, fill) = builder.makeShapeContents(from: shape, with: state, boundingBox: box),
            case let .shape(_, plainStroke, plainFill) = builder.makeShapeContents(from: shape, with: state)
        else {
            Issue.record("expected shapes")
            return
        }
        #expect(fill.boundingBox == box)
        #expect(stroke.boundingBox == box)
        #expect(plainFill.boundingBox == nil)
        #expect(plainStroke.boundingBox == nil)
    }

    @Test
    func objectBoundingBoxPaintResolvesAgainstTheGivenBox() throws {
        let svg = try parse("")
        let builder = LayerTree.Builder(svg: svg)
        var state = LayerTree.Builder.State()
        state.fill = .url(try #require(URL(string: "#g")))
        let shape = LayerTree.Shape.rect(within: LayerTree.Rect(x: 10, y: 10, width: 10, height: 10), radii: .zero)
        let layer = LayerTree.Layer()
        layer.appendContents(
            builder.makeShapeContents(
                from: shape,
                with: state,
                boundingBox: LayerTree.Rect(x: 0, y: 0, width: 100, height: 50)
            )
        )

        let generator = LayerTree.CommandGenerator(
            provider: LayerTreeProvider(),
            size: .init(200, 200),
            options: .default
        )
        let commands = generator.renderCommands(for: layer, colorConverter: .default)
        // the gradient's unit square maps onto the given box, not the 10×10 shape
        #expect(commands.contains { if case .scale(100, 50) = $0 { true } else { false } })
        #expect(!commands.contains { if case .scale(10, 10) = $0 { true } else { false } })
    }

    #if canImport(CoreText)
    @Test
    func textBoundsAreTheUnionOfItsGlyphCells() throws {
        let svg = try parse(#"<text x="10" y="100">Te<tspan font-size="40">xt</tspan></text>"#)
        let text = try #require(svg.childElements.first as? DOM.Text)
        let builder = LayerTree.Builder(svg: svg)
        let state = builder.createState(for: text, inheriting: .init())
        let bounds = try #require(builder.makeTextBounds(for: text, with: state))

        let chunks = builder.makeTextChunks(for: text, with: state)
        let runs = chunks.flatMap(\.runs)
        try #require(runs.count == 2)
        let large = CGProvider.createFont(for: builder.makeTextAttributes(with: runs[1].state)).font
        #expect(bounds.x == 10)
        #expect(abs(bounds.width - (runs[1].origin.x + runs[1].advance - 10)) < 0.001)
        // the larger run sets the height: its ascent above the baseline, its descent below
        #expect(abs(bounds.y - (100 - Float(CTFontGetAscent(large)))) < 0.001)
        #expect(abs(bounds.y + bounds.height - (100 + Float(CTFontGetDescent(large)))) < 0.001)
    }

    @Test
    func everyRunOfTextIsPaintedAcrossTheWholeText() throws {
        let svg = try parse(#"<text x="10" y="100" fill="url(#g)">Te<tspan font-weight="bold">xt</tspan></text>"#)
        let text = try #require(svg.childElements.first as? DOM.Text)
        let builder = LayerTree.Builder(svg: svg)
        // the text inherits the root's font-family and font-size
        let root = builder.createState(for: svg, inheriting: .init())
        let bounds = try #require(
            builder.makeTextBounds(for: text, with: builder.createState(for: text, inheriting: root))
        )
        let fills = shapes(in: builder.makeLayer()).map(\.1)
        #expect(fills.count == 2)
        #expect(fills.allSatisfy { $0.boundingBox == bounds })
    }

    @Test
    func rotatedGlyphsArePaintedInTheTextsSpace() throws {
        // the outlines are turned, not drawn in a turned layer, so the gradient does not turn with them
        let layer = LayerTree.Builder(svg: try parse(#"<text x="10" y="100" fill="url(#g)" rotate="0 30">AB</text>"#))
            .makeLayer()
        #expect(shapes(in: layer).count == 2)
        let transforms = layers(in: layer).map(\.transform)
        #expect(transforms.allSatisfy { $0.isEmpty })
    }

    @Test
    func strokeAttributesReachTheOutlines() throws {
        let layer = LayerTree.Builder(
            svg: try parse(
                #"<text x="10" y="100" stroke="blue" stroke-width="3" stroke-dasharray="2 1" stroke-linejoin="round" stroke-opacity="0.5">Text</text>"#
            )
        ).makeLayer()
        let stroke = try #require(shapes(in: layer).first?.0)
        #expect(stroke.width == 3)
        #expect(stroke.join == .round)
        #expect(stroke.dashArray == [2, 1])
        #expect(stroke.color == .color(.rgba(r: 0, g: 0, b: 1, a: 0.5, space: .srgb)))
    }

    @Test
    func paintOrderDrawsTheStrokeOfTextFirst() throws {
        let layer = LayerTree.Builder(
            svg: try parse(#"<text x="10" y="100" fill="green" stroke="blue" paint-order="stroke">Text</text>"#)
        ).makeLayer()
        let ordered = try #require(layers(in: layer).first { $0.isPaintOrdered })
        let painted = shapes(in: ordered)
        try #require(painted.count == 2)
        #expect(painted[0].1.fill == .color(.none))
        #expect(painted[1].0.color == .color(.none))
    }

    @Test
    func paintOrderOnATspanAppliesToItsRunOnly() throws {
        let layer = LayerTree.Builder(
            svg: try parse(
                #"<text x="10" y="100" fill="green" stroke="blue">Te<tspan paint-order="stroke fill">xt</tspan></text>"#
            )
        ).makeLayer()
        #expect(layers(in: layer).filter(\.isPaintOrdered).count == 1)
        #expect(shapes(in: layer).count == 3)
    }

    @Test
    func objectBoundingBoxClipOnTextUsesItsBounds() throws {
        let svg = try parse(
            """
            <clipPath id="c" clipPathUnits="objectBoundingBox"><rect width="0.5" height="1"/></clipPath>
            <text x="10" y="100" clip-path="url(#c)">Text</text>
            """
        )
        #expect(layers(in: LayerTree.Builder(svg: svg).makeLayer()).contains { !$0.clip.isEmpty })
    }

    @Test
    func quadraticCurvesBecomeExactCubics() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addQuadCurve(to: CGPoint(x: 30, y: 0), control: CGPoint(x: 15, y: 30))
        path.closeSubpath()
        path.addQuadCurve(to: CGPoint(x: 6, y: 0), control: CGPoint(x: 3, y: 3))

        #expect(
            path.makePath().segments == [
                .move(to: LayerTree.Point(0, 0)),
                .cubic(
                    to: LayerTree.Point(30, 0),
                    control1: LayerTree.Point(10, 20),
                    control2: LayerTree.Point(20, 20)
                ),
                .close,
                // after a close the curve starts from the start of the subpath
                .cubic(to: LayerTree.Point(6, 0), control1: LayerTree.Point(2, 2), control2: LayerTree.Point(4, 2)),
            ]
        )
    }
    #endif
}
