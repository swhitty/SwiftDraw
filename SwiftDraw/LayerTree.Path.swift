//
//  LayerTree.Path.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 3/6/17.
//  Copyright 2020 WhileLoop Pty Ltd. All rights reserved.
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

extension LayerTree {
  final class Path: Hashable {
    var segments: [Segment]
    
    init(_ segments: [Segment] = []) {
      self.segments = segments
    }
    
    enum Segment: Hashable {
      case move(to: Point)
      case line(to: Point)
      case cubic(to: Point, control1: Point, control2: Point)
      case close
    }
    
    func hash(into hasher: inout Hasher) {
      hasher.combine(self.segments)
    }
    
    static func ==(lhs: LayerTree.Path, rhs: LayerTree.Path) -> Bool {
      return lhs.segments == rhs.segments
    }
  }
}

extension LayerTree.Path {
  var lastControl: LayerTree.Point? {
    guard let lastSegment = segments.last else { return nil }
    switch lastSegment {
    case .cubic(_, _, let p): return p
    default: return nil
    }
  }
  
  var location: LayerTree.Point? {
    guard let location = segments.last?.location else {
      return lastStart
    }
    
    return location
  }
  
  var lastStart: LayerTree.Point? {
    let rev = segments.reversed().dropFirst()
    guard
      let closeIdx = rev.firstIndex(where: { $0.isClose }),
      closeIdx != rev.startIndex else {
        return segments.first?.location
    }
    
    let point = rev.index(before: closeIdx)
    return rev[point].location
  }
}

private extension LayerTree.Path.Segment {
  
  var isClose: Bool {
    guard case .close = self else {
      return false
    }
    return true
  }
  
  var location: LayerTree.Point? {
    switch self {
    case .move(to: let p): return p
    case .line(let p): return p
    case .cubic(let p, _, _): return p
    case .close: return nil
    }
  }
}


extension LayerTree.Path {

    func applying(matrix: LayerTree.Transform.Matrix) -> LayerTree.Path {
        LayerTree.Path(
            segments.map { $0.applying(matrix: matrix) }
        )
    }
}

extension LayerTree.Path.Segment {

    func applying(matrix: LayerTree.Transform.Matrix) -> Self {
        switch self {
        case .move(let point):
            return .move(to: matrix.transform(point: point))
        case .line(let point):
            return .line(to: matrix.transform(point: point))
        case .cubic(let p, let cp1, let cp2):
            return .cubic(to: matrix.transform(point: p),
                          control1: matrix.transform(point: cp1),
                          control2: matrix.transform(point: cp2))
        case .close:
            return .close
        }
    }
}
