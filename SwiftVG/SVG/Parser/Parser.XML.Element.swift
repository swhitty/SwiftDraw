//
//  Parser.XML.Element.swift
//  SwiftVG
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright © 2016 WhileLoop Pty Ltd. All rights reserved.
//

extension XMLParser {
    
    func parseLine(_ e: XML.Element) throws -> DOM.Line {
        let att = try parseStyleAttributes(e)
        guard e.name == "line",
            let x1 = try parseCoordinate(att["x1"]),
            let y1 = try parseCoordinate(att["y1"]),
            let x2 = try parseCoordinate(att["x2"]),
            let y2 = try parseCoordinate(att["y2"]) else {
            throw Error.invalid
        }
        
        return DOM.Line(x1: x1, y1: y1, x2: x2, y2: y2)
    }
    
    func parseCircle(_ e: XML.Element) throws -> DOM.Circle {
        let att = try parseStyleAttributes(e)
        guard e.name == "circle",
            let cx = try parseCoordinate(att["cx"]),
            let cy = try parseCoordinate(att["cy"]),
            let r = try parseCoordinate(att["r"]) else {
            throw Error.invalid
        }
        
        return DOM.Circle(cx: cx, cy: cy, r: r)
    }
    
    func parseEllipse(_ e: XML.Element) throws -> DOM.Ellipse {
        let att = try parseStyleAttributes(e)
        guard e.name == "ellipse",
            let cx = try parseCoordinate(att["cx"]),
            let cy = try parseCoordinate(att["cy"]),
            let rx = try parseCoordinate(att["rx"]),
            let ry = try parseCoordinate(att["ry"]) else {
            throw Error.invalid
        }
        
        return DOM.Ellipse(cx: cx, cy: cy, rx: rx, ry: ry)
    }
    
    func parseRect(_ e: XML.Element) throws -> DOM.Rect {
        let att = try parseStyleAttributes(e)
        guard e.name == "rect",
            let x = try parseCoordinate(att["x"]),
            let y = try parseCoordinate(att["y"]),
            let width = try parseCoordinate(att["width"]),
            let height = try parseCoordinate(att["height"]) else {
            throw Error.invalid
        }
        
        let rect = DOM.Rect(x: x, y: y, width: width, height: height)
        
        rect.rx = try parseCoordinate(att["rx"])
        rect.ry = try parseCoordinate(att["ry"])
        
        return rect
    }
    
    func parsePoints(_ text: String) -> [DOM.Point] {
        var points = Array<DOM.Point>()
        var scanner = Scanner(text: text)
        
        while let x = try? scanner.scanCoordinate(),
            let y = try? scanner.scanCoordinate() {
            points.append(DOM.Point(x, y))
        }
        
        return points
        
    }
    func parsePolyline(_ e: XML.Element) throws -> DOM.Polyline {
        let att = try parseStyleAttributes(e)
        guard e.name == "polyline",
            let points = att["points"] else {
            throw Error.invalid
        }
        
        return DOM.Polyline(points: parsePoints(points))
    }
    
    func parsePolygon(_ e: XML.Element) throws -> DOM.Polygon {
        let att = try parseStyleAttributes(e)
        guard e.name == "polygon",
            let points = att["points"] else {
            throw Error.invalid
        }
        
        let polygon = DOM.Polygon(points: parsePoints(points))
        
        if let fillRule = att["fill-rule"] {
            polygon.fillRule = try parseFillRule(data: fillRule)
        }
        
        return polygon
    }
    
    func parseGraphicsElement(_ e: XML.Element) throws -> DOM.GraphicsElement? {
        switch e.name {
        case "g", "svg": return try parseGroup(e)
        case "line": return try parseLine(e)
        case "circle": return try parseCircle(e)
        case "ellipse": return try parseEllipse(e)
        case "rect": return try parseRect(e)
        case "polyline": return try parsePolyline(e)
        case "polygon": return try parsePolygon(e)
        case "path": return try parsePath(e)
        case "text": return try parseText(e)
        default: return nil
        }
    }
    
    func parseContainerChildren(_ e: XML.Element) throws -> [DOM.GraphicsElement] {
        guard e.name == "g" || e.name == "svg" else {
            throw Error.invalid
        }
        
        var children = Array<DOM.GraphicsElement>()
        
        for n in e.children {
            if let ge = try parseGraphicsElement(n) {
                children.append(ge)
            }
        }
        
        return children
    }
    
    func parseGroup(_ e: XML.Element) throws -> DOM.Group {
        guard e.name == "g" else {
            throw Error.invalid
        }
        
        let group = DOM.Group()
        group.childElements = try parseContainerChildren(e)
        return group
    }
    
    func parseStyleAttributes(_ e: XML.Element) throws -> [String: String] {
        guard let style = e.attributes["style"] else {
            return e.attributes
        }
        
        var scanner = Scanner(text: style)
        var attributes = e.attributes
        attributes["style"] = nil
        
        while !scanner.isEOF {
            let att = try parseStyleAttribute(&scanner)
            attributes[att.0] = att.1
        }
        
        return attributes
    }
    
    func parseStyleAttribute(_ scanner: inout Scanner) throws -> (String, String) {
        guard let key = scanner.scan(upTo: " \t:") else {
            throw Error.invalid
        }
        _ = scanner.scan(":")
        
        if let value = scanner.scan(upTo: ";") {
            _ = scanner.scan(";")
            return (key, value.trimmingCharacters(in: .whitespaces))
        }
        
        guard let value = scanner.scanToEOF() else {
            throw Error.invalid
        }
        
        return (key, value.trimmingCharacters(in: .whitespaces))
    }
    
}
