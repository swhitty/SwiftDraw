//
//  Parser.XML.Element.swift
//  SwiftVG
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright © 2016 WhileLoop Pty Ltd. All rights reserved.
//

extension XMLParser {
    
    func parseLine(_ att: Attributes) throws -> DOM.Line {
        guard let x1 = try parseCoordinate(att["x1"]),
            let y1 = try parseCoordinate(att["y1"]),
            let x2 = try parseCoordinate(att["x2"]),
            let y2 = try parseCoordinate(att["y2"]) else {
            throw Error.invalid
        }
        
        return DOM.Line(x1: x1, y1: y1, x2: x2, y2: y2)
    }
    
    func parseCircle(_ att: Attributes) throws -> DOM.Circle {
        guard let cx = try parseCoordinate(att["cx"]),
              let cy = try parseCoordinate(att["cy"]),
              let r = try parseCoordinate(att["r"]) else {
            throw Error.invalid
        }
        
        return DOM.Circle(cx: cx, cy: cy, r: r)
    }
    
    func parseEllipse(_ att: Attributes) throws -> DOM.Ellipse {
        guard let cx = try parseCoordinate(att["cx"]),
              let cy = try parseCoordinate(att["cy"]),
              let rx = try parseCoordinate(att["rx"]),
              let ry = try parseCoordinate(att["ry"]) else {
            throw Error.invalid
        }
        
        return DOM.Ellipse(cx: cx, cy: cy, rx: rx, ry: ry)
    }
    
    func parseRect(_ att: Attributes) throws -> DOM.Rect {
        guard let x = try parseCoordinate(att["x"]),
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
    func parsePolyline(_ att: Attributes) throws -> DOM.Polyline {
        guard let points = att["points"] else {
            throw Error.invalid
        }
        
        return DOM.Polyline(points: parsePoints(points))
    }
    
    func parsePolygon(_ att: Attributes) throws -> DOM.Polygon {
        guard let points = att["points"] else {
            throw Error.invalid
        }
        
        let polygon = DOM.Polygon(points: parsePoints(points))
        return polygon
    }
    
    func parseGraphicsElement(_ e: XML.Element) throws -> DOM.GraphicsElement? {
        
        let ge: DOM.GraphicsElement
        
        let attributes = try parseAttributes(e)
   
        switch e.name {
        case "g", "svg": ge = try parseGroup(e)
        case "line": ge = try parseLine(attributes)
        case "circle": ge = try parseCircle(attributes)
        case "ellipse": ge = try parseEllipse(attributes)
        case "rect": ge = try parseRect(attributes)
        case "polyline": ge = try parsePolyline(attributes)
        case "polygon": ge = try parsePolygon(attributes)
        case "path": ge = try parsePath(attributes)
        case "text": ge = try parseText(attributes, value: e.innerText)
        case "use": ge = try parseUse(attributes)
        default: return nil
        }
        
        ge.id = e.attributes["id"]
        
        let att = try parsePresentationAttributes(attributes)

        ge.opacity = att.opacity
        ge.display = att.display
        ge.stroke = att.stroke
        ge.strokeWidth = att.strokeWidth
        ge.strokeOpacity = att.strokeOpacity
        ge.fill = att.fill
        ge.fillOpacity = att.fillOpacity
        ge.fillRule = att.fillRule
        ge.transform = att.transform
        ge.clipPath = att.clipPath
        ge.mask = att.mask
        
        return ge
    }
    
    func parseContainerChildren(_ e: XML.Element) throws -> [DOM.GraphicsElement] {
        guard e.name == "svg" ||
              e.name == "clipPath" ||
              e.name == "mask" ||
              e.name == "defs" ||
              e.name == "g" else {
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
    
    func parseStyleAttributes(_ e: XML.Element) throws -> Attributes {
        return try parseAttributes(e)
    }
    
    func parseAttributes(_ e: XML.Element) throws -> Attributes {
        guard let style = e.attributes["style"] else {
            return Attributes(element: e.attributes, style: [:])
        }
        
        var scanner = Scanner(text: style)
        var styleProperties = [String: String]()
        
        while !scanner.isEOF {
            let att = try parseStyleAttribute(&scanner)
            styleProperties[att.0] = att.1
        }
        
        var element = e.attributes
        element["style"] = nil
        return Attributes(element: element, style: styleProperties)
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
    
    func parsePresentationAttributes(_ att: Attributes) throws -> PresentationAttributes {
        let el = DOM.GraphicsElement()

        el.opacity = try parsePercentage(att["opacity"])
        el.display = try parseDisplayMode(att["display"])
        
        el.stroke = try parseColor(att["stroke"])
        el.strokeWidth = try parseFloat(att["stroke-width"])
        el.strokeOpacity = try parsePercentage(att["stroke-opacity"])
        el.strokeLineCap = try parseLineCap(att["stroke-linecap"])
        el.strokeLineJoin = try parseLineJoin(att["stroke-linejoin"])
        el.strokeDashArray = try parseDashArray(att["stroke-dasharray"])
        
        el.fill = try parseColor(att["fill"])
        el.fillOpacity = try parsePercentage(att["fill-opacity"])
        el.fillRule = try parseFillRule(att["fill-rule"])
        
        if let val = att["transform"] {
            el.transform = try parseTransform(val)
        }
        if let val = att["clip-path"] {
            el.clipPath = try parseUrlSelector(val)
        }
        if let val = att["mask"] {
            el.mask = try parseUrlSelector(val)
        }
        
        return el
        
    }
    
    
}
