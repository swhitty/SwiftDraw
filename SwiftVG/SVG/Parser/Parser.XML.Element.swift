//
//  Parser.XML.Element.swift
//  SwiftVG
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright © 2016 WhileLoop Pty Ltd. All rights reserved.
//


extension XMLParser {
    
    func parseLine(_ e: XML.Element) throws -> DOM.Line {
        guard e.name == "line",
            let x1 = try parseCoordinate(e.attributes["x1"]),
            let y1 = try parseCoordinate(e.attributes["y1"]),
            let x2 = try parseCoordinate(e.attributes["x2"]),
            let y2 = try parseCoordinate(e.attributes["y2"]) else {
                throw Error.invalid
        }
        
        return DOM.Line(x1: x1, y1: y1, x2: x2, y2: y2)
    }
    
    func parseCircle(_ e: XML.Element) throws -> DOM.Circle {
        guard e.name == "circle",
            let cx = try parseCoordinate(e.attributes["cx"]),
            let cy = try parseCoordinate(e.attributes["cy"]),
            let r = try parseCoordinate(e.attributes["r"]) else {
                throw Error.invalid
        }
        
        return DOM.Circle(cx: cx, cy: cy, r: r)
    }
    
    func parseEllipse(_ e: XML.Element) throws -> DOM.Ellipse {
        guard e.name == "ellipse",
            let cx = try parseCoordinate(e.attributes["cx"]),
            let cy = try parseCoordinate(e.attributes["cy"]),
            let rx = try parseCoordinate(e.attributes["rx"]),
            let ry = try parseCoordinate(e.attributes["ry"]) else {
                throw Error.invalid
        }
        
        return DOM.Ellipse(cx: cx, cy: cy, rx: rx, ry: ry)
    }
    
    func parseRect(_ e: XML.Element) throws -> DOM.Rect {
        guard e.name == "rect",
            let x = try parseCoordinate(e.attributes["x"]),
            let y = try parseCoordinate(e.attributes["y"]),
            let width = try parseCoordinate(e.attributes["width"]),
            let height = try parseCoordinate(e.attributes["height"]) else {
                throw Error.invalid
        }
        
        let rect = DOM.Rect(x: x, y: y, width: width, height: height)
        
        rect.rx = try parseCoordinate(e.attributes["rx"])
        rect.ry = try parseCoordinate(e.attributes["ry"])
        
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
        guard e.name == "polyline",
            let points = e.attributes["points"] else {
                throw Error.invalid
        }
        
        return DOM.Polyline(points: parsePoints(points))
    }
    
    func parsePolygon(_ e: XML.Element) throws -> DOM.Polygon {
        guard e.name == "polygon",
            let points = e.attributes["points"] else {
                throw Error.invalid
        }
        
        let polygon = DOM.Polygon(points: parsePoints(points))
        
        if let fillRule = e.attributes["fill-rule"] {
            polygon.fillRule = try parseFillRule(data: fillRule)
        }
        
        return polygon
    }

}
