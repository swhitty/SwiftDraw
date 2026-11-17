//
//  LayerTree.Builder.Marker.swift
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

import SwiftDrawDOM
import Foundation

// SVG 2 §11.6: markers on path, line, polyline and polygon

extension LayerTree.Builder {

    /// A vertex of a shape's path data and the marker orientation there.
    struct MarkerVertex: Equatable {
        var point: LayerTree.Point
        /// The direction of the path at the vertex in degrees: the bisector of the incoming and
        /// outgoing directions, or the one there is at the ends of an open subpath.
        var angle: LayerTree.Float
    }

    /// The markers of a shape in the order they are drawn; empty when it has none.
    func makeMarkerLayers(for element: DOM.GraphicsElement, with state: State) -> [LayerTree.Layer] {
        let start = resolveMarker(state.markerStart)
        let mid = resolveMarker(state.markerMid)
        let end = resolveMarker(state.markerEnd)
        guard start != nil || mid != nil || end != nil else { return [] }

        let vertices = Self.makeMarkerVertices(for: element)
        guard !vertices.isEmpty else { return [] }

        // the contents of each marker are built once and shared by all its vertices
        var cache = [ObjectIdentifier: LayerTree.Layer?]()
        func markerContents(of marker: DOM.Marker) -> LayerTree.Layer? {
            let key = ObjectIdentifier(marker)
            if let cached = cache[key] { return cached }
            let layer = makeMarkerContents(for: marker)
            cache[key] = .some(layer)
            return layer
        }

        var markers = [LayerTree.Layer]()
        func append(_ marker: DOM.Marker?, at vertex: MarkerVertex, isStart: Bool = false) {
            guard let marker, let inner = markerContents(of: marker),
                let layer = makeMarkerLayer(
                    for: marker,
                    contents: inner,
                    at: vertex,
                    isStart: isStart,
                    strokeWidth: state.strokeWidth
                )
            else { return }
            markers.append(layer)
        }

        // marker-start on the first vertex, marker-mid on every other but the last, marker-end on the last
        append(start, at: vertices[0], isStart: true)
        if vertices.count > 2 {
            for vertex in vertices[1..<(vertices.count - 1)] {
                append(mid, at: vertex)
            }
        }
        append(end, at: vertices[vertices.count - 1])
        return markers
    }

    /// The fill, stroke and markers of a shape in its `paint-order` (SVG 2 §13.6).
    ///
    /// Fill followed directly by stroke stays one `.shape`, so the default order draws as it always has:
    /// the shape alone, or a layer of the shape then its markers. Otherwise the shape is split into a
    /// fill-only and a stroke-only `.shape`, and the markers go where the order puts them. Everything
    /// is in one layer, so the element's opacity, clip, mask and filter still apply to them as a group.
    func makePaintedContents(
        _ contents: LayerTree.Layer.Contents,
        for element: DOM.GraphicsElement,
        with state: State
    ) -> LayerTree.Layer.Contents {
        guard case let .shape(shape, stroke, fill) = contents else { return contents }
        let markers = makeMarkerLayers(for: element, with: state)

        var noFill = fill
        var noStroke = stroke
        noFill.fill = .color(.none)
        noStroke.color = .color(.none)
        let hasFill = fill.fill != .color(.none)
        let hasStroke = stroke.color != .color(.none)

        var items = [LayerTree.Layer.Contents]()
        let order = state.paintOrder.layers
        var index = order.startIndex
        while index < order.endIndex {
            switch order[index] {
            case .fill where index + 1 < order.endIndex && order[index + 1] == .stroke:
                items.append(contents)
                index += 1
            case .fill:
                if hasFill { items.append(.shape(shape, noStroke, fill)) }
            case .stroke:
                if hasStroke { items.append(.shape(shape, stroke, noFill)) }
            case .markers:
                items.append(contentsOf: markers.map { .layer($0) })
            }
            index += 1
        }

        guard items.count > 1 else { return items.first ?? contents }
        let l = LayerTree.Layer()
        l.isPaintOrdered = items != [contents] + markers.map { .layer($0) }
        items.forEach(l.appendContents)
        return .layer(l)
    }

    func resolveMarker(_ url: DOM.URL?) -> DOM.Marker? {
        guard let id = url?.fragmentID else { return nil }
        return svg.defs.markers.first { $0.id == id }
    }

    /// The contents of a marker in its own coordinate system, clipped to its viewport unless
    /// `overflow` is visible; nil when it references itself.
    func makeMarkerContents(for marker: DOM.Marker) -> LayerTree.Layer? {
        // A marker drawn inside itself draws nothing
        building(ObjectIdentifier(marker), cycle: nil) {
            buildingContents {
                let attributes = DOM.presentationAttributes(for: marker, styles: svg.styles)
                // the contents inherit from the marker and its ancestors, not from the shape (SVG 2 §11.6.2),
                // and `display` does not apply to <marker>
                var markerState = Self.createState(
                    for: attributes,
                    inheriting: makeInheritedState(from: marker.ancestors),
                    viewportDiagonal: viewportDiagonal
                )
                markerState.display = .inline
                let l = LayerTree.Layer()
                l.opacity = markerState.opacity
                for child in marker.childElements {
                    l.appendContents(.layer(makeLayer(from: child, inheriting: markerState)))
                }

                // the user agent style sheet sets `overflow: hidden` on <marker>, which clips to the viewport
                let overflow = attributes.overflow ?? .hidden
                if overflow == .hidden || overflow == .scroll {
                    let viewport = Self.makeViewportClip(
                        viewBox: marker.viewBox,
                        width: marker.markerWidth ?? 3,
                        height: marker.markerHeight ?? 3,
                        preserveAspectRatio: marker.preserveAspectRatio
                    )
                    l.clip = [LayerTree.ClipShape(shape: .rect(within: viewport, radii: .zero), transform: .identity)]
                }
                return l
            }
        }
    }

    /// One marker placed at a vertex: its viewport positioned so `refX`/`refY` falls on the vertex,
    /// rotated by `orient`, scaled by the stroke width for `markerUnits="strokeWidth"`.
    func makeMarkerLayer(
        for marker: DOM.Marker,
        contents: LayerTree.Layer,
        at vertex: MarkerVertex,
        isStart: Bool,
        strokeWidth: LayerTree.Float
    ) -> LayerTree.Layer? {
        let width = marker.markerWidth ?? 3
        let height = marker.markerHeight ?? 3
        // a zero or negative viewport disables the marker
        guard width > 0, height > 0, width.isFinite, height.isFinite else { return nil }

        let scale = marker.markerUnits == .userSpaceOnUse ? 1 : strokeWidth
        guard scale > 0, scale.isFinite else { return nil }

        let angle: LayerTree.Float
        switch marker.orient {
        case .auto:
            angle = vertex.angle
        case .autoStartReverse:
            angle = isStart ? vertex.angle + 180 : vertex.angle
        case .angle(let degrees):
            angle = degrees
        case nil:
            angle = 0
        }

        let fit = Self.makeViewBoxFit(
            viewBox: marker.viewBox,
            width: width,
            height: height,
            preserveAspectRatio: marker.preserveAspectRatio
        )

        // (x - refX) * viewBoxScale maps the reference point onto the vertex: the viewBox
        // origin and the alignment offset cancel out
        var transform = [LayerTree.Transform]()
        if vertex.point != .zero {
            transform.append(.translate(tx: vertex.point.x, ty: vertex.point.y))
        }
        if angle.truncatingRemainder(dividingBy: 360) != 0 {
            transform.append(.rotate(radians: angle * .pi / 180))
        }
        if scale != 1 {
            transform.append(.scale(sx: scale, sy: scale))
        }
        if fit.sx != 1 || fit.sy != 1 {
            transform.append(.scale(sx: fit.sx, sy: fit.sy))
        }
        let refX = marker.refX ?? 0
        let refY = marker.refY ?? 0
        if refX != 0 || refY != 0 {
            transform.append(.translate(tx: -refX, ty: -refY))
        }

        let l = LayerTree.Layer()
        l.transform = transform
        l.appendContents(.layer(contents))
        return l
    }
}

extension LayerTree.Builder {

    /// The vertices of the path data of a path, line, polyline or polygon (SVG 2 §11.6.2): the start of
    /// each subpath and the end of every segment. A closepath ends at the start of its subpath, so a
    /// closed subpath has a vertex there twice. Arcs are one segment, though drawn as several curves.
    static func makeMarkerVertices(for element: DOM.GraphicsElement) -> [MarkerVertex] {
        makeMarkerVertices(from: makeMarkerSegments(for: element))
    }

    /// The path data as one group of drawn segments per path command.
    static func makeMarkerSegments(for element: DOM.GraphicsElement) -> [[LayerTree.Path.Segment]] {
        func lines(_ points: [DOM.Point]) -> [[LayerTree.Path.Segment]] {
            guard let first = points.first else { return [] }
            return [[.move(to: Point(first.x, first.y))]] + points.dropFirst().map { [.line(to: Point($0.x, $0.y))] }
        }

        switch element {
        case let line as DOM.Line:
            return [[.move(to: Point(line.x1, line.y1))], [.line(to: Point(line.x2, line.y2))]]
        case let polyline as DOM.Polyline:
            return polyline.points.count > 1 ? lines(polyline.points) : []
        case let polygon as DOM.Polygon:
            return polygon.points.count > 1 ? lines(polygon.points) + [[.close]] : []
        case let domPath as DOM.Path:
            var state = PathState()
            var groups = [[LayerTree.Path.Segment]]()
            for segment in domPath.segments {
                guard let segments = try? makeSegments(from: segment, state: &state) else { break }
                groups.append(segments)
            }
            // path data must begin with a moveto
            guard groups.first?.first?.isMove == true else { return [] }
            return groups
        default:
            return []
        }
    }

    static func makeMarkerVertices(from groups: [[LayerTree.Path.Segment]]) -> [MarkerVertex] {
        struct Vertex {
            var point: LayerTree.Point
            var incoming: LayerTree.Point?
            var outgoing: LayerTree.Point?
        }
        var vertices = [Vertex]()
        var current = LayerTree.Point.zero
        var subpathStart = LayerTree.Point.zero
        var subpathIndex = 0
        // the direction at the start of the first segment of the subpath
        var subpathDirection: LayerTree.Point?
        var hasSegments = false
        // the direction at the end of the previous segment, for zero-length segments
        var previousDirection: LayerTree.Point?

        func appendSegment(start: LayerTree.Point?, end: LayerTree.Point?, to point: LayerTree.Point) {
            // a zero-length segment takes the direction of the segment before it
            let start = start ?? previousDirection
            let end = end ?? start
            if !hasSegments {
                subpathDirection = start
                hasSegments = true
            }
            if !vertices.isEmpty {
                vertices[vertices.count - 1].outgoing = start
            }
            vertices.append(Vertex(point: point, incoming: end))
            previousDirection = end
            current = point
        }

        for group in groups {
            guard let first = group.first else { continue }
            switch first {
            case .move(let point):
                vertices.append(Vertex(point: point))
                current = point
                subpathStart = point
                subpathIndex = vertices.count - 1
                subpathDirection = nil
                hasSegments = false
                previousDirection = nil
            case .close:
                let direction = makeDirection(from: current, to: subpathStart)
                appendSegment(start: direction, end: direction, to: subpathStart)
                // SVG 2 §11.6.2: both vertices of a closed subpath take the bisector of the
                // closing segment and the first segment
                let closing = vertices[vertices.count - 1].incoming
                vertices[vertices.count - 1].outgoing = subpathDirection
                vertices[subpathIndex].incoming = closing
                // a segment after closepath starts a new subpath at the same point
                subpathIndex = vertices.count - 1
                hasSegments = false
                previousDirection = nil
            case .line, .cubic:
                var start: LayerTree.Point?
                var end: LayerTree.Point?
                var point = current
                for segment in group {
                    let directions = makeDirections(of: segment, from: point)
                    start = start ?? directions.start
                    end = directions.end ?? end
                    point = segment.location ?? point
                }
                appendSegment(start: start, end: end, to: point)
            }
        }

        return vertices.map {
            MarkerVertex(point: $0.point, angle: makeBisector(incoming: $0.incoming, outgoing: $0.outgoing))
        }
    }

    /// The directions at the start and end of a segment; nil where it has zero length.
    static func makeDirections(
        of segment: LayerTree.Path.Segment,
        from point: LayerTree.Point
    ) -> (start: LayerTree.Point?, end: LayerTree.Point?) {
        switch segment {
        case .line(let to):
            let direction = makeDirection(from: point, to: to)
            return (direction, direction)
        case let .cubic(to, control1, control2):
            // the first control point distinct from the end point gives the tangent there
            let start =
                makeDirection(from: point, to: control1)
                ?? makeDirection(from: point, to: control2)
                ?? makeDirection(from: point, to: to)
            let end =
                makeDirection(from: control2, to: to)
                ?? makeDirection(from: control1, to: to)
                ?? makeDirection(from: point, to: to)
            return (start, end)
        case .move, .close:
            return (nil, nil)
        }
    }

    static func makeDirection(from: LayerTree.Point, to: LayerTree.Point) -> LayerTree.Point? {
        let dx = to.x - from.x
        let dy = to.y - from.y
        guard dx != 0 || dy != 0, dx.isFinite, dy.isFinite else { return nil }
        return LayerTree.Point(dx, dy)
    }

    /// The angle in degrees halfway between the incoming and outgoing directions
    /// (as WebKit, the mean of the two angles taken the short way round).
    static func makeBisector(incoming: LayerTree.Point?, outgoing: LayerTree.Point?) -> LayerTree.Float {
        func degrees(_ p: LayerTree.Point) -> LayerTree.Float {
            // in Double: a reversal (0° then 180°) must stay exactly on the 180° wrap
            // threshold below, and Float atan2 rounds across it differently per platform
            LayerTree.Float(atan2(Double(p.y), Double(p.x)) * 180 / .pi)
        }
        switch (incoming.map(degrees), outgoing.map(degrees)) {
        case (var a?, let b?):
            if abs(a - b) > 180 { a += 360 }
            return (a + b) / 2
        case (let a?, nil):
            return a
        case (nil, let b?):
            return b
        case (nil, nil):
            return 0
        }
    }
}
