//
//  Parser.XML.Gradient.swift
//  SwiftVG
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright © 2016 WhileLoop Pty Ltd. All rights reserved.
//

extension XMLParser {
    
    func parseLinearGradient(_ e: XML.Element) throws -> DOM.LinearGradient {
        guard e.name == "linearGradient" else {
            throw Error.invalid
        }
        
        let node = DOM.LinearGradient()
        
        for n in e.children where n.name == "stop" {
            node.stops.append(try parseLinearGradientStop(n))
        }
        
        return node
    }
    
    func parseLinearGradientStop(_ e: XML.Element) throws -> DOM.LinearGradient.Stop {
        let att = try parseStyleAttributes(e)
        guard e.name == "stop",
            let offsetText = att["offset"],
            let colorText = att["stop-color"] else {
            throw Error.invalid
        }
        
        let offset = try parsePercentage(offsetText)
        let color = try parseColor(data: colorText)
        
        guard let opacityText = att["stop-opacity"] else {
            return DOM.LinearGradient.Stop(offset: offset, color: color)
        }
        
        let opacity = try parsePercentage(opacityText)
        return DOM.LinearGradient.Stop(offset: offset, color: color, opacity: opacity)
    }
    
}
