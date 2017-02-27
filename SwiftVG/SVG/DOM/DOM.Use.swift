//
//  DOM.Use.swift
//  SwiftVG
//
//  Created by Simon Whitty on 27/2/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

extension DOM {
    final class Use: GraphicsElement {
        var x: Coordinate?
        var y: Coordinate?

        //references element ids within defs
        var href: String

        init(href: String) {
            self.href = href
        }
    }
}
