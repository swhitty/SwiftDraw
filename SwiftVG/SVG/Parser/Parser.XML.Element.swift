//
//  Parser.XML.Element.swift
//  SwiftVG
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright © 2016 WhileLoop Pty Ltd. All rights reserved.
//

extension XMLParser {
    
    func parseLine(_ att: AttributeParser) throws -> DOM.Line {
        let x1: DOM.Coordinate = try att.parseCoordinate("x1")
        let y1: DOM.Coordinate = try att.parseCoordinate("y1")
        let x2: DOM.Coordinate = try att.parseCoordinate("x2")
        let y2: DOM.Coordinate = try att.parseCoordinate("y2")
        return DOM.Line(x1: x1, y1: y1, x2: x2, y2: y2)
    }
    
    func parseCircle(_ att: AttributeParser) throws -> DOM.Circle {
        let cx: DOM.Coordinate = try att.parseCoordinate("cx")
        let cy: DOM.Coordinate = try att.parseCoordinate("cy")
        let r: DOM.Coordinate = try att.parseCoordinate("r")
        return DOM.Circle(cx: cx, cy: cy, r: r)
    }
    
    func parseEllipse(_ att: AttributeParser) throws -> DOM.Ellipse {
        let cx: DOM.Coordinate = try att.parseCoordinate("cx")
        let cy: DOM.Coordinate = try att.parseCoordinate("cy")
        let rx: DOM.Coordinate = try att.parseCoordinate("rx")
        let ry: DOM.Coordinate = try att.parseCoordinate("ry")
        return DOM.Ellipse(cx: cx, cy: cy, rx: rx, ry: ry)
    }
    
    func parseRect(_ att: AttributeParser) throws -> DOM.Rect {
        let x: DOM.Coordinate = try att.parseCoordinate("x")
        let y: DOM.Coordinate = try att.parseCoordinate("y")
        let width: DOM.Coordinate = try att.parseCoordinate("width")
        let height: DOM.Coordinate = try att.parseCoordinate("height")
        let rect = DOM.Rect(x: x, y: y, width: width, height: height)
        
        rect.rx = try att.parseCoordinate("rx")
        rect.ry = try att.parseCoordinate("ry")
        
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
    
    func parsePolyline(_ att: AttributeParser) throws -> DOM.Polyline {
        return DOM.Polyline(points: try att.parsePoints("points"))
    }
    
    func parsePolygon(_ att: AttributeParser) throws -> DOM.Polygon {
        return DOM.Polygon(points: try att.parsePoints("points"))
    }
    
    func parseGraphicsElement(_ e: XML.Element) throws -> DOM.GraphicsElement? {
        
        let ge: DOM.GraphicsElement
        
        let att = try parseAttributes(e)
   
        switch e.name {
        case "g": ge = try parseGroup(e)
        case "line": ge = try parseLine(att)
        case "circle": ge = try parseCircle(att)
        case "ellipse": ge = try parseEllipse(att)
        case "rect": ge = try parseRect(att)
        case "polyline": ge = try parsePolyline(att)
        case "polygon": ge = try parsePolygon(att)
        case "path": ge = try parsePath(att)
        case "text": ge = try parseText(att, value: e.innerText)
        case "use": ge = try parseUse(att)
        case "switch": ge = try parseSwitch(e)
        default: return nil
        }
        
        ge.id = e.attributes["id"]
        
        let presentation = try parsePresentationAttributes(att)

        ge.opacity = presentation.opacity
        ge.display = presentation.display
        ge.stroke = presentation.stroke
        ge.strokeWidth = presentation.strokeWidth
        ge.strokeOpacity = presentation.strokeOpacity
        ge.fill = presentation.fill
        ge.fillOpacity = presentation.fillOpacity
        ge.fillRule = presentation.fillRule
        ge.transform = presentation.transform
        ge.clipPath = presentation.clipPath
        ge.mask = presentation.mask
        
        return ge
    }
    
    func parseContainerChildren(_ e: XML.Element) throws -> [DOM.GraphicsElement] {
        guard e.name == "svg" ||
              e.name == "clipPath" ||
              e.name == "mask" ||
              e.name == "defs" ||
              e.name == "switch" ||
              e.name == "g" else {
            throw Error.invalid
        }
        
        var children = Array<DOM.GraphicsElement>()
        
        for n in e.children {
            do {
                if let ge = try parseGraphicsElement(n) {
                    children.append(ge)
                }
            } catch let error as XMLParser.Error {
                switch error {
                case .invalidElement(_):
                    throw error
                default:
                    throw Error.invalidElement(name: n.name,
                                               error: error,
                                               line: n.parsedLocation?.line,
                                               column: n.parsedLocation?.column)
                }
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
    
    func parseSwitch(_ e: XML.Element) throws -> DOM.Switch {
        guard e.name == "switch" else {
            throw Error.invalid
        }
        
        let node = DOM.Switch()
        node.childElements = try parseContainerChildren(e)
        return node
    }
    
    func parseAttributes(_ e: XML.Element) throws -> Attributes {
        guard let styleText = e.attributes["style"] else {
            return Attributes(parser: ValueParser(),
                              options: options,
                              element: e.attributes,
                              style: [:])
        }
        
        var scanner = Scanner(text: styleText)
        var style = [String: String]()
        
        while !scanner.isEOF {
            let att = try parseStyleAttribute(&scanner)
            style[att.0] = att.1
        }
        
        var element = e.attributes
        element["style"] = nil
        return Attributes(parser: ValueParser(),
                          options: options,
                          element: element,
                          style: style)
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
    
    func parsePresentationAttributes(_ att: AttributeParser) throws -> PresentationAttributes {
        let el = DOM.GraphicsElement()

        el.opacity = try att.parsePercentage("opacity")
        el.display = try att.parseRaw("display")
        
        el.stroke = try att.parseColor("stroke")
        el.strokeWidth = try att.parseFloat("stroke-width")
        el.strokeOpacity = try att.parsePercentage("stroke-opacity")
        el.strokeLineCap = try att.parseRaw("stroke-linecap")
        el.strokeLineJoin = try att.parseRaw("stroke-linejoin")
        el.strokeDashArray = try att.parseFloats("stroke-dasharray")
        
        el.fill = try att.parseColor("fill")
        el.fillOpacity = try att.parsePercentage("fill-opacity")
        el.fillRule = try att.parseRaw("fill-rule")
        
        if let val = try? att.parseString("transform") {
            el.transform = try parseTransform(val)
        }
      
        el.clipPath = try att.parseUrlSelector("clip-path")
        el.mask = try att.parseUrlSelector("mask")

        return el
    }
    
    
}
