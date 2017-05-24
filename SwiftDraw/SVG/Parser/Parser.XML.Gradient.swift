//
//  Parser.XML.Gradient.swift
//  SwiftVG
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright © 2016 WhileLoop Pty Ltd. All rights reserved.
//

extension XMLParser {
    
    func parseLinearGradients(_ e: XML.Element) throws -> [DOM.LinearGradient] {
        var gradients = Array<DOM.LinearGradient>()
        
        for n in e.children {
            if n.name == "linearGradient" {
                gradients.append(try parseLinearGradient(n))
            } else {
                gradients.append(contentsOf: try parseLinearGradients(n))
            }
        }
        return gradients
    }
    
    func parseLinearGradient(_ e: XML.Element) throws -> DOM.LinearGradient {
        guard e.name == "linearGradient" else {
            throw Error.invalid
        }
        
        let node = DOM.LinearGradient()
        
        for n in e.children where n.name == "stop" {
            let att: AttributeParser = try parseAttributes(n)
            node.stops.append(try parseLinearGradientStop(att))
        }
        
        return node
    }
    
    func parseLinearGradientStop(_ att: AttributeParser) throws -> DOM.LinearGradient.Stop {
        let offset: DOM.Float = try att.parsePercentage("offset")
        let color: DOM.Color = try att.parseColor("stop-color")
        let opacity: DOM.Float? = try att.parsePercentage("stop-opacity")
        return DOM.LinearGradient.Stop(offset: offset, color: color, opacity: opacity ?? 1.0)
    }
    
}
