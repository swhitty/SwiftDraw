//
//  DOM.RadialGradient.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 13/8/22.
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

extension DOM {
    
    final class RadialGradient: Element {
        typealias Units = LinearGradient.Units
        
        var id: String
        var r: Coordinate?
        var cx: Coordinate?
        var cy: Coordinate?
        var fr: Coordinate?
        var fx: Coordinate?
        var fy: Coordinate?
        
        var stops: [Stop]
        var gradientUnits: Units?
        var gradientTransform: [Transform]
        
        //references another RadialGradient element id within defs
        var href: URL?
        
        init(id: String) {
            self.id = id
            self.stops = []
            self.gradientTransform = []
        }
        
        struct Stop: Equatable {
            var offset: Float
            var color: Color
            var opacity: Float
            
            init(offset: Float, color: Color, opacity: Opacity = 1.0) {
                self.offset = offset
                self.color = color
                self.opacity = opacity
            }
        }
    }
}

extension DOM.RadialGradient: Equatable {
    static func ==(lhs: DOM.RadialGradient, rhs: DOM.RadialGradient) -> Bool {
        return lhs.id == rhs.id && lhs.stops == rhs.stops
    }
}
