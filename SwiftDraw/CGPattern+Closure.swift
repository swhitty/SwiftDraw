//
//  CGPattern+Closure.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 28/3/19.
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

#if canImport(CoreGraphics)
import CoreGraphics

extension CGPattern {

  static func make(bounds: CGRect,
                   matrix: CGAffineTransform,
                   step: CGSize,
                   tiling: CGPatternTiling,
                   isColored: Bool,
                   draw: @escaping (CGContext) -> Void) -> CGPattern {

    let drawPattern: CGPatternDrawPatternCallback = { info, ctx in
      let box = Unmanaged<Box>.fromOpaque(info!).takeUnretainedValue()
      box.closure(ctx)
    }

    let releaseInfo: CGPatternReleaseInfoCallback = { info in
      Unmanaged<Box>.fromOpaque(info!).release()
    }

    var callbacks = CGPatternCallbacks(version: 0,
                                       drawPattern: drawPattern,
                                       releaseInfo: releaseInfo)

    return CGPattern(info: Unmanaged.passRetained(Box(draw)).toOpaque(),
                     bounds: bounds,
                     matrix: matrix,
                     xStep: step.width,
                     yStep: step.height,
                     tiling: tiling,
                     isColored: isColored,
                     callbacks: &callbacks)!
  }

  private final class Box {
    let closure: (CGContext) -> Void
    init(_ closure: @escaping (CGContext) -> Void) {
      self.closure = closure
    }
  }
}

#endif
