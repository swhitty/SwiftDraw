//
//  LayerTreet.Path+Reversed.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 21/8/22.
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

    func makeNonZero() -> LayerTree.Path {
        let paths = makeNodes().flatMap { $0.windPaths() }
        return LayerTree.Path(paths.flatMap(\.segments))
    }

    var reversed: LayerTree.Path {
        var reversed = segments
            .reversed()
            .paired(with: .nextSkippingLast)
            .compactMap { segment, next in
                segment.reversing(to: next.location)
            }

        if let point = segments.lastLocation {
            reversed.insert(.move(to: point), at: 0)
        }

        while reversed.last?.isMove == true {
            reversed.removeLast()
        }

        if segments.last?.isClose == true {
            reversed.append(.close)
        }

        return .init(reversed)
    }
}

private extension LayerTree.Path {

    func makeNodes() -> [SubPathNode] {
        var nodes = [SubPathNode]()

        for p in subpaths {
            let node = SubPathNode(p)
            if let idx = nodes.firstIndex(where: { $0.containsNode(node) }) {
                nodes[idx].append(node)
            } else {
                nodes.append(node)
            }
        }
        return nodes
    }
}

#if canImport(CoreGraphics)
import CoreGraphics
#endif

private struct SubPathNode {
    let path: LayerTree.Path
#if canImport(CoreGraphics)
    let cgPath: CGPath
#endif

    let bounds: LayerTree.Rect
    let direction: LayerTree.Path.Direction
    var children: [SubPathNode] = []

    init(_ path: LayerTree.Path) {
        self.path = path
        self.bounds = path.bounds
        self.direction = path.segments.direction

        #if canImport(CoreGraphics)
        self.cgPath = CGProvider().createPath(from: .path(path))
        #endif
    }

    mutating func append(_ node: SubPathNode) {
        if let idx = children.firstIndex(where: { $0.containsNode(node) }) {
            children[idx].append(node)
        } else {
            children.append(node)
        }
    }

    func windPaths() -> [LayerTree.Path] {
        windPaths(direction)
    }

    func containsNode(_ node: SubPathNode) -> Bool {
        #if canImport(CoreGraphics)
        let provider = CGProvider()
        for point in node.path.segments.compactMap(\.location) {
            if cgPath.contains(provider.createPoint(from: point)) {
                return true
            }
        }
        return false
        #else
        return bounds.contains(point: node.bounds.center)
        #endif
    }

    func windPaths(_ direction: LayerTree.Path.Direction) -> [LayerTree.Path] {
        var paths = [LayerTree.Path]()

        if self.direction == direction {
            paths.append(path)
        } else {
            paths.append(path.reversed)
        }

        paths += children.flatMap { $0.windPaths(direction.opposite) }
        return paths
    }
}

private extension Array where Element == LayerTree.Path.Segment {

    var lastLocation: LayerTree.Point? {
        for segment in reversed() {
            if let location = segment.location {
                return location
            }
        }
        return nil
    }
}

private extension LayerTree.Path.Segment {

    func reversing(to point: LayerTree.Point?) -> Self? {
        guard let point = point else { return nil }
        switch self {
        case .move:
            return .move(to: point)
        case .line:
            return .line(to: point)
        case let .cubic(to: _, control1: control1, control2: control2):
            return .cubic(to: point, control1: control2, control2: control1)
        case .close:
            return nil
        }
    }
}
