//
//  DOM.SVG.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 11/2/17.
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

extension DOM {
    final class SVG: GraphicsElement, ContainerElement {
        var x: Coordinate?
        var y: Coordinate?
        var width: Length
        var height: Length
        var viewBox: ViewBox?

        var childElements = [GraphicsElement]()
        
        var styles = [StyleSheet]()
        var defs = Defs()
        
        init(x: Coordinate? = nil, y: Coordinate? = nil, width: Length, height: Length) {
            self.x = x
            self.y = y
            self.width = width
            self.height = height
        }
        
        struct ViewBox: Equatable {
            var x: Coordinate
            var y: Coordinate
            var width: Coordinate
            var height: Coordinate
        }
        
        struct Defs {
            var clipPaths = [ClipPath]()
            var linearGradients = [LinearGradient]()
            var radialGradients = [RadialGradient]()
            var masks = [Mask]()
            var patterns = [Pattern]()
            var filters = [Filter]()
            
            var elements = [String: GraphicsElement]()
        }
    }
    
    struct ClipPath: ContainerElement {
        var id: String
        var childElements = [GraphicsElement]()
    }
    
    struct Mask: ContainerElement {
        var id: String
        var childElements = [GraphicsElement]()
    }
    
    struct StyleSheet {
        
        enum Selector: Hashable, Comparable {
            case id(String)
            case element(String)
            case `class`(String)
        }
        
        var attributes: [Selector: PresentationAttributes] = [:]
    }
}
