//
//  Parser.XML.Element.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright 2020 Simon Whitty
//
//  Distributed under the permissive zlib license
//  Get the latest version from here:
//
//  https://github.com/swhitty/SwiftDraw
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
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
        let cx: DOM.Coordinate? = try att.parseCoordinate("cx")
        let cy: DOM.Coordinate? = try att.parseCoordinate("cy")
        let r: DOM.Coordinate = try att.parseCoordinate("r")
        return DOM.Circle(cx: cx, cy: cy, r: r)
    }

    func parseEllipse(_ att: AttributeParser) throws -> DOM.Ellipse {
        let cx: DOM.Coordinate? = try att.parseCoordinate("cx")
        let cy: DOM.Coordinate? = try att.parseCoordinate("cy")
        let rx: DOM.Coordinate = try att.parseCoordinate("rx")
        let ry: DOM.Coordinate = try att.parseCoordinate("ry")
        return DOM.Ellipse(cx: cx, cy: cy, rx: rx, ry: ry)
    }

    func parseRect(_ att: AttributeParser) throws -> DOM.Rect {
        let width: DOM.Coordinate = try att.parseCoordinate("width")
        let height: DOM.Coordinate = try att.parseCoordinate("height")
        let rect = DOM.Rect(width: width, height: height)

        rect.x = try att.parseCoordinate("x")
        rect.y = try att.parseCoordinate("y")
        rect.rx = try att.parseCoordinate("rx")
        rect.ry = try att.parseCoordinate("ry")

        return rect
    }

    func parsePolyline(_ att: AttributeParser) throws -> DOM.Polyline {
        return DOM.Polyline(points: try att.parsePoints("points"))
    }

    func parsePolygon(_ att: AttributeParser) throws -> DOM.Polygon {
        return DOM.Polygon(points: try att.parsePoints("points"))
    }

    func parseGraphicsElement(_ e: XML.Element) throws -> DOM.GraphicsElement? {
        var ge: DOM.GraphicsElement

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
        case "text":
            guard let text = try parseText(att, element: e) else { return nil }
            ge = text
        case "a":
            guard let anchor = try parseAnchor(att, element: e) else { return nil }
            ge = anchor
        case "use": ge = try parseUse(att)
        case "switch": ge = try parseSwitch(e)
        case "image": ge = try parseImage(att)
        case "svg": ge = try parseSVG(e)
        default: return nil
        }

        let elementAtt = try parseElementAttributes(att)
        ge.id = elementAtt.id
        ge.class = elementAtt.class

        ge.attributes = try parsePresentationAttributes(e)
        ge.style = try parseStyleAttributes(e)
        return ge
    }

    func parseContainerChildren(_ e: XML.Element) throws -> [DOM.GraphicsElement] {
        guard e.name == "svg" ||
                e.name == "clipPath" ||
                e.name == "pattern" ||
                e.name == "mask" ||
                e.name == "defs" ||
                e.name == "switch" ||
                e.name == "g" ||
                e.name == "a" else {
            throw Error.invalid
        }

        var children = [DOM.GraphicsElement]()

        for n in e.children {
            do {
                if let ge = try parseGraphicsElement(n) {
                    children.append(ge)
                }
            } catch let error {
                if let parseError = parseError(for: error, parsing: n, with: options) {
                    throw parseError
                }
            }
        }

        return children
    }

    func parseError(for error: Swift.Error, parsing element: XML.Element, with options: Options) -> XMLParser.Error? {
        guard options.contains(.skipInvalidElements) == false else {
            Self.logParsingError(for: error, filename: filename, parsing: element)
            return nil
        }

        switch error {
        case let XMLParser.Error.invalidElement(name, error, line, column):
            return .invalidElement(name: name,
                                   error: error,
                                   line: line,
                                   column: column)
        default:
            return .invalidElement(name: element.name,
                                   error: error,
                                   line: element.parsedLocation?.line,
                                   column: element.parsedLocation?.column)
        }
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

        let style = try parseStyleAttributes(styleText)
        var element = e.attributes
        element["style"] = nil
        return Attributes(parser: ValueParser(),
                          options: options,
                          element: element,
                          style: style)
    }

    func parsePresentationAttributes(_ e: XML.Element) throws -> DOM.PresentationAttributes {
        return try parsePresentationAttributes(e.attributes)
    }

    func parseStyleAttributes(_ e: XML.Element) throws -> DOM.PresentationAttributes {
        guard let styleText = e.attributes["style"] else {
            return DOM.PresentationAttributes()
        }

        let style = try parseStyleAttributes(styleText)
        return try parsePresentationAttributes(style)
    }

    func parseStyleAttributes(_ data: String) throws -> [String: String] {
        var scanner = XMLParser.Scanner(text: data)
        var style = [String: String]()

        while !scanner.isEOF {
            let att = try parseStyleAttribute(&scanner)
            style[att.0] = att.1
        }
        return style
    }

    private func parseStyleAttribute(_ scanner: inout  XMLParser.Scanner) throws -> (String, String) {
        let key = try scanner.scanString(upTo: ":")
        _ = try? scanner.scanString(":")
        let value = try scanner.scanString(upTo: ";")
        _ = try? scanner.scanString(";")

        return (key.trimmingCharacters(in: .whitespaces),
                value.trimmingCharacters(in: .whitespaces))
    }

    func parsePresentationAttributes(_ att: AttributeParser) throws -> DOM.PresentationAttributes {
        var el = DOM.PresentationAttributes()

        el.opacity = try att.parsePercentage("opacity")
        el.display = try att.parseRaw("display")
        el.color = try att.parseColor("color")

        el.stroke = try att.parseFill("stroke")
        el.strokeWidth = try att.parseFloat("stroke-width")
        el.strokeOpacity = try att.parsePercentage("stroke-opacity")
        el.strokeLineCap = try att.parseRaw("stroke-linecap")
        el.strokeLineJoin = try att.parseRaw("stroke-linejoin")

        //maybe handle this better
        // att.parseDashArray?
        if let dash = try att.parseString("stroke-dasharray") as String?,
           dash.trimmingCharacters(in: .whitespaces) == "none" {
            el.strokeDashArray = nil
        } else {
            el.strokeDashArray = try att.parseFloats("stroke-dasharray")
        }

        el.fill = try att.parseFill("fill")
        el.fillOpacity = try att.parsePercentage("fill-opacity")
        el.fillRule = try att.parseRaw("fill-rule")

        el.fontFamily = (try att.parseString("font-family"))?.trimmingCharacters(in: .whitespacesAndNewlines)
        el.fontSize = try att.parseFloat("font-size")
        el.textAnchor = try att.parseRaw("text-anchor")

        if let val = try? att.parseString("transform") {
            el.transform = try parseTransform(val)
        }

        el.clipPath = try att.parseUrlSelector("clip-path")
        el.clipRule = try att.parseRaw("clip-rule")
        el.mask = try att.parseUrlSelector("mask")
        el.filter = try att.parseUrlSelector("filter")

        return el
    }

    func parseElementAttributes(_ att: AttributeParser) throws -> ElementAttributes {
        var el = ElementAtt()
        el.id = try? att.parseString("id")
        el.class = try? att.parseString("class")
        return el
    }

    private struct ElementAtt: ElementAttributes {
        var id: String?
        var `class`: String?
    }

    static func logParsingError(for error: Swift.Error, filename: String?, parsing element: XML.Element? = nil) {
        let elementName = element.map { "<\($0.name)>" } ?? ""
        let filename = filename ?? ""
        switch error {
        case let XMLParser.Error.invalidDocument(error, element, line, column):
            let element = element.map { "<\($0)>" } ?? ""
            if let error = error {
                print("[parsing error]", filename, element, "line:", line, "column:", column, "error:", error, to: &.standardError)
            } else {
                print("[parsing error]", filename, element, "line:", line, "column:", column, to: &.standardError)
            }
        case let XMLParser.Error.invalidElement(name, error, line, column):
            if let line = line {
                print("[parsing error]", filename, "<\(name)>", "line:", line, "column:", column ?? -1, "error:", error, to: &.standardError)
            } else {
                print("[parsing error]", filename, "<\(name)>", "error:", error, to: &.standardError)
            }
        default:
            if let location = element?.parsedLocation {
                print("[parsing error]", filename, elementName, "line:", location.line, "column:", location.column, "error:", error, to: &.standardError)
            } else {
                print("[parsing error]", filename, elementName, "error:", error, to: &.standardError)
            }
        }
    }
}

extension DOM.PresentationAttributes {
    
    mutating func updateAttributes(from attributes: Self) {
        opacity = attributes.opacity
        display = attributes.display
        color = attributes.color
        stroke = attributes.stroke
        strokeWidth = attributes.strokeWidth
        strokeOpacity = attributes.strokeOpacity
        strokeLineCap = attributes.strokeLineCap
        strokeLineJoin = attributes.strokeLineJoin
        strokeDashArray = attributes.strokeDashArray
        fill = attributes.fill
        fillOpacity = attributes.fillOpacity
        fillRule = attributes.fillRule
        fontFamily = attributes.fontFamily
        fontSize = attributes.fontSize
        transform = attributes.transform
        clipPath = attributes.clipPath
        clipRule = attributes.clipRule
        mask = attributes.mask
        filter = attributes.filter
    }
}
