//
//  Parser.XML.Image.swift
//  SwiftVG
//
//  Created by Simon Whitty on 27/2/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

extension XMLParser {
    
    func parseImage(_ att: AttributeParser) throws -> DOM.Image {
        let href: DOM.URL = try att.parseUrl("xlink:href")
        let width: DOM.Coordinate = try att.parseCoordinate("width")
        let height: DOM.Coordinate = try att.parseCoordinate("height")
        
        let use = DOM.Image(href: href, width: width, height: height)
        use.x = try att.parseCoordinate("x")
        use.y = try att.parseCoordinate("y")
        
        return use
    }
}
