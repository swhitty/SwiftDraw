//
//  LayerTree.TextPathTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 3/6/17.
//  Copyright 2020 WhileLoop Pty Ltd. All rights reserved.
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
import XCTest
@testable import SwiftDraw

@testable import SwiftDraw
@testable import SwiftDrawDOM
import Foundation
import Testing

struct LayerTreePathMeasureTests {

    typealias Point = LayerTree.Point

    private func path(_ segments: LayerTree.Path.Segment...) -> LayerTree.Path {
        LayerTree.Path(segments)
    }

    @Test
    func lineLength() {
        let measure = LayerTree.Path.Measure(path(.move(to: Point(0, 0)), .line(to: Point(30, 40))))
        #expect(measure.length == 50)
    }

    @Test
    func moveDoesNotAddLength() {
        let measure = LayerTree.Path.Measure(path(
            .move(to: Point(0, 0)), .line(to: Point(10, 0)),
            .move(to: Point(100, 100)), .line(to: Point(100, 20))
        ))
        #expect(measure.length == 90)
        #expect(measure.position(at: 10)?.point == Point(10, 0))
        #expect(measure.position(at: 10.5)?.point == Point(100, 99.5))
    }

    @Test
    func closeAddsTheLineBackToTheStart() {
        let measure = LayerTree.Path.Measure(path(
            .move(to: Point(0, 0)), .line(to: Point(10, 0)), .line(to: Point(10, 10)), .close
        ))
        #expect(abs(measure.length - (20 + Float(200).squareRoot())) < 0.0001)
    }

    @Test
    func circleLength() {
        let circle = LayerTree.Shape.ellipse(within: LayerTree.Rect(x: 0, y: 0, width: 100, height: 100)).path
        let measure = LayerTree.Path.Measure(circle)
        #expect(abs(measure.length - 100 * .pi) < 0.05)
    }

    @Test(arguments: [
        (0, Point(0, 0), 0),
        (5, Point(5, 0), 0),
        (10, Point(10, 0), 0),
        (15, Point(10, 5), Float.pi / 2),
        (20, Point(10, 10), Float.pi / 2)
    ] as [(Float, Point, Float)])
    func positionAndAngle(distance: Float, point: Point, angle: Float) throws {
        let measure = LayerTree.Path.Measure(path(.move(to: Point(0, 0)), .line(to: Point(10, 0)), .line(to: Point(10, 10))))
        let position = try #require(measure.position(at: distance))
        #expect(position.point == point)
        #expect(abs(position.angle - angle) < 0.0001)
    }

    @Test(arguments: [-0.1, 20.1] as [Float])
    func positionOffTheEndsIsNil(distance: Float) {
        let measure = LayerTree.Path.Measure(path(.move(to: Point(0, 0)), .line(to: Point(10, 0)), .line(to: Point(10, 10))))
        #expect(measure.position(at: distance) == nil)
    }

    @Test
    func emptyPathHasNoPositions() {
        let measure = LayerTree.Path.Measure(path(.move(to: Point(5, 5))))
        #expect(measure.length == 0)
        #expect(measure.position(at: 0) == nil)
    }

    @Test
    func curveTangentFollowsTheCurve() throws {
        // a quarter circle-ish curve from heading right to heading down
        let measure = LayerTree.Path.Measure(path(
            .move(to: Point(0, 0)),
            .cubic(to: Point(100, 100), control1: Point(55, 0), control2: Point(100, 45))
        ))
        let start = try #require(measure.position(at: 0.01))
        let end = try #require(measure.position(at: measure.length))
        #expect(abs(start.angle) < 0.05)
        #expect(abs(end.angle - .pi / 2) < 0.05)
        #expect(end.point == Point(100, 100))
    }
}

struct LayerTreeTextPathTests {

    typealias Builder = LayerTree.Builder
    typealias Point = LayerTree.Point

    @Test(arguments: [
        (nil, 0),
        (.length(25), 25),
        (.length(-10), -10),
        (.percentage(50), 100),
        (.percentage(12.5), 25)
    ] as [(DOM.TextPath.Offset?, Float)])
    func startOffset(offset: DOM.TextPath.Offset?, expected: Float) {
        #expect(Builder.makeStartOffset(offset, pathLength: 200) == expected)
    }

    private let line = LayerTree.Path.Measure(LayerTree.Path([.move(to: Point(0, 0)), .line(to: Point(0, 100))]))

    @Test
    func glyphIsCentredOnItsMidpointAndTurnedToThePath() throws {
        // the path heads down (+y): the glyph's x-axis turns to +y and its baseline origin moves back half its advance
        let m = try #require(Builder.makeGlyphTransform(midpoint: 40, advance: 10, along: line))
        #expect(approx(m.transform(point: Point(0, 0)), Point(0, 35)))
        #expect(approx(m.transform(point: Point(10, 0)), Point(0, 45)))
        // above the baseline (-y) is on the left of the direction of travel
        #expect(approx(m.transform(point: Point(5, -10)), Point(10, 40)))
    }

    @Test
    func rightSideTracesThePathFromItsEnd() throws {
        let m = try #require(Builder.makeGlyphTransform(midpoint: 40, advance: 10, along: line, side: .right))
        #expect(approx(m.transform(point: Point(0, 0)), Point(0, 65)))
        #expect(approx(m.transform(point: Point(10, 0)), Point(0, 55)))
    }

    @Test(arguments: [-0.5, 100.5] as [Float])
    func glyphOffTheEndOfThePathIsNotPlaced(midpoint: Float) {
        #expect(Builder.makeGlyphTransform(midpoint: midpoint, advance: 10, along: line) == nil)
        #expect(Builder.makeGlyphTransform(midpoint: midpoint, advance: 10, along: line, side: .right) == nil)
    }

    private func geometry(_ body: String) throws -> LayerTree.Path? {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          \(body)
        </svg>
        """)
        let text = try #require(svg.childElements.compactMap { $0 as? DOM.Text }.first)
        let textPath = try #require(text.textPath)
        return Builder(svg: svg).makeTextPathGeometry(for: textPath)
    }

    @Test
    func geometryIsTheReferencedPathWithItsTransform() throws {
        let path = try #require(try geometry("""
        <defs><path id="p" d="M 0 0 L 10 0" transform="translate(5 6)" /></defs>
        <text><textPath href='#p'>a</textPath></text>
        """))
        #expect(path.segments == [.move(to: Point(5, 6)), .line(to: Point(15, 6))])
    }

    @Test
    func geometryOfABasicShape() throws {
        let path = try #require(try geometry("""
        <defs><line id="l" x1="1" y1="2" x2="3" y2="4" /></defs>
        <text><textPath href="#l">a</textPath></text>
        """))
        #expect(path.segments == [.move(to: Point(1, 2)), .line(to: Point(3, 4))])
    }

    @Test
    func pathAttributeIsPreferredToHref() throws {
        let path = try #require(try geometry("""
        <defs><path id="p" d="M 0 0 L 10 0" /></defs>
        <text><textPath href='#p' path="M 0 0 L 0 20">a</textPath></text>
        """))
        #expect(path.segments == [.move(to: Point(0, 0)), .line(to: Point(0, 20))])
    }

    @Test
    func missingReferenceHasNoGeometry() throws {
        #expect(try geometry(#"<text><textPath href='#missing'>a</textPath></text>"#) == nil)
    }

    private func layer(_ body: String) throws -> LayerTree.Layer {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="200" height="200">
          <defs><path id="p" d="M 0 100 L 100 100" /></defs>
          \(body)
        </svg>
        """)
        return Builder(svg: svg).makeLayer()
    }

    private func shapes(in layer: LayerTree.Layer) -> [(LayerTree.Path, LayerTree.FillAttributes)] {
        layer.contents.flatMap { contents -> [(LayerTree.Path, LayerTree.FillAttributes)] in
            switch contents {
            case let .shape(.path(path), _, fill): return [(path, fill)]
            case .layer(let child): return shapes(in: child)
            default: return []
            }
        }
    }

    @Test
    func missingPathDrawsNothing() throws {
        let layer = try layer(#"<text><textPath href='#missing'>abc</textPath></text>"#)
        #expect(shapes(in: layer).isEmpty)
    }

#if canImport(CoreText)
    @Test
    func glyphsBecomeOutlinesFilledLikeShapes() throws {
        let layer = try layer(#"<text font-size="20" fill="red"><textPath href='#p'>ab<tspan fill="blue">c</tspan></textPath></text>"#)
        let shapes = shapes(in: layer)
        #expect(shapes.map(\.1.fill) == [.color(.rgba(r: 1, g: 0, b: 0, a: 1, space: .srgb)),
                                         .color(.rgba(r: 0, g: 0, b: 1, a: 1, space: .srgb))])
        let bounds = try #require(shapes.first?.0.bounds)
        // on the path's baseline, from its start
        #expect(bounds.minX >= 0 && bounds.minX < 5)
        #expect(bounds.maxY > 99 && bounds.maxY < 101)
    }

    @Test
    func glyphsOffTheEndOfThePathAreNotDrawn() throws {
        let layer = try layer(#"<text font-size="20"><textPath href='#p'>MMMMMMMMMMMMMMMMMMMM</textPath></text>"#)
        let bounds = try #require(shapes(in: layer).first?.0.bounds)
        // twenty Ms are far longer than the path: only those with their midpoint on it are drawn
        #expect(bounds.maxX <= 100 + 10)
        #expect(bounds.maxX > 80)
    }

    @Test
    func clipPathClipsWithTheGlyphOutlines() throws {
        let layer = try layer("""
        <clipPath id="c"><text font-size="20"><textPath href='#p' fill="red">a<tspan fill="blue">b</tspan></textPath></text></clipPath>
        <rect width="200" height="200" clip-path="url(#c)" />
        """)
        func masks(in layer: LayerTree.Layer) -> [LayerTree.Layer] {
            (layer.mask.map { [$0] } ?? []) + layer.contents.flatMap { contents -> [LayerTree.Layer] in
                guard case .layer(let child) = contents else { return [] }
                return masks(in: child)
            }
        }
        let mask = try #require(masks(in: layer).first)
        let fills = shapes(in: mask).map(\.1.fill)
        #expect(fills.count == 2)
        #expect(fills.allSatisfy { $0 == .color(.rgba(r: 1, g: 1, b: 1, a: 1, space: .srgb)) })
    }

    @Test
    func middleAnchorCentresTheTextOnTheOffset() throws {
        let layer = try layer(#"<text font-size="10" text-anchor="middle"><textPath href='#p' startOffset="50%">HHHH</textPath></text>"#)
        let bounds = try #require(shapes(in: layer).first?.0.bounds)
        #expect(abs(bounds.midX - 50) < 1)
    }
#endif

    private func approx(_ lhs: Point, _ rhs: Point) -> Bool {
        abs(lhs.x - rhs.x) < 0.0001 && abs(lhs.y - rhs.y) < 0.0001
    }
}
