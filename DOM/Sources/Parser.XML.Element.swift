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

    func parseLine(_ att: any AttributeParser) throws -> DOM.Line {
        let x1: DOM.Coordinate = try att.parseCoordinate("x1")
        let y1: DOM.Coordinate = try att.parseCoordinate("y1")
        let x2: DOM.Coordinate = try att.parseCoordinate("x2")
        let y2: DOM.Coordinate = try att.parseCoordinate("y2")
        return DOM.Line(x1: x1, y1: y1, x2: x2, y2: y2)
    }

    func parseCircle(_ att: any AttributeParser) throws -> DOM.Circle {
        let cx: DOM.Coordinate? = try att.parseCoordinate("cx")
        let cy: DOM.Coordinate? = try att.parseCoordinate("cy")
        let r: DOM.Coordinate = try att.parseCoordinate("r")
        return DOM.Circle(cx: cx, cy: cy, r: r)
    }

    func parseEllipse(_ att: any AttributeParser) throws -> DOM.Ellipse {
        let cx: DOM.Coordinate? = try att.parseCoordinate("cx")
        let cy: DOM.Coordinate? = try att.parseCoordinate("cy")
        let rx: DOM.Coordinate = try att.parseCoordinate("rx")
        let ry: DOM.Coordinate = try att.parseCoordinate("ry")
        return DOM.Ellipse(cx: cx, cy: cy, rx: rx, ry: ry)
    }

    func parseRect(_ att: any AttributeParser) throws -> DOM.Rect {
        let width: DOM.Coordinate = try att.parseCoordinate("width")
        let height: DOM.Coordinate = try att.parseCoordinate("height")
        let rect = DOM.Rect(width: width, height: height)

        rect.x = try att.parseCoordinate("x")
        rect.y = try att.parseCoordinate("y")
        rect.rx = try att.parseCoordinate("rx")
        rect.ry = try att.parseCoordinate("ry")

        return rect
    }

    func parsePolyline(_ att: any AttributeParser) throws -> DOM.Polyline {
        return DOM.Polyline(points: try att.parsePoints("points"))
    }

    func parsePolygon(_ att: any AttributeParser) throws -> DOM.Polygon {
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
        applyStyle(of: e, to: ge)
        return ge
    }

    func parseGraphicsElements(_ elements: [XML.Element]) throws -> [DOM.GraphicsElement] {
        var result = [DOM.GraphicsElement]()
        var stack: [(XML.Element, parent: (any ContainerElement)?)] = elements
            .reversed()
            .map { ($0, parent: nil) }

        while let (element, parent) = stack.popLast() {
            try Task.checkCancellation()

            // not routed through skippingInvalid(_:_:): nested <svg> recurses through here and
            // the extra generic/closure frames overflow the small stacks of test threads
            let ge: DOM.GraphicsElement
            do {
                guard let parsed = try parseGraphicsElement(element) else { continue }
                ge = parsed
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                if let parseError = parseError(for: error, parsing: element, with: options) {
                    throw parseError
                }
                continue
            }

            if var parent {
                parent.childElements.append(ge)
            } else {
                result.append(ge)
            }

            if let container = ge as? any ContainerElement {
                stack.append(contentsOf: element.children.reversed().map { ($0, container) })
            }

        }

        return result
    }

    /// Appends `parse(element)` to `array`; with `.skipInvalidElements` an error drops the element instead of throwing.
    /// Kept out of line: the recursive `parse…s(_:)` walkers call it so their own frames stay small
    /// (500 nested groups must still fit the small stacks of test threads).
    @inline(never)
    func appendSkippingInvalid<T>(_ array: inout [T], _ element: XML.Element, _ parse: (XML.Element) throws -> T) throws {
        do {
            array.append(try parse(element))
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if let parseError = parseError(for: error, parsing: element, with: options) {
                throw parseError
            }
        }
    }

    func parseError(for error: any Swift.Error, parsing element: XML.Element, with options: Options) -> XMLParser.Error? {
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

        return DOM.Group()
    }

    func parseSwitch(_ e: XML.Element) throws -> DOM.Switch {
        guard e.name == "switch" else {
            throw Error.invalid
        }

        return DOM.Switch()
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

    /// SVG 1.1 §11.4: `none` or a list of non-negative lengths / percentages; returns nil when invalid.
    static func parseDashArray(_ text: String) -> [DOM.DashLength]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "none" {
            return []
        }
        let tokens = trimmed
            .split(whereSeparator: { $0 == "," || $0 == " " || $0 == "\t" || $0 == "\n" || $0 == "\r" })
            .map(String.init)
        guard !tokens.isEmpty else { return nil }
        var lengths = [DOM.DashLength]()
        for token in tokens {
            guard let length = parseDashLength(token), !length.isNegative else { return nil }
            lengths.append(length)
        }
        return lengths
    }

    static func parseDashLength(_ text: String) -> DOM.DashLength? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasSuffix("%") {
            guard let value = Float(text.dropLast()), value.isFinite else { return nil }
            return .percentage(value)
        }
        var scanner = XMLParser.Scanner(text: text)
        guard let value = try? scanner.scanCoordinate(), value.isFinite, scanner.isEOF else { return nil }
        return .absolute(value)
    }

    func parsePresentationAttributes(_ e: XML.Element) throws -> DOM.PresentationAttributes {
        return try parsePresentationAttributes(e.attributes)
    }

    // style="" in source order: the last valid declaration of a property wins,
    // `!important` ones are kept apart so they can override `!important` stylesheet rules
    func parseStyleDeclarations(_ e: XML.Element) -> (normal: DOM.PresentationAttributes, important: DOM.PresentationAttributes) {
        guard let styleText = e.attributes["style"] else {
            return (DOM.PresentationAttributes(), DOM.PresentationAttributes())
        }
        let declarations = Self.parseCSSDeclarations(styleText)
        let important = declarations.filter(\.important)
        // most style attributes have no !important: skip a second parse of an empty partition
        guard !important.isEmpty else {
            return (parsePresentationAttributes(declarations), DOM.PresentationAttributes())
        }
        return (parsePresentationAttributes(declarations.filter { !$0.important }),
                parsePresentationAttributes(important))
    }

    // Declarations are parsed once as a dictionary; only properties that repeat are
    // validated one at a time, so an invalid later value (`fill: red; fill: var(--x)`)
    // leaves the earlier valid one in place.
    func parsePresentationAttributes(_ declarations: [CSSDeclaration]) -> DOM.PresentationAttributes {
        var counts = [String: Int]()
        for d in declarations {
            counts[d.name, default: 0] += 1
        }
        var unique = [String: String]()
        for d in declarations where counts[d.name] == 1 {
            unique[d.name] = d.value
        }
        var result = (try? parsePresentationAttributes(unique)) ?? DOM.PresentationAttributes()
        for d in declarations where counts[d.name, default: 0] > 1 {
            if let att = try? parsePresentationAttributes([d.name: d.value]) {
                result = result.applyingAttributes(att)
            }
        }
        return result
    }

    // inline style and the stylesheet rules matched against the document tree
    func applyStyle(of e: XML.Element, to element: DOM.GraphicsElement) {
        let style = parseStyleDeclarations(e)
        element.style = style.normal
        element.importantStyle = style.important
        element.matchedStyle = styleContext.matcher?.match(e)
    }

    // A malformed declaration (`fill:`, `fill`, empty) is skipped; the others are kept.
    func parseStyleAttributes(_ data: String) throws -> [String: String] {
        var style = [String: String]()

        for declaration in data.split(separator: ";", omittingEmptySubsequences: true) {
            guard let colon = declaration.firstIndex(of: ":") else { continue }
            let key = declaration[declaration.startIndex..<colon].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = declaration[declaration.index(after: colon)...].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, !value.isEmpty else { continue }
            style[key] = value
        }
        return style
    }

    // An invalid value drops the attribute (the spec default applies) rather than the document.
    private func lenient<T>(_ parse: () throws -> T?) -> T? {
        (try? parse()) ?? nil
    }

    // opacity outside 0...1 is clamped; a non-numeric value is dropped
    private func opacity(_ att: any AttributeParser, _ key: String) -> DOM.Float? {
        if let value = lenient({ try att.parsePercentage(key) as DOM.Float? }) {
            return value
        }
        return lenient { try att.parseFloat(key) as DOM.Float? }.map { min(max($0, 0), 1) }
    }

    static func isNone(_ value: String) -> Bool {
        XMLParser.Attributes.removingImportant(from: value)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() == "none"
    }

    // `none` is kept as DOM.noneURL so it overrides a reference from a lower rule
    private func urlOrNone(_ att: any AttributeParser, _ key: String) -> DOM.URL? {
        if let raw = lenient({ try att.parseString(key) as String? }), Self.isNone(raw) {
            return DOM.noneURL
        }
        return lenient { try att.parseUrlSelector(key) }
    }

    func parsePresentationAttributes(_ att: any AttributeParser) throws -> DOM.PresentationAttributes {
        var el = DOM.PresentationAttributes()

        el.opacity = opacity(att, "opacity")
        el.display = lenient { try att.parseRaw("display") }
        el.visibility = lenient { try att.parseRaw("visibility") }
        el.color = lenient { try att.parseColor("color") }

        el.stroke = lenient { try att.parseFill("stroke") }
        // a negative stroke-width is an error: drop it (SVG 1.1 §11.4)
        el.strokeWidth = lenient { try att.parseFloat("stroke-width") }.flatMap { $0 < 0 ? nil : $0 }
        el.strokeOpacity = opacity(att, "stroke-opacity")
        el.strokeLineCap = lenient { try att.parseRaw("stroke-linecap") }
        el.strokeLineJoin = lenient { try att.parseRaw("stroke-linejoin") }

        // an invalid dash value is dropped (inherited), never fatal for the document
        if let dash = lenient({ try att.parseString("stroke-dasharray") as String? }) {
            el.strokeDashArray = Self.parseDashArray(dash)
        }
        if let offset = lenient({ try att.parseString("stroke-dashoffset") as String? }) {
            el.strokeDashOffset = Self.parseDashLength(offset)
        }

        el.fill = lenient { try att.parseFill("fill") }
        el.fillOpacity = opacity(att, "fill-opacity")
        el.fillRule = lenient { try att.parseRaw("fill-rule") }

        el.fontFamily = lenient { try att.parseFontFamily("font-family") }
        el.fontSize = lenient { try att.parseFloat("font-size") }
        el.textAnchor = lenient { try att.parseRaw("text-anchor") }
        el.dominantBaseline = lenient { try att.parseRaw("dominant-baseline") }

        if let val = try? att.parseString("transform") {
            // `none` is the identity, and still overrides a lower rule
            el.transform = Self.isNone(val) ? [] : try? parseTransform(val)
        }

        el.clipPath = urlOrNone(att, "clip-path")
        el.clipRule = lenient { try att.parseRaw("clip-rule") }
        el.mask = urlOrNone(att, "mask")
        el.filter = urlOrNone(att, "filter")

        el.stopColor = lenient { try att.parseFill("stop-color").getColor() }
        el.stopOpacity = opacity(att, "stop-opacity")

        return el
    }

    func parseElementAttributes(_ att: any AttributeParser) throws -> any ElementAttributes {
        var el = ElementAtt()
        el.id = try? att.parseString("id")
        el.class = try? att.parseString("class")
        return el
    }

    private struct ElementAtt: ElementAttributes {
        var id: String?
        var `class`: String?
    }

    func parseFontFace(_ att: any AttributeParser) throws -> DOM.FontFace {
        try DOM.FontFace(
            family: att.parseString("font-family").unquoted,
            src: att.parseFontSource("src")
        )
    }

    package static func logParsingError(for error: any Swift.Error, filename: String?, parsing element: XML.Element? = nil) {
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
        visibility = attributes.visibility
        color = attributes.color
        stroke = attributes.stroke
        strokeWidth = attributes.strokeWidth
        strokeOpacity = attributes.strokeOpacity
        strokeLineCap = attributes.strokeLineCap
        strokeLineJoin = attributes.strokeLineJoin
        strokeDashArray = attributes.strokeDashArray
        strokeDashOffset = attributes.strokeDashOffset
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
