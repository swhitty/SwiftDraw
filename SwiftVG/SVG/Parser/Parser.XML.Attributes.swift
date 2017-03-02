//
//  Parser.XML.Attributes.swift
//  SwiftVG
//
//  Created by Simon Whitty on 2/3/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

import Foundation

extension XMLParser {
    
    // Storage for merging XMLElement attibutes and style properties;
    // style properties have precedence over element attibutes
    // <line stroke="none" fill="red" style="stroke: 2" />
    // attributes["stoke"] == "2"
    // attributes["fill"] == "red"
    final class Attributes {
        var element: [String: String]
        var style: [String: String]
        
        init(element: [String: String], style: [String: String]) {
            self.element = element
            self.style = style
        }
        
        subscript(name: String) -> String? {
            get {
                return style[name] ?? element[name]
            }
        }
        
        var properties: [String: String] {
            var props = element
            for (name, value) in style {
                props[name] = value
            }
            return props
        }
    }
}
