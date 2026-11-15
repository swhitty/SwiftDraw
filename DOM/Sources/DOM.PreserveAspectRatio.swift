//
//  DOM.PreserveAspectRatio.swift
//  SwiftDraw
//
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

package extension DOM {

    /// `preserveAspectRatio` (SVG 1.1 §7.8): how a viewBox, or an image, is fitted into its viewport.
    struct PreserveAspectRatio: Equatable, Hashable, Sendable {
        package var align: Align
        package var meetOrSlice: MeetOrSlice

        package enum Align: Equatable, Hashable, Sendable {
            case none
            case xMinYMin, xMidYMin, xMaxYMin
            case xMinYMid, xMidYMid, xMaxYMid
            case xMinYMax, xMidYMax, xMaxYMax
        }

        package enum MeetOrSlice: Equatable, Hashable, Sendable {
            case meet
            case slice
        }

        package init(align: Align = .xMidYMid, meetOrSlice: MeetOrSlice = .meet) {
            self.align = align
            self.meetOrSlice = meetOrSlice
        }

        /// The initial value: `xMidYMid meet`
        package static let `default` = PreserveAspectRatio()

        /// Fraction (0, 0.5 or 1) of the free space placed before the content on each axis.
        package var alignment: (x: Float, y: Float) {
            switch align {
            case .none, .xMinYMin: return (0, 0)
            case .xMidYMin: return (0.5, 0)
            case .xMaxYMin: return (1, 0)
            case .xMinYMid: return (0, 0.5)
            case .xMidYMid: return (0.5, 0.5)
            case .xMaxYMid: return (1, 0.5)
            case .xMinYMax: return (0, 1)
            case .xMidYMax: return (0.5, 1)
            case .xMaxYMax: return (1, 1)
            }
        }

        /// Fits `content` into `viewport`, returning the uniform or (for `none`) non-uniform scale and the
        /// translation applied after scaling, both in viewport units: `viewport = content * scale + offset`.
        package func fit(
            contentWidth: Float, contentHeight: Float,
            viewportWidth: Float, viewportHeight: Float
        ) -> (sx: Float, sy: Float, tx: Float, ty: Float) {
            var sx = viewportWidth / contentWidth
            var sy = viewportHeight / contentHeight
            if align != .none {
                let s = meetOrSlice == .meet ? min(sx, sy) : max(sx, sy)
                sx = s
                sy = s
            }
            let a = alignment
            return (sx, sy,
                    (viewportWidth - contentWidth * sx) * a.x,
                    (viewportHeight - contentHeight * sy) * a.y)
        }
    }
}
