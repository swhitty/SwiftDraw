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
        
        let att = try parseAttributes(e)
        var width: DOM.Coordinate? = try att.parseCoordinate("width")
        var height: DOM.Coordinate? = try att.parseCoordinate("height")
        let viewBox: DOM.Svg.ViewBox? = try parseViewBox(try att.parseString("viewBox"))
        
        width = width ?? viewBox?.width
        height = height ?? viewBox?.height
        
        guard let w = width else { throw XMLParser.Error.missingAttribute(name: "width") }
        guard let h = height else { throw XMLParser.Error.missingAttribute(name: "height") }
    
        var svg = DOM.Svg(width: DOM.Length(w), height: DOM.Length(h))
        svg.childElements = try parseContainerChildren(e)
        svg.viewBox = try parseViewBox(try att.parseString("viewBox"))
        
        svg.defs = try parseSVGDefs(e)
        
        let presentation = try parsePresentationAttributes(att)
        svg.updateAttributes(from: presentation)
        
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
    func parseSVGDefs(_ e: XML.Element) throws -> DOM.Svg.Defs {
        var defs = DOM.Svg.Defs()
        defs.clipPaths = try parseClipPaths(e)
        defs.masks = try parseMasks(e)
        defs.linearGradients = try parseLinearGradients(e)

        //TODO parse all children for all defs nodes
        if let node = e.children.first( where: { $0.name == "defs" }) {
            defs.elements = try parseDefsElements(node)
        }

        return defs
    }

    func parseDefsElements(_ e: XML.Element) throws -> [String: DOM.GraphicsElement] {
        guard e.name == "defs" else {
                throw Error.invalid
        }
        
        var defs = Dictionary<String, DOM.GraphicsElement>()
        let elements = try parseContainerChildren(e)
        
        for e in elements {
            guard let id = e.id else {
                throw Error.invalid
            }
            defs[id] = e
        }
        
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
        guard e.name == "clipPath" else { throw Error.invalid }
        
        let att = try parseAttributes(e)
        let id: String = try att.parseString("id")
        
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
        guard e.name == "mask" else { throw Error.invalid }
        
        let att = try parseAttributes(e)
        let id: String = try att.parseString("id")
   
        let children = try parseContainerChildren(e)
        return DOM.Mask(id: id, childElements: children)
    }
}
