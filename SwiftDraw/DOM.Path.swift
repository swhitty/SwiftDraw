//
//  DOM.Path.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 8/3/17.
//  Copyright 2020 Simon Whitty
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

extension DOM {
  
  final class Path: GraphicsElement {
    
    // segments[0] should always be a .move
    var segments: [Segment]
    
    init(x: Coordinate, y: Coordinate) {
      let s = Segment.move(x: x, y: y, space: .absolute)
      segments = [s]
      super.init()
    }
    
    enum Segment {
      case move(x: Coordinate, y: Coordinate, space: CoordinateSpace)
      case line(x: Coordinate, y: Coordinate, space: CoordinateSpace)
      case horizontal(x: Coordinate, space: CoordinateSpace)
      case vertical(y: Coordinate, space: CoordinateSpace)
      case cubic(x1: Coordinate, y1: Coordinate,
        x2: Coordinate, y2: Coordinate,
        x: Coordinate, y: Coordinate, space: CoordinateSpace)
      case cubicSmooth(x2: Coordinate, y2: Coordinate,
        x: Coordinate, y: Coordinate, space: CoordinateSpace)
      case quadratic(x1: Coordinate, y1: Coordinate,
        x: Coordinate, y: Coordinate, space: CoordinateSpace)
      case quadraticSmooth(x: Coordinate, y: Coordinate, space: CoordinateSpace)
      case arc(rx: Coordinate, ry: Coordinate, rotate: Coordinate,
        large: Bool, sweep: Bool,
        x: Coordinate, y: Coordinate, space: CoordinateSpace)
      case close
      
      enum CoordinateSpace {
        case absolute
        case relative
      }
    }
    
    enum Command: UnicodeScalar {
      case move = "M"
      case moveRelative = "m"
      case line = "L"
      case lineRelative = "l"
      case horizontal = "H"
      case horizontalRelative = "h"
      case vertical = "V"
      case verticalRelative = "v"
      case cubic = "C"
      case cubicRelative = "c"
      case cubicSmooth = "S"
      case cubicSmoothRelative = "s"
      case quadratic = "Q"
      case quadraticRelative = "q"
      case quadraticSmooth = "T"
      case quadraticSmoothRelative = "t"
      case arc = "A"
      case arcRelative = "a"
      case close = "Z"
      case closeAlias = "z"
      
      var coordinateSpace: Segment.CoordinateSpace {
        switch self {
        case .move, .line,
             .horizontal, .vertical,
             .cubic, .cubicSmooth,
             .quadratic, .quadraticSmooth,
             .arc, .close, .closeAlias:
          return .absolute
        case .moveRelative, .lineRelative,
             .horizontalRelative, .verticalRelative,
             .cubicRelative, .cubicSmoothRelative,
             .quadraticRelative, .quadraticSmoothRelative,
             .arcRelative:
          return .relative
        }
      }
    }
  }
}
