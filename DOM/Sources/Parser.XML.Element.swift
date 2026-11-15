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

    /// A geometry value with a default (a position, a corner radius, an image size): a missing or invalid value
    /// leaves it unset so the default applies, rather than invalidating the element.
    /// Sizes without a usable default (`width`, `height`, `r`) are still required.
    /// Units, percentages and `em`/`ex` resolve as in `resolveLength(_:_:)`.
    func parseDefaultedLength(_ att: any AttributeParser, _ key: String, _ direction: LengthDirection) -> DOM.Coordinate? {
        try? parseLength(att, key, direction) as DOM.Coordinate?
    }

    func parseLine(_ att: any AttributeParser) throws -> DOM.Line {
        // x1, y1, x2 and y2 default to 0
        DOM.Line(x1: parseDefaultedLength(att, "x1", .horizontal) ?? 0,
                 y1: parseDefaultedLength(att, "y1", .vertical) ?? 0,
                 x2: parseDefaultedLength(att, "x2", .horizontal) ?? 0,
                 y2: parseDefaultedLength(att, "y2", .vertical) ?? 0)
    }

    func parseCircle(_ att: any AttributeParser) throws -> DOM.Circle {
        let r: DOM.Coordinate = try parseLength(att, "r", .other)
        return DOM.Circle(cx: parseDefaultedLength(att, "cx", .horizontal),
                          cy: parseDefaultedLength(att, "cy", .vertical),
                          r: r)
    }

    func parseEllipse(_ att: any AttributeParser) throws -> DOM.Ellipse {
        let rx: DOM.Coordinate = try parseLength(att, "rx", .horizontal)
        let ry: DOM.Coordinate = try parseLength(att, "ry", .vertical)
        return DOM.Ellipse(cx: parseDefaultedLength(att, "cx", .horizontal),
                           cy: parseDefaultedLength(att, "cy", .vertical),
                           rx: rx, ry: ry)
    }

    func parseRect(_ att: any AttributeParser) throws -> DOM.Rect {
        let width: DOM.Coordinate = try parseLength(att, "width", .horizontal)
        let height: DOM.Coordinate = try parseLength(att, "height", .vertical)
        let rect = DOM.Rect(width: width, height: height)

        rect.x = parseDefaultedLength(att, "x", .horizontal)
        rect.y = parseDefaultedLength(att, "y", .vertical)
        rect.rx = parseDefaultedLength(att, "rx", .horizontal)
        rect.ry = parseDefaultedLength(att, "ry", .vertical)

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
        let attributes = try parsePresentationAttributes(e)
        let style = try parseStyleAttributes(e)
        // `em` and `ex` lengths of this element (and font-size inherited by its children)
        lengthContext.fontSize = fontSize(of: e, attributes: attributes, style: style) ?? lengthContext.fontSize

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

        ge.attributes = attributes
        ge.style = style
        return ge
    }

    func parseGraphicsElements(_ elements: [XML.Element]) throws -> [DOM.GraphicsElement] {
        var result = [DOM.GraphicsElement]()
        // each element inherits the font-size of its parent for `em` and `ex` lengths
        let fontSize = lengthContext.fontSize
        defer { lengthContext.fontSize = fontSize }
        var stack: [(XML.Element, parent: (any ContainerElement)?, fontSize: DOM.Float)] = elements
            .reversed()
            .map { ($0, parent: nil, fontSize: fontSize) }

        while let (element, parent, inheritedFontSize) = stack.popLast() {
            try Task.checkCancellation()
            lengthContext.fontSize = inheritedFontSize

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

            // a nested <svg> has already parsed its own children (with its own defs and styles)
            if let container = ge as? any ContainerElement, !(ge is DOM.SVG) {
                let fontSize = lengthContext.fontSize
                stack.append(contentsOf: element.children.reversed().map { ($0, container, fontSize) })
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

    func parseStyleAttributes(_ e: XML.Element) throws -> DOM.PresentationAttributes {
        guard let styleText = e.attributes["style"] else {
            return DOM.PresentationAttributes()
        }

        let style = try parseStyleAttributes(styleText)
        return try parsePresentationAttributes(style)
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

    func parsePresentationAttributes(_ att: any AttributeParser) throws -> DOM.PresentationAttributes {
        var el = DOM.PresentationAttributes()

        el.opacity = opacity(att, "opacity")
        el.display = lenient { try att.parseRaw("display") }
        el.visibility = lenient { try att.parseRaw("visibility") }
        el.color = lenient { try att.parseColor("color") }

        el.stroke = lenient { try att.parseFill("stroke") }
        // a negative stroke-width is an error: drop it (SVG 1.1 §11.4); absolute units in px
        el.strokeWidth = lenient { try att.parseCoordinate("stroke-width") }.flatMap { $0 < 0 ? nil : $0 }
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
        // absolute units (`12pt`) in px; `em` and `%` keep their raw number as before
        // absolute units (`12pt`) in px; `em` and `%` keep their raw number as before
        el.fontSize = lenient { try att.parseCoordinate("font-size") }
        el.fontWeight = lenient { try att.parseString("font-weight") as String? }.flatMap(DOM.FontWeight.init)
        el.fontStyle = lenient { try att.parseString("font-style") as String? }.flatMap(DOM.FontStyle.init)
        el.textAnchor = lenient { try att.parseRaw("text-anchor") }
        el.dominantBaseline = lenient { try att.parseRaw("dominant-baseline") }

        if let val = try? att.parseString("transform") {
            el.transform = try? parseTransform(val)
        }

        el.clipPath = lenient { try att.parseUrlSelector("clip-path") }
        el.clipRule = lenient { try att.parseRaw("clip-rule") }
        el.mask = lenient { try att.parseUrlSelector("mask") }
        el.maskType = lenient { try att.parseRaw("mask-type") }
        el.filter = lenient { try att.parseUrlSelector("filter") }

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
            src: att.parseFontSource("src"),
            weight: (try? att.parseString("font-weight")).flatMap(Self.parseFontFaceWeight) ?? 400...400,
            style: (try? att.parseString("font-style")).flatMap(DOM.FontStyle.init) ?? .normal
        )
    }

    /// The `font-weight` descriptor of `@font-face`: a weight, or two for a variable font's range (`100 900`).
    /// `bolder` and `lighter` are not valid here.
    static func parseFontFaceWeight(_ text: String) -> ClosedRange<Int>? {
        let weights = text.split(separator: " ").map { DOM.FontWeight(String($0)) }
        func number(_ weight: DOM.FontWeight?) -> Int? {
            switch weight {
            case .normal: return 400
            case .bold: return 700
            case .number(let value): return value
            default: return nil
            }
        }
        switch weights.count {
        case 1:
            return number(weights[0]).map { $0...$0 }
        case 2:
            guard let a = number(weights[0]), let b = number(weights[1]) else { return nil }
            return min(a, b)...max(a, b)
        default:
            return nil
        }
    }

    package static func logParsingError(for error: any Swift.Error, filename: String?, parsing element: XML.Element? = nil) {
        LogSink.error(makeParsingErrorMessage(for: error, filename: filename, parsing: element))
    }

    package static func makeParsingErrorMessage(for error: any Swift.Error, filename: String?, parsing element: XML.Element? = nil) -> String {
        let elementName = element.map { "<\($0.name)>" } ?? ""
        let filename = filename ?? ""
        switch error {
        case let XMLParser.Error.invalidDocument(error, element, line, column):
            let element = element.map { "<\($0)>" } ?? ""
            if let error = error {
                return "[parsing error] \(filename) \(element) line: \(line) column: \(column) error: \(error)"
            } else {
                return "[parsing error] \(filename) \(element) line: \(line) column: \(column)"
            }
        case let XMLParser.Error.invalidElement(name, error, line, column):
            if let line = line {
                return "[parsing error] \(filename) <\(name)> line: \(line) column: \(column ?? -1) error: \(error)"
            } else {
                return "[parsing error] \(filename) <\(name)> error: \(error)"
            }
        default:
            if let location = element?.parsedLocation {
                return "[parsing error] \(filename) \(elementName) line: \(location.line) column: \(location.column) error: \(error)"
            } else {
                return "[parsing error] \(filename) \(elementName) error: \(error)"
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
