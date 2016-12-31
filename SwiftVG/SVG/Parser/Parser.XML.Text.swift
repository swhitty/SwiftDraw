
//
//  Parser.XML.Text.swift
//  SwiftVG
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright © 2016 WhileLoop Pty Ltd. All rights reserved.
//

import Foundation

extension XMLParser {
    
    func parseText(_ e: XML.Element) throws -> DOM.Text {
        guard e.name == "text",
              let x = try parseCoordinate(e.attributes["x"]),
              let y = try parseCoordinate(e.attributes["y"]),
              let value = e.innerText?.trimmingCharacters(in: .whitespacesAndNewlines),
              value.characters.count > 0 else {
                throw Error.invalid
        }
        
        let element = DOM.Text(x: x, y: y, value: value)
        element.fontFamily = e.attributes["font-family"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        element.fontSize = try parseFloat(e.attributes["font-size"])
        
        return element
    }
}
