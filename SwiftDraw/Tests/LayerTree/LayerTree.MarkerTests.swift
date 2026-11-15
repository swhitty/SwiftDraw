//
//  LayerTree.MarkerTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 15/11/26.
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


import Foundation
import SwiftDrawDOM
import Testing
@testable import SwiftDraw

struct LayerTreeMarkerTests {

    typealias Vertex = LayerTree.Builder.MarkerVertex

    private func parse(_ body: String) throws -> DOM.SVG {
        try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="200" height="200">\(body)</svg>
        """)
    }

    private func vertices(_ body: String) throws -> [Vertex] {
        let element = try #require(try parse(body).childElements.first)
        return LayerTree.Builder.makeMarkerVertices(for: element)
    }

    private func vertex(_ x: Float, _ y: Float, _ angle: Float) -> Vertex {
        Vertex(point: LayerTree.Point(x, y), angle: angle)
    }

    private func expectVertices(_ actual: [Vertex], _ expected: [Vertex],
                                sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(actual.count == expected.count, sourceLocation: sourceLocation)
        for (a, e) in zip(actual, expected) {
            #expect(abs(a.point.x - e.point.x) < 0.001 && abs(a.point.y - e.point.y) < 0.001,
                    "\(a.point) != \(e.point)", sourceLocation: sourceLocation)
            let delta = (a.angle - e.angle).truncatingRemainder(dividingBy: 360)
            #expect(abs(delta) < 0.01 || abs(abs(delta) - 360) < 0.01,
                    "angle \(a.angle) != \(e.angle) at \(e.point)", sourceLocation: sourceLocation)
        }
    }

    /// The marker layers drawn after the shape, in order
    private func markerLayers(_ body: String) throws -> [LayerTree.Layer] {
        let svg = try parse(body)
        let root = LayerTree.Builder(svg: svg).makeLayer()
        return markerLayers(in: root)
    }

    private func markerLayers(in layer: LayerTree.Layer) -> [LayerTree.Layer] {
        for case let .layer(l) in layer.contents {
            if case .shape = l.contents.first, l.contents.count > 1 {
                return l.contents.compactMap { if case let .layer(m) = $0 { return m } else { return nil } }
            }
            let found = markerLayers(in: l)
            if !found.isEmpty { return found }
        }
        return []
    }

    /// The clip of the marker contents, inside the layer placing them at the vertex
    private func clip(of layer: LayerTree.Layer) -> [LayerTree.ClipShape] {
        guard case let .layer(contents) = layer.contents.first else { return [] }
        return contents.clip
    }

    // MARK: - vertices

    @Test
    func lineVertices() throws {
        expectVertices(try vertices(#"<line x1="10" y1="10" x2="10" y2="50"/>"#), [
            vertex(10, 10, 90),
            vertex(10, 50, 90)
        ])
    }

    @Test
    func polylineMidVerticesBisect() throws {
        expectVertices(try vertices(#"<polyline points="0,0 10,0 10,10 0,10"/>"#), [
            vertex(0, 0, 0),
            vertex(10, 0, 45),
            vertex(10, 10, 135),
            vertex(0, 10, 180)
        ])
    }

    @Test
    func closedSubpathBisectsAtItsStart() throws {
        // SVG 2 §11.6.2: the first and last vertex of a closed subpath bisect the closing and first segments
        expectVertices(try vertices(#"<polygon points="0,0 10,0 10,10 0,10"/>"#), [
            vertex(0, 0, -45),
            vertex(10, 0, 45),
            vertex(10, 10, 135),
            vertex(0, 10, 225),
            vertex(0, 0, -45)
        ])
        expectVertices(try vertices(#"<path d="M 0 0 H 10 V 10 H 0 Z"/>"#), [
            vertex(0, 0, -45),
            vertex(10, 0, 45),
            vertex(10, 10, 135),
            vertex(0, 10, 225),
            vertex(0, 0, -45)
        ])
    }

    @Test
    func curvesUseTheirTangents() throws {
        expectVertices(try vertices(#"<path d="M 0 0 C 0 10 10 10 10 0 Q 20 -10 30 0"/>"#), [
            vertex(0, 0, 90),
            vertex(10, 0, -90 + (-45 - -90) / 2),
            vertex(30, 0, 45)
        ])
    }

    @Test
    func curveWithControlPointOnTheEndPoint() throws {
        // the tangent comes from the next distinct control point
        expectVertices(try vertices(#"<path d="M 0 0 C 0 0 10 10 10 20"/>"#), [
            vertex(0, 0, 45),
            vertex(10, 20, 90)
        ])
    }

    @Test
    func subpathsEachStartAVertex() throws {
        expectVertices(try vertices(#"<path d="M 0 0 L 10 0 M 20 0 L 20 10"/>"#), [
            vertex(0, 0, 0),
            vertex(10, 0, 0),
            vertex(20, 0, 90),
            vertex(20, 10, 90)
        ])
    }

    @Test
    func arcIsOneSegment() throws {
        // drawn as two curves, but one path command
        expectVertices(try vertices(#"<path d="M 0 0 A 10 10 0 0 1 20 0 L 30 0"/>"#), [
            vertex(0, 0, -90),
            vertex(20, 0, 45),
            vertex(30, 0, 0)
        ])
    }

    @Test
    func zeroLengthSegmentKeepsThePreviousDirection() throws {
        expectVertices(try vertices(#"<path d="M 0 0 L 10 0 L 10 0 L 10 10"/>"#), [
            vertex(0, 0, 0),
            vertex(10, 0, 0),
            vertex(10, 0, 45),
            vertex(10, 10, 90)
        ])
    }

    @Test
    func loneMoveIsOneVertex() throws {
        expectVertices(try vertices(#"<path d="M 5 5"/>"#), [vertex(5, 5, 0)])
    }

    @Test
    func onlyPathLinePolylineAndPolygonHaveVertices() throws {
        let rect = try vertices(#"<rect width="10" height="10"/>"#)
        let circle = try vertices(#"<circle r="10"/>"#)
        let point = try vertices(#"<polyline points="5,5"/>"#)
        #expect(rect.isEmpty)
        #expect(circle.isEmpty)
        #expect(point.isEmpty)
    }

    @Test(arguments: [
        (Float(0), Float(90), Float(45)),
        (170, -170, 180),
        (-170, 170, 180),
        (0, 180, 90)
    ])
    func bisector(incoming: Float, outgoing: Float, expected: Float) {
        func direction(_ degrees: Float) -> LayerTree.Point {
            LayerTree.Point(cos(degrees * .pi / 180), sin(degrees * .pi / 180))
        }
        let angle = LayerTree.Builder.makeBisector(incoming: direction(incoming), outgoing: direction(outgoing))
        let delta = (angle - expected).truncatingRemainder(dividingBy: 360)
        #expect(abs(delta) < 0.01 || abs(abs(delta) - 360) < 0.01)
    }

    // MARK: - marker layers

    @Test
    func markersAtEachVertex() throws {
        let layers = try markerLayers("""
        <marker id="s"/><marker id="m"/><marker id="e"/>
        <polyline points="0,0 10,0 20,0 30,0" stroke="black"
                  marker-start="url(#s)" marker-mid="url(#m)" marker-end="url(#e)"/>
        """)
        #expect(layers.count == 4)
        #expect(layers.map(\.transform.first) == [
            nil,
            .translate(tx: 10, ty: 0),
            .translate(tx: 20, ty: 0),
            .translate(tx: 30, ty: 0)
        ])
    }

    @Test
    func strokeWidthUnitsScaleTheMarker() throws {
        let layers = try markerLayers("""
        <marker id="m" refX="1" refY="2" orient="auto"/>
        <line x1="10" y1="10" x2="10" y2="50" stroke="black" stroke-width="4" marker-end="url(#m)"/>
        """)
        let transform = try #require(layers.first?.transform)
        #expect(layers.count == 1)
        #expect(transform.count == 4)
        #expect(transform.first == .translate(tx: 10, ty: 50))
        guard case let .rotate(radians) = transform[1] else {
            Issue.record("not a rotation: \(transform[1])")
            return
        }
        #expect(abs(radians - .pi / 2) < 0.0001)
        #expect(transform.dropFirst(2) == [
            .scale(sx: 4, sy: 4),
            .translate(tx: -1, ty: -2)
        ])
    }

    @Test
    func userSpaceOnUseUnitsWithViewBox() throws {
        let layers = try markerLayers("""
        <marker id="m" markerUnits="userSpaceOnUse" markerWidth="20" markerHeight="10" viewBox="0 0 10 10"
                refX="5" refY="5" orient="auto-start-reverse"/>
        <line x1="10" y1="10" x2="50" y2="10" stroke="black" stroke-width="4" marker-start="url(#m)"/>
        """)
        // the viewBox meets the viewport with a scale of 1, centred
        #expect(layers.first?.transform == [
            .translate(tx: 10, ty: 10),
            .rotate(radians: 180 * .pi / 180),
            .translate(tx: -5, ty: -5)
        ])
        // clipped to the viewport, which is wider than the viewBox
        #expect(layers.first.map(clip(of:)) == [
            LayerTree.ClipShape(shape: .rect(within: LayerTree.Rect(x: -5, y: 0, width: 20, height: 10), radii: .zero),
                                transform: .identity)
        ])
    }

    @Test
    func overflowVisibleDoesNotClip() throws {
        let layers = try markerLayers("""
        <style>#b { overflow: visible }</style>
        <marker id="a"/><marker id="b"/><marker id="c" overflow="auto"/>
        <polyline points="5,5 10,5 20,5" stroke="black" marker-start="url(#a)" marker-mid="url(#b)" marker-end="url(#c)"/>
        """)
        #expect(layers.map { clip(of: $0).isEmpty } == [false, true, true])
    }

    @Test
    func emptyViewportOrStrokeDrawsNoMarker() throws {
        let emptyViewport = try markerLayers("""
        <marker id="m" markerWidth="0"/>
        <line x2="10" stroke="black" marker-end="url(#m)"/>
        """)
        let emptyStroke = try markerLayers("""
        <marker id="m"/>
        <line x2="10" stroke="black" stroke-width="0" marker-end="url(#m)"/>
        """)
        #expect(emptyViewport.isEmpty)
        #expect(emptyStroke.isEmpty)
    }

    @Test
    func markerPropertiesAreInherited() throws {
        let layers = try markerLayers("""
        <marker id="m"/>
        <g marker-end="url(#m)" stroke="black">
          <g><line x2="10"/></g>
        </g>
        """)
        #expect(layers.count == 1)

        let none = try markerLayers("""
        <marker id="m"/>
        <g marker-end="url(#m)" stroke="black"><line x2="10" marker-end="none"/></g>
        """)
        #expect(none.isEmpty)
    }

    @Test
    func noMarkersOnOtherShapes() throws {
        let layers = try markerLayers("""
        <marker id="m"><rect width="3" height="3"/></marker>
        <rect width="10" height="10" marker-start="url(#m)"/>
        <circle r="10" marker-start="url(#m)"/>
        """)
        #expect(layers.isEmpty)
    }

    @Test
    func contentsInheritFromTheMarkerNotTheShape() throws {
        let layers = try markerLayers("""
        <marker id="m" fill="red"><rect width="3" height="3"/></marker>
        <line x2="10" stroke="black" fill="blue" marker-end="url(#m)"/>
        """)
        let layer = try #require(layers.first)
        let fill = try #require(firstFill(in: layer))
        #expect(fill.fill == .color(.rgba(r: 1, g: 0, b: 0, a: 1, space: .srgb)))
    }

    private func firstFill(in layer: LayerTree.Layer) -> LayerTree.FillAttributes? {
        for contents in layer.contents {
            switch contents {
            case let .shape(_, _, fill): return fill
            case let .layer(l): if let fill = firstFill(in: l) { return fill }
            default: continue
            }
        }
        return nil
    }

    @Test
    func markerReferencingItselfIsDropped() throws {
        // must terminate: the marker's own line would place the marker again
        let layers = try markerLayers("""
        <marker id="m" marker-end="url(#m)"><line x2="3" stroke="black"/></marker>
        <line x2="10" stroke="black" marker-end="url(#m)"/>
        """)
        let layer = try #require(layers.first)
        #expect(layers.count == 1)
        #expect(markerLayers(in: layer).isEmpty)
    }

    @Test
    func markersReferencingEachOtherTerminate() throws {
        let layers = try markerLayers("""
        <marker id="a"><line x2="3" stroke="black" marker-end="url(#b)"/></marker>
        <marker id="b"><line x2="3" stroke="black" marker-end="url(#a)"/></marker>
        <line x2="10" stroke="black" marker-end="url(#a)"/>
        """)
        #expect(layers.count == 1)
    }
}
