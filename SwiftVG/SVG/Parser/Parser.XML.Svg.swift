//
//  Parser.XML.Svg.swift
//  SwiftVG
//
//  Created by Simon Whitty on 11/2/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

extension XMLParser {
    
    func parseSvg(_ e: XML.Element) throws -> DOM.Svg {
        guard e.name == "svg" else {
            throw Error.invalid
        }
        
        let width = try parseLength(e.attributes["width"])
        let height = try parseLength(e.attributes["height"])
        
        let svg = DOM.Svg(width: width, height: height)
        svg.childElements = try parseContainerChildren(e)
        
        return svg
    }
    
    
}
