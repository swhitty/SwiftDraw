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

package extension DOM {
    final class SVG: GraphicsElement, ContainerElement {
        package var x: Coordinate?
        package var y: Coordinate?
        package var width: Length
        package var height: Length
        package var viewBox: ViewBox?

        package var childElements = [GraphicsElement]()

        package var styles = [StyleSheet]()
        package var defs = Defs()

        package init(x: Coordinate? = nil, y: Coordinate? = nil, width: Length, height: Length) {
            self.x = x
            self.y = y
            self.width = width
            self.height = height
        }
        
        package struct ViewBox: Equatable {
            package var x: Coordinate
            package var y: Coordinate
            package var width: Coordinate
            package var height: Coordinate

            package init(x: Coordinate, y: Coordinate, width: Coordinate, height: Coordinate) {
                self.x = x
                self.y = y
                self.width = width
                self.height = height
            }
        }
        
        package struct Defs {
            package var clipPaths = [ClipPath]()
            package var linearGradients = [LinearGradient]()
            package var radialGradients = [RadialGradient]()
            package var masks = [Mask]()
            package var patterns = [Pattern]()
            package var filters = [Filter]()

            package var elements = [String: GraphicsElement]()
        }
    }
    
    struct ClipPath: ContainerElement {
        package var id: String
        package var childElements = [GraphicsElement]()
    }
    
    final class Mask: GraphicsElement, ContainerElement {
        package var childElements = [GraphicsElement]()

        init(id: String, childElements: [GraphicsElement] = []) {
            super.init()
            self.id = id
            self.childElements = childElements
        }
    }
    
    struct StyleSheet {

        package enum Selector: Hashable, Comparable {
            case id(String)
            case element(String)
            case `class`(String)
        }
        
        package var attributes: [Selector: PresentationAttributes] = [:]
    }
}
