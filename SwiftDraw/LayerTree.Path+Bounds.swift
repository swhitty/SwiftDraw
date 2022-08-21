//
//  LayerTreet.Path+Bounds.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 15/8/22.
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

extension LayerTree.Path {

    struct BoundsFinder {
        typealias Point = LayerTree.Point

        private(set) var location: Point = .zero
        private(set) var min: Point = .maximum
        private(set) var max: Point = .minimum

        mutating func makeBounds(for segments: [Segment]) -> LayerTree.Rect {
            location = .zero
            min = .maximum
            max = .minimum
            updateBounds(for: segments)
            return LayerTree.Rect(
                x: min.x,
                y: min.y,
                width: max.x - min.x,
                height: max.y - min.y
            )
        }

        mutating func makeEndpoints(for segments: [Segment]) -> (start: LayerTree.Point, end: LayerTree.Point) {
            _ = makeBounds(for: segments)
            return (start: start ?? .zero, end: location)
        }

        mutating func updateBounds(for segments: [LayerTree.Path.Segment]) {
            for s in segments {
                updateBounds(for: s)
            }
        }

        private(set) var start: Point?

        mutating func updateBounds(for segment: LayerTree.Path.Segment) {
            switch segment {
            case let .move(to: p):
                location = p
                start = nil
            case let .line(to: p):
                if start == nil {
                    start = location
                }
                updateBounds(from: location, control1: location, control2: p, to: p)
                location = p
            case let .cubic(to: p, control1: cp1, control2: cp2):
                if start == nil {
                    start = location
                }
                updateBounds(from: location, control1: cp1, control2: cp2, to: p)
                location = p
            case .close:
                if let start = start {
                    location = start
                }
                start = nil
            }
        }

        mutating func updateBounds(from: Point, control1: Point, control2: Point, to: Point) {
            let bounds = Self.makeBounds(from: from, control1: control1, control2: control2, to: to)
            min = min.minimum(combining: bounds.min)
            max = max.maximum(combining: bounds.max)
        }

        static func makeBounds(from: Point, control1: Point, control2: Point, to: Point) -> (min: Point, max: Point) {
            let xd = Derivative(p0: from.x, p1: control1.x, p2: control2.x, p3: to.x)
            let yd = Derivative(p0: from.y, p1: control1.y, p2: control2.y, p3: to.y)

            var min = Point.maximum
            var max = Point.minimum

            for t in Set(xd.roots + yd.roots + [0, 1]) {
                let point = Point(xd.value(for: t), yd.value(for: t))
                min = min.minimum(combining: point)
                max = max.maximum(combining: point)
            }
            return (min, max)
        }
    }

    struct Derivative {
        let p0: LayerTree.Float
        let p1: LayerTree.Float
        let p2: LayerTree.Float
        let p3: LayerTree.Float
        let b: LayerTree.Float
        let a: LayerTree.Float
        let c: LayerTree.Float

        init(p0: LayerTree.Float, p1: LayerTree.Float, p2: LayerTree.Float, p3: LayerTree.Float) {
            self.p0 = p0
            self.p1 = p1
            self.p2 = p2
            self.p3 = p3
            self.b = (6 * p0) - (12 * p1) + (6 * p2)
            self.a = (-3 * p0) + (9 * p1) - (9 * p2) + (3 * p3)
            self.c = (3 * p1) - (3 * p0)
        }

        var roots: [LayerTree.Float] {
            var roots = [LayerTree.Float]()

            guard abs(a) > .ulpOfOne else {
                let t = -c / b
                guard (0...1).contains(t) else {
                    return []
                }
                return [t]
            }

            let b2ac = (b * b - 4 * c * a).squareRoot()
            let t1 = (-b + b2ac) / (2 * a)
            let t2 = (-b - b2ac) / (2 * a)

            if (0...1).contains(t1) {
                roots.append(t1)
            }

            if (0...1).contains(t2) {
                roots.append(t2)
            }
            return roots
        }

        func value(for t: LayerTree.Float) -> LayerTree.Float {
            assert(t >= 0 && t <= 1)
            let mt = 1 - t
            return (mt * mt * mt * p0) +
                   (3 * mt * mt * t * p1) +
                   (3 * mt * t * t * p2) +
                   (t * t * t * p3)
        }
    }
}

extension LayerTree.Point {

    static let maximum = LayerTree.Point(.greatestFiniteMagnitude, .greatestFiniteMagnitude)
    static let minimum = LayerTree.Point(-.greatestFiniteMagnitude, -.greatestFiniteMagnitude)

    func minimum(combining other: Self) -> Self {
        LayerTree.Point(min(x, other.x), min(y, other.y))
    }

    func maximum(combining other: Self) -> Self {
        LayerTree.Point(max(x, other.x), max(y, other.y))
    }
}

extension LayerTree.Rect {
    var minX: LayerTree.Float { origin.x }
    var minY: LayerTree.Float { origin.y }
    var maxX: LayerTree.Float { origin.x + size.width }
    var maxY: LayerTree.Float { origin.y + size.height }

    var midX: LayerTree.Float { origin.x + (size.width / 2) }
    var midY: LayerTree.Float { origin.y + (size.height / 2) }
}
