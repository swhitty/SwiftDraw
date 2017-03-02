
//
//  Parser.XML.Text.swift
//  SwiftVG
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright © 2016 WhileLoop Pty Ltd. All rights reserved.
//

import Foundation

extension XMLParser {
    
    func parseText(_ att: AttributeParser, value: String?) throws -> DOM.Text {
        
        let x: DOM.Coordinate = try att.parseCoordinate("x")
        let y: DOM.Coordinate = try att.parseCoordinate("y")
        
        guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              text.characters.count > 0 else {
            throw Error.missingAttribute(name: "innerText")
        }
        
        let element = DOM.Text(x: x, y: y, value: text)
       
        element.fontFamily = att.parseString("font-family")?.trimmingCharacters(in: .whitespacesAndNewlines)
        element.fontSize = try att.parseFloat("font-size")
        
        return element
    }
}
