//
//  DOM.SVG.swift
//  SwiftVG
//
//  Created by Simon Whitty on 11/2/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

extension DOM {
    class Svg: GraphicsElement, ContainerElement {
        var width: Length?
        var height: Length?
        var viewBox: ViewBox?
        
        var childElements = [GraphicsElement]()
        
        var clipPaths = [ClipPath]()
        
        init(width: Length? = nil, height: Length? = nil) {
            self.width = width
            self.height = height
        }
        
        struct ViewBox {
            var x: Coordinate
            var y: Coordinate
            var width: Coordinate
            var height: Coordinate
        }
    }
    
    
    struct ClipPath: ContainerElement {
        var id: String
        var childElements = [GraphicsElement]()
    }
}
