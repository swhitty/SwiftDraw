
//
//  Parser.XML.Text.swift
//  SwiftVG
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright © 2016 WhileLoop Pty Ltd. All rights reserved.
//

import Foundation

extension XMLParser {
    
    func parseText(_ att: Attributes, value: String?) throws -> DOM.Text {
        guard let x = try parseCoordinate(att["x"]),
              let y = try parseCoordinate(att["y"]),
              let text = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              text.characters.count > 0 else {
            throw Error.invalid
        }
        
        let element = DOM.Text(x: x, y: y, value: text)
        element.fontFamily = att["font-family"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        element.fontSize = try parseFloat(att["font-size"])
        
        return element
    }
}
