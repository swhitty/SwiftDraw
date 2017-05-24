
//
//  Parser.XML.Text.swift
//  SwiftVG
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright © 2016 WhileLoop Pty Ltd. All rights reserved.
//

import Foundation

extension XMLParser {
    
    func parseText(_ att: AttributeParser, element: XML.Element) throws -> DOM.Text? {
        guard let text = element.innerText?.trimmingCharacters(in: .whitespacesAndNewlines),
              text.characters.count > 0 else {
                return nil
        }
        
        return try parseText(att, value: text)
    }
    
    func parseText(_ att: AttributeParser, value: String) throws -> DOM.Text {
        let element = DOM.Text(value: value)
        element.x = try att.parseCoordinate("x")
        element.y = try att.parseCoordinate("y")
        element.fontFamily = (try att.parseString("font-family"))?.trimmingCharacters(in: .whitespacesAndNewlines)
        element.fontSize = try att.parseFloat("font-size")
        
        return element
    }
}
