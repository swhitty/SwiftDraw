//
//  Parser.XML.Use.swift
//  SwiftVG
//
//  Created by Simon Whitty on 27/2/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

extension XMLParser {
    
    func parseUse(_ e: XML.Element) throws -> DOM.Use {
        let att = try parseStyleAttributes(e)
        guard e.name == "use",
              let anchor = att["xlink:href"] else {
                throw Error.invalid
        }

        let use = DOM.Use(href: try parseUrl(anchor))
        use.x = try parseCoordinate(att["x"])
        use.y = try parseCoordinate(att["y"])

        return use
    }
}
