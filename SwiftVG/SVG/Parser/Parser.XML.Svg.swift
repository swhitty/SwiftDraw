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
        
        svg.defs = try parseDefs(e)
        
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
    
    
    // search all nodes within document for any defs
    // not just the <defs> node
    func parseDefs(_ e: XML.Element) throws -> DOM.Svg.Defs {
        var defs = DOM.Svg.Defs()
        defs.clipPaths = try parseClipPaths(e)
        defs.masks = try parseMasks(e)
        defs.linearGradients = try parseLinearGradients(e)
        
        return defs
    }

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
    
    func parseMasks(_ e: XML.Element) throws -> [DOM.Mask] {
        var masks = Array<DOM.Mask>()
        
        for n in e.children {
            if n.name == "mask" {
                masks.append(try parseMask(n))
            } else {
                masks.append(contentsOf: try parseMasks(n))
            }
        }
        return masks
    }
    
    func parseMask(_ e: XML.Element) throws -> DOM.Mask {
        let att = try parseStyleAttributes(e)
        
        guard e.name == "mask",
            let id = att["id"] else {
                throw Error.invalid
        }
        
        let children = try parseContainerChildren(e)
        return DOM.Mask(id: id, childElements: children)
    }
}
