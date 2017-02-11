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
        svg.viewBox = try parseViewBox(e.attributes["viewBox"])
        
        return svg
    }
    
    func parseViewBox(_ data: String?) throws -> DOM.Svg.ViewBox? {
        guard let data = data else { return nil }
        var scanner = Scanner(text: data)
        
        let x = try scanner.scanCoordinate()
        let y = try scanner.scanCoordinate()
        let width = try scanner.scanCoordinate()
        let height = try scanner.scanCoordinate()
        
        guard scanner.isEOF else {
            throw Error.invalid
        }
        
        return DOM.Svg.ViewBox(x: x, y: y, width: width, height: height)
    }
}
