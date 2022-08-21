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
