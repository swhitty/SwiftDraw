//
//  LayerTreet.Path+Subpath.swift
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

    var subpaths: [LayerTree.Path] {
        var builder = SubpathBuilder()
        return builder.makeSubpaths(for: self)
    }
}

extension LayerTree.Path {

    struct SubpathBuilder {
        typealias Point = LayerTree.Point

        var start: Point?
        var location: Point = .zero

        var subpaths = [LayerTree.Path]()
        var current = [LayerTree.Path.Segment]()

        mutating func makeSubpaths(for path: LayerTree.Path) -> [LayerTree.Path] {
            subpaths = []
            current = []
            start = nil
            for s in path.segments {
                appendSegment(s)
            }

            if current.contains(where: \.isEdge) {
                subpaths.append(.init(current))
            }

            return subpaths
        }

        mutating func appendSegment(_ segment: LayerTree.Path.Segment) {
            switch segment {
            case let .move(to: p):
                if let idx = current.indices.last, current[idx].isMove {
                    current[idx] = segment
                } else {
                    current.append(segment)
                }
                location = p
                start = nil
            case let .line(to: p):
                current.append(segment)
                if start == nil {
                    start = location
                }
                location = p
            case let .cubic(to: p, control1: _, control2: _):
                current.append(segment)
                if start == nil {
                    start = location
                }
                location = p
            case .close:
                current.append(segment)
                subpaths.append(.init(current))
                current = []
                if let start = start {
                    location = start
                    current.append(.move(to: start))
                }
                start = nil
            }
        }
    }
}

private extension LayerTree.Path.Segment {

    var isEdge: Bool {
        switch self {
        case .line, .cubic:
            return true
        case .move, .close:
            return false
        }
    }
}
