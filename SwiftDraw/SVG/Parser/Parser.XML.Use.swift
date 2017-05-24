//
//  Parser.XML.Use.swift
//  SwiftVG
//
//  Created by Simon Whitty on 27/2/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

extension XMLParser {
    
    func parseUse(_ att: AttributeParser) throws -> DOM.Use {
        let use = DOM.Use(href: try att.parseUrl("xlink:href"))
        use.x = try att.parseCoordinate("x")
        use.y = try att.parseCoordinate("y")

        return use
    }
}
