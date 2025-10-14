//
//  DOM.LinearGradient.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 31/12/16.
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

    final class LinearGradient: Element {
        
        package var id: String
        package var x1: Coordinate?
        package var y1: Coordinate?
        package var x2: Coordinate?
        package var y2: Coordinate?

        package var stops: [Stop]
        package var gradientUnits: Units?
        package var gradientTransform: [Transform]

        //references another LinearGradient element id within defs
        package var href: URL?

        package init(id: String) {
            self.id = id
            self.stops = []
            self.gradientTransform = []
        }
        
        package struct Stop: Equatable {
            package var offset: Float
            package var color: Color
            package var opacity: Float

            package init(offset: Float, color: Color, opacity: Opacity = 1.0) {
                self.offset = offset
                self.color = color
                self.opacity = opacity
            }
        }
    }
}

extension DOM.LinearGradient: Equatable {
    package static func ==(lhs: DOM.LinearGradient, rhs: DOM.LinearGradient) -> Bool {
        return lhs.id == rhs.id &&
        lhs.x1 == rhs.x1 &&
        lhs.y1 == rhs.y1 &&
        lhs.x2 == rhs.x2 &&
        lhs.y2 == rhs.y2 &&
        lhs.stops == rhs.stops
    }
}

package extension DOM.LinearGradient {

    enum Units: String {
        case userSpaceOnUse
        case objectBoundingBox
    }
}
