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
        
        let att = try parseStyleAttributes(e)
        let width = try parseLength(att["width"])
        let height = try parseLength(att["height"])
        
        let svg = DOM.Svg(width: width, height: height)
        svg.childElements = try parseContainerChildren(e)
        svg.viewBox = try parseViewBox(att["viewBox"])
        svg.clipPaths = try parseClipPaths(e)
        
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
    
    
    //search allChild nodes for any ClipPath
    func parseClipPaths(_ e: XML.Element) throws -> [DOM.ClipPath] {
        var clipPaths = Array<DOM.ClipPath>()
        
        for n in e.children {
            if n.name == "clipPath" {
                clipPaths.append(try parseClipPath(n))
            } else {
                clipPaths.append(contentsOf: try parseClipPaths(n))
            }
        }
        return clipPaths
    }
    
    func parseClipPath(_ e: XML.Element) throws -> DOM.ClipPath {
        let att = try parseStyleAttributes(e)
        
        guard e.name == "clipPath",
              let id = att["id"] else {
            throw Error.invalid
        }
        
        let children = try parseContainerChildren(e)
        return DOM.ClipPath(id: id, childElements: children)
    }
}
