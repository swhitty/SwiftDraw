//
//  SVG+Insets.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 23/2/25.
//  Copyright 2025 Simon Whitty
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

#if canImport(CoreGraphics)
import CoreGraphics
#endif

public extension SVG {
    struct Insets: Equatable {
        public var top: CGFloat
        public var left: CGFloat
        public var bottom: CGFloat
        public var right: CGFloat

        public init(
            top: CGFloat = 0,
            left: CGFloat = 0,
            bottom: CGFloat = 0,
            right: CGFloat = 0
        ) {
            self.top = top
            self.left = left
            self.bottom = bottom
            self.right = right
        }

        public static let zero = Insets(top: 0, left: 0, bottom: 0, right: 0)
    }
}
