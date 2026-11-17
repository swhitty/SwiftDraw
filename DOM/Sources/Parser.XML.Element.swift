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
    func parseDefaultedLength(
        _ att: any AttributeParser,
        _ key: String,
        _ direction: LengthDirection
    ) -> DOM.Coordinate? {
        try? parseLength(att, key, direction) as DOM.Coordinate?
    }

    func parseLine(_ att: any AttributeParser) throws -> DOM.Line {
        // x1, y1, x2 and y2 default to 0
        DOM.Line(
            x1: parseDefaultedLength(att, "x1", .horizontal) ?? 0,
            y1: parseDefaultedLength(att, "y1", .vertical) ?? 0,
            x2: parseDefaultedLength(att, "x2", .horizontal) ?? 0,
            y2: parseDefaultedLength(att, "y2", .vertical) ?? 0
        )
    }

    /// A non-negative length; a negative value is an error (SVG 2 §10.2, §10.3, §10.4).
    func parseNonNegativeLength(
        _ att: any AttributeParser,
        _ key: String,
        _ direction: LengthDirection
    ) throws -> DOM.Coordinate {
        let length: DOM.Coordinate = try parseLength(att, key, direction)
        guard length >= 0 else { throw XMLParser.Error.invalid }
        return length
    }

    /// An `rx`/`ry` that may be `auto` (SVG 2 §10.3, §10.4): missing, invalid or negative values are `nil`.
    func parseAutoRadius(_ att: any AttributeParser, _ key: String, _ direction: LengthDirection) -> DOM.Coordinate? {
        guard let radius = parseDefaultedLength(att, key, direction), radius >= 0 else { return nil }
        return radius
    }

    func parseCircle(_ att: any AttributeParser) throws -> DOM.Circle {
        let r = try parseNonNegativeLength(att, "r", .other)
        return DOM.Circle(
            cx: parseDefaultedLength(att, "cx", .horizontal),
            cy: parseDefaultedLength(att, "cy", .vertical),
            r: r
        )
    }

    func parseEllipse(_ att: any AttributeParser) throws -> DOM.Ellipse {
        // SVG 2: an auto rx uses ry and vice versa; both auto is 0, which disables rendering
        let rx = parseAutoRadius(att, "rx", .horizontal)
        let ry = parseAutoRadius(att, "ry", .vertical)
        return DOM.Ellipse(
            cx: parseDefaultedLength(att, "cx", .horizontal),
            cy: parseDefaultedLength(att, "cy", .vertical),
            rx: rx ?? ry ?? 0,
            ry: ry ?? rx ?? 0
        )
    }

    func parseRect(_ att: any AttributeParser) throws -> DOM.Rect {
        let width = try parseNonNegativeLength(att, "width", .horizontal)
        let height = try parseNonNegativeLength(att, "height", .vertical)
        let rect = DOM.Rect(width: width, height: height)

        rect.x = parseDefaultedLength(att, "x", .horizontal)
        rect.y = parseDefaultedLength(att, "y", .vertical)
        rect.rx = parseAutoRadius(att, "rx", .horizontal)
        rect.ry = parseAutoRadius(att, "ry", .vertical)

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
        let style = parseStyleDeclarations(e)
        let matched = styleContext.matcher?.match(e)
        // `em` and `ex` lengths of this element (and font-size inherited by its children)
        lengthContext.fontSize = fontSize(
            attributes: attributes,
            style: style,
            matched: matched,
            inheriting: lengthContext.fontSize
        )

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
        case "symbol": ge = try parseSymbol(e, att)
        default: return nil
        }

        let elementAtt = try parseElementAttributes(att)
        ge.id = elementAtt.id
        ge.class = elementAtt.class
        parseConditionalAttributes(att, into: ge)

        ge.attributes = attributes
        ge.style = style.normal
        ge.importantStyle = style.important
        ge.matchedStyle = matched

        if let id = ge.id, referenceContext.firstWithID.contains(ObjectIdentifier(e)),
            referenceContext.elements[id] == nil
        {
            referenceContext.elements[id] = ge
        }
        return ge
    }

    func parseGraphicsElements(_ elements: [XML.Element]) throws -> [DOM.GraphicsElement] {
        var result = [DOM.GraphicsElement]()
        // each element inherits the font-size of its parent for `em` and `ex` lengths
        let fontSize = lengthContext.fontSize
        defer { lengthContext.fontSize = fontSize }
        var stack: [(XML.Element, parent: (any ContainerElement)?, fontSize: DOM.Float)] =
            elements
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

            // a nested <svg> has already parsed its own children (with its own defs and styles),
            // and a <symbol> in its own viewport
            if let container = ge as? any ContainerElement, !(ge is DOM.SVG), !(ge is DOM.Symbol) {
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
    func appendSkippingInvalid<T>(_ array: inout [T], _ element: XML.Element, _ parse: (XML.Element) throws -> T) throws
    {
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

    func parseError(for error: any Swift.Error, parsing element: XML.Element, with options: Options) -> XMLParser.Error?
    {
        guard options.contains(.skipInvalidElements) == false else {
            Self.logParsingError(for: error, filename: filename, parsing: element)
            return nil
        }

        switch error {
        case let XMLParser.Error.invalidElement(name, error, line, column):
            return .invalidElement(
                name: name,
                error: error,
                line: line,
                column: column
            )
        default:
            return .invalidElement(
                name: element.name,
                error: error,
                line: element.parsedLocation?.line,
                column: element.parsedLocation?.column
            )
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
            return Attributes(
                parser: ValueParser(),
                options: options,
                element: e.attributes,
                style: [:]
            )
        }

        let style = try parseStyleAttributes(styleText)
        var element = e.attributes
        element["style"] = nil
        return Attributes(
            parser: ValueParser(),
            options: options,
            element: element,
            style: style
        )
    }

    /// SVG 1.1 §11.4: `none` or a list of non-negative lengths / percentages; returns nil when invalid.
    static func parseDashArray(_ text: String) -> [DOM.DashLength]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "none" {
            return []
        }
        let tokens =
            trimmed
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

    /// `letter-spacing` and `word-spacing`: `normal` (0) or a length; `em` and `%` are of the font-size
    static func parseSpacing(_ text: String) -> DOM.DashLength? {
        let text = XMLParser.Attributes.removingImportant(from: text).trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.lowercased() != "normal" else { return .absolute(0) }
        return parseDashLength(text)
    }

    static func parseDashLength(_ text: String) -> DOM.DashLength? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasSuffix("%") {
            guard let value = Float(text.dropLast()), value.isFinite else { return nil }
            return .percentage(value)
        }
        var scanner = XMLParser.Scanner(text: text)
        guard let number = try? scanner.scanDouble(), number.isFinite else { return nil }
        let length: DOM.DashLength
        switch scanner.scanUnit() {
        case .em: length = .em(Float(number))
        case .ex: length = .em(Float(number / 2))
        case let unit?: length = .absolute(Float(number.apply(unit: unit)))
        case nil: length = .absolute(Float(number))
        }
        return scanner.isEOF ? length : nil
    }

    func parsePresentationAttributes(_ e: XML.Element) throws -> DOM.PresentationAttributes {
        return try parsePresentationAttributes(e.attributes)
    }

    // style="" in source order: the last valid declaration of a property wins,
    // `!important` ones are kept apart so they can override `!important` stylesheet rules
    func parseStyleDeclarations(
        _ e: XML.Element
    ) -> (normal: DOM.PresentationAttributes, important: DOM.PresentationAttributes) {
        guard let styleText = e.attributes["style"] else {
            return (DOM.PresentationAttributes(), DOM.PresentationAttributes())
        }
        let declarations = Self.parseCSSDeclarations(Self.removeCSSComments(from: styleText))
        let important = declarations.filter(\.important)
        // most style attributes have no !important: skip a second parse of an empty partition
        guard !important.isEmpty else {
            return (parsePresentationAttributes(declarations), DOM.PresentationAttributes())
        }
        return (
            parsePresentationAttributes(declarations.filter { !$0.important }),
            parsePresentationAttributes(important)
        )
    }

    // Declarations are parsed once as a dictionary; only properties that repeat are
    // validated one at a time, so an invalid later value (`fill: red; fill: var(--x)`)
    // leaves the earlier valid one in place.
    func parsePresentationAttributes(_ declarations: [CSSDeclaration]) -> DOM.PresentationAttributes {
        let declarations = Self.expandingShorthands(declarations)
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

    /// The `marker` shorthand sets `marker-start`, `marker-mid` and `marker-end` (SVG 2 §11.6.4), and
    /// `font` sets `font-style`, `font-weight`, `font-size` and `font-family` (CSS Fonts 4 §2.8).
    /// They are CSS properties only, not presentation attributes (SVG 2 §6.6); expanded in place so a
    /// later longhand still overrides them, and an earlier one is overridden. An invalid `font` is dropped.
    static func expandingShorthands(_ declarations: [CSSDeclaration]) -> [CSSDeclaration] {
        guard declarations.contains(where: { $0.name == "marker" || $0.name == "font" }) else { return declarations }
        return declarations.flatMap { d -> [CSSDeclaration] in
            switch d.name {
            case "marker":
                return ["marker-start", "marker-mid", "marker-end"].map {
                    CSSDeclaration(name: $0, value: d.value, important: d.important)
                }
            case "font":
                let value = XMLParser.Attributes.removingImportant(from: d.value)
                return (parseFontShorthand(value) ?? []).map {
                    CSSDeclaration(name: $0.name, value: $0.value, important: d.important)
                }
            default:
                return [d]
            }
        }
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

        let data = Self.removeCSSComments(from: data)
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

    // opacity outside 0...1 is clamped; an invalid value (`0.1mm`, `x`) is dropped
    private func opacity(_ att: any AttributeParser, _ key: String) -> DOM.Float? {
        lenient { try att.parseString(key) as String? }.flatMap(Self.parseOpacity)
    }

    /// `<number> | <percentage>` clamped to 0...1 (CSS Color 4 §11.1); nil when invalid.
    static func parseOpacity(_ text: String) -> DOM.Float? {
        let text = XMLParser.Attributes.removingImportant(from: text)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let isPercentage = text.hasSuffix("%")
        guard let number = Double(isPercentage ? String(text.dropLast()) : text), number.isFinite else {
            return nil
        }
        let value = isPercentage ? number / 100 : number
        return DOM.Float(min(max(value, 0), 1))
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
        // a negative stroke-width is an error: drop it (SVG 1.1 §11.4); absolute units in px,
        // `em` and `%` are kept for LayerTree to resolve
        el.strokeWidth = lenient { try att.parseString("stroke-width") as String? }
            .flatMap(Self.parseDashLength)
            .flatMap { $0.isNegative ? nil : $0 }
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
        // kept unresolved: `em`, `%`, keywords and `larger` are relative to the parent's font-size
        el.fontSize = lenient { try att.parseString("font-size") as String? }.flatMap(DOM.FontSize.init)
        el.fontWeight = lenient { try att.parseString("font-weight") as String? }.flatMap(DOM.FontWeight.init)
        el.fontStyle = lenient { try att.parseString("font-style") as String? }.flatMap(DOM.FontStyle.init)
        el.textAnchor = lenient { try att.parseRaw("text-anchor") }
        el.dominantBaseline = lenient { try att.parseString("dominant-baseline") as String? }
            .flatMap { DOM.TextBaseline(css: XMLParser.Attributes.removingImportant(from: $0)) }
        el.alignmentBaseline = lenient { try att.parseString("alignment-baseline") as String? }
            .flatMap { DOM.TextBaseline(css: XMLParser.Attributes.removingImportant(from: $0)) }
        el.baselineShift = lenient { try att.parseString("baseline-shift") as String? }
            .flatMap { DOM.BaselineShift(css: XMLParser.Attributes.removingImportant(from: $0)) }
        // a percentage is of the viewport width, as for other horizontal lengths (as resvg; CSS Text 4
        // makes it a percentage of the font-size)
        let viewportWidth = lengthContext.viewports.last?.width
        func spacing(_ key: String) -> DOM.DashLength? {
            guard let length = lenient({ try att.parseString(key) as String? }).flatMap(Self.parseSpacing) else {
                return nil
            }
            guard case .percentage(let percent) = length else { return length }
            return viewportWidth.map { .absolute(percent / 100 * $0) }
        }
        el.letterSpacing = spacing("letter-spacing")
        el.wordSpacing = spacing("word-spacing")

        if let val = try? att.parseString("transform") {
            // `none` is the identity, and still overrides a lower rule
            el.transform = Self.isNone(val) ? [] : try? parseTransform(val)
        }
        // not inherited: it only applies to the element's own transform
        el.transformOrigin = lenient { try att.parseString("transform-origin") as String? }.flatMap(
            parseTransformOrigin
        )

        el.clipPath = urlOrNone(att, "clip-path")
        el.clipRule = lenient { try att.parseRaw("clip-rule") }
        el.mask = urlOrNone(att, "mask")
        el.maskType = lenient { try att.parseRaw("mask-type") }
        el.colorInterpolation = lenient { try att.parseRaw("color-interpolation") }
        el.filter = lenient { try att.parseString("filter") as String? }.flatMap {
            try? Self.parseFilterValue(XMLParser.Attributes.removingImportant(from: $0))
        }
        el.overflow = lenient { try att.parseRaw("overflow") }

        el.markerStart = urlOrNone(att, "marker-start")
        el.markerMid = urlOrNone(att, "marker-mid")
        el.markerEnd = urlOrNone(att, "marker-end")
        // SVG 2 §13.6: an invalid value is dropped, so the inherited order applies
        el.paintOrder = lenient { try att.parseString("paint-order") as String? }.flatMap {
            DOM.PaintOrder(XMLParser.Attributes.removingImportant(from: $0))
        }

        el.stopColor = lenient { try att.parseFill("stop-color").getColor() }
        el.stopOpacity = opacity(att, "stop-opacity")

        return el
    }

    /// SVG 2 §5.8: `systemLanguage` and `requiredExtensions` are kept as written and evaluated when
    /// rendering. `requiredFeatures` was removed in SVG 2 and browsers treat it as true, so it is ignored.
    func parseConditionalAttributes(_ att: any AttributeParser, into element: DOM.GraphicsElement) {
        element.systemLanguage = try? att.parseString("systemLanguage")
        element.requiredExtensions = try? att.parseString("requiredExtensions")
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

    /// Splits a `src` list at its top-level commas. Commas inside `url(…)` (data URLs) or quotes are kept.
    static func splitFontSources(_ text: String) -> [String] {
        var entries = [String]()
        var current = ""
        var depth = 0
        var quote: Character?
        for character in text {
            if let open = quote {
                if character == open { quote = nil }
            } else if character == "\"" || character == "'" {
                quote = character
            } else if character == "(" {
                depth += 1
            } else if character == ")" {
                depth = max(0, depth - 1)
            } else if character == "," && depth == 0 {
                entries.append(current)
                current = ""
                continue
            }
            current.append(character)
        }
        entries.append(current)
        return
            entries
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
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

    package static func logParsingError(
        for error: any Swift.Error,
        filename: String?,
        parsing element: XML.Element? = nil
    ) {
        LogSink.error(makeParsingErrorMessage(for: error, filename: filename, parsing: element))
    }

    package static func makeParsingErrorMessage(
        for error: any Swift.Error,
        filename: String?,
        parsing element: XML.Element? = nil
    ) -> String {
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
                return
                    "[parsing error] \(filename) \(elementName) line: \(location.line) column: \(location.column) error: \(error)"
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
