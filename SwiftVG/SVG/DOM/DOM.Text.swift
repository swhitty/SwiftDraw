//
//  DOM.Text.swift
//  SwiftVG
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright © 2016 WhileLoop Pty Ltd. All rights reserved.
//

extension DOM {
    
    final class Text: GraphicsElement {
        var x: Coordinate?
        var y: Coordinate?
        var value: String
        
        var fontFamily: String?
        var fontSize: Float?
        
        // var textLength: Coordinate
        // var text: [TSpan] child nodes
        
        init(value: String) {
            self.value = value
        }
    }
}
