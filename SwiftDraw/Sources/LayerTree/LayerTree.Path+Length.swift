//
//  LayerTree.Path+Length.swift
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

#if canImport(Darwin)
import Darwin
#elseif canImport(Android)
import Android
#elseif canImport(ucrt)
import ucrt
#else
import Glibc
#endif

extension LayerTree.Path {

    /// Distances along a path (SVG 2 §9.5 "path length"), with the path flattened into short lines.
    /// A move does not add to the length; a close adds the line back to the start of its subpath.
    struct Measure {
        typealias Point = LayerTree.Point
        typealias Float = LayerTree.Float

        struct Line: Equatable {
            var start: Point
            var end: Point
            /// distance along the path to `start`
            var offset: Float
            var length: Float
        }

        private(set) var lines: [Line] = []
        private(set) var length: Float = 0

        /// - Parameter flatness: the longest line a curve is split into, in user units
        init(_ path: LayerTree.Path, flatness: Float = 1) {
            var current = Point(0, 0)
            var subpathStart = Point(0, 0)

            for segment in path.segments {
                switch segment {
                case .move(let p):
                    current = p
                    subpathStart = p
                case .line(let p):
                    append(from: current, to: p)
                    current = p
                case let .cubic(p, cp1, cp2):
                    let hull = current.distance(to: cp1) + cp1.distance(to: cp2) + cp2.distance(to: p)
                    let count = Int(min(max((hull / flatness).rounded(.up), 1), 1024))
                    var previous = current
                    for i in 1...count {
                        let t = Float(i) / Float(count)
                        let next = i == count ? p : Self.point(on: current, cp1, cp2, p, at: t)
                        append(from: previous, to: next)
                        previous = next
                    }
                    current = p
                case .close:
                    append(from: current, to: subpathStart)
                    current = subpathStart
                }
            }
        }

        private mutating func append(from start: Point, to end: Point) {
            let d = start.distance(to: end)
            guard d > 0, d.isFinite else { return }
            lines.append(Line(start: start, end: end, offset: length, length: d))
            length += d
        }

        /// The point at a distance along the path and the angle of its direction there, in radians
        /// clockwise from the x-axis (y down). nil when the distance is off either end of the path.
        func position(at distance: Float) -> (point: Point, angle: Float)? {
            guard distance >= 0, distance <= length, !lines.isEmpty else { return nil }

            // the first line that reaches the distance
            var low = 0
            var high = lines.count - 1
            while low < high {
                let mid = (low + high) / 2
                if lines[mid].offset + lines[mid].length < distance {
                    low = mid + 1
                } else {
                    high = mid
                }
            }
            let line = lines[low]
            let t = min(max((distance - line.offset) / line.length, 0), 1)
            let point = Point(
                line.start.x + (line.end.x - line.start.x) * t,
                line.start.y + (line.end.y - line.start.y) * t
            )
            let angle = atan2(line.end.y - line.start.y, line.end.x - line.start.x)
            return (point, angle)
        }

        static func point(on p0: Point, _ p1: Point, _ p2: Point, _ p3: Point, at t: Float) -> Point {
            let mt = 1 - t
            let a = mt * mt * mt
            let b = 3 * mt * mt * t
            let c = 3 * mt * t * t
            let d = t * t * t
            return Point(
                a * p0.x + b * p1.x + c * p2.x + d * p3.x,
                a * p0.y + b * p1.y + c * p2.y + d * p3.y
            )
        }
    }
}

private extension LayerTree.Point {
    func distance(to other: LayerTree.Point) -> LayerTree.Float {
        let dx = other.x - x
        let dy = other.y - y
        return (dx * dx + dy * dy).squareRoot()
    }
}
