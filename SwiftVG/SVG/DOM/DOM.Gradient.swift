//
//  DOM.Gradient.swift
//  SwiftVG
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright © 2016 WhileLoop Pty Ltd. All rights reserved.
//


extension DOM {
    
    final class LinearGradient: Element {
        
        var stops: [Stop]
        
        override init() {
            self.stops = []
        }
        
        struct Stop {
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

extension DOM.LinearGradient: Equatable {
    static func ==(lhs: DOM.LinearGradient, rhs: DOM.LinearGradient) -> Bool {
        return lhs.stops == rhs.stops
    }
}

extension DOM.LinearGradient.Stop: Equatable {
    static func ==(lhs: DOM.LinearGradient.Stop, rhs: DOM.LinearGradient.Stop) -> Bool {
        return lhs.offset == rhs.offset &&
                lhs.color == rhs.color &&
                lhs.opacity == rhs.opacity
    }
}
