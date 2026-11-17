//
//  Parser.XML.Text.swift
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

import Foundation

extension XMLParser {

    func parseText(_ att: any AttributeParser, element: XML.Element) throws -> DOM.Text? {
        let whiteSpace = parseWhiteSpace(element, att: att) ?? .collapse
        if let textPath = element.children.first(where: { $0.name == "textPath" }) {
            // text outside the <textPath> is not drawn
            guard let path = try parseTextPath(textPath, inheriting: whiteSpace) else { return nil }
            let text = try parseText(att, value: DOM.TextRun.plainText(of: path.runs))
            text.textPath = path
            return text
        }

        let runs = DOM.TextRun.collapsingWhitespace(try parseTextRuns(element), whiteSpace: whiteSpace)
        guard !DOM.TextRun.plainText(of: runs).isEmpty else { return nil }
        let text = DOM.Text(runs: runs)
        applyPositions(att, to: text)
        return text
    }

    func parseAnchor(_ att: any AttributeParser, element: XML.Element) throws -> DOM.Anchor? {
        let anchor = DOM.Anchor()
        // an <a> without a valid href (or xlink:href) is a plain group (SVG 2)
        anchor.href = try? att.parseHref()
        return anchor
    }

    /// A `<textPath>` with its runs of text and `<tspan>`, or nil when it has no characters to draw.
    func parseTextPath(_ e: XML.Element, inheriting whiteSpace: DOM.WhiteSpace = .collapse) throws -> DOM.TextPath? {
        let att = try parseAttributes(e)
        let runs = DOM.TextRun.collapsingWhitespace(
            try parseTextRuns(e),
            whiteSpace: parseWhiteSpace(e, att: att) ?? whiteSpace
        )
        guard !DOM.TextRun.plainText(of: runs).isEmpty else { return nil }

        let textPath = DOM.TextPath(href: try? att.parseHref(), runs: runs)
        // SVG 2: a `path` attribute takes precedence over `href`
        if let data = e.attributes["path"] {
            textPath.path = try? parsePath(from: data)
        }
        textPath.startOffset = try? att.parse("startOffset") { try Self.parseTextPathOffset($0) }
        textPath.side = e.attributes["side"].flatMap {
            DOM.TextPath.Side(rawValue: $0.trimmingCharacters(in: .whitespaces))
        }
        try applyTextContentAttributes(of: e, att: att, to: textPath)
        return textPath
    }

    static func parseTextPathOffset(_ value: String) throws -> DOM.TextPath.Offset {
        var scanner = XMLParser.Scanner(text: value)
        let number = try scanner.scanDouble()
        if scanner.scanStringIfPossible("%") {
            return .percentage(DOM.Float(number))
        }
        switch scanner.scanUnit() {
        case let unit?:
            return .length(DOM.Float(number.apply(unit: unit)))
        case nil:
            return .length(DOM.Float(number))
        }
    }

    /// The character data and `<tspan>` children of a text content element, in document order.
    func parseTextRuns(_ e: XML.Element) throws -> [DOM.TextRun] {
        var runs = [DOM.TextRun]()
        for node in e.nodes {
            switch node {
            case .text(let text):
                runs.append(.text(text))
            case .element(let child) where child.name == "tspan":
                runs.append(.span(try parseTextSpan(child)))
            case .element:
                // other children (<title>, <desc>, nested <textPath>…) draw nothing
                ()
            }
        }
        return runs
    }

    func parseTextSpan(_ e: XML.Element) throws -> DOM.TextSpan {
        // `em` lengths of the span (and of its children) are relative to its own font-size
        let fontSize = lengthContext.fontSize
        defer { lengthContext.fontSize = fontSize }
        let att = try parseAttributes(e)
        lengthContext.fontSize = self.fontSize(
            attributes: try parsePresentationAttributes(e),
            style: parseStyleDeclarations(e),
            matched: styleContext.matcher?.match(e),
            inheriting: fontSize
        )

        let span = DOM.TextSpan(runs: try parseTextRuns(e))
        try applyTextContentAttributes(of: e, att: att, to: span)
        span.xList = parseDefaultedLengthList(att, "x", .horizontal) ?? []
        span.yList = parseDefaultedLengthList(att, "y", .vertical) ?? []
        span.dxList = parseDefaultedLengthList(att, "dx", .horizontal) ?? []
        span.dyList = parseDefaultedLengthList(att, "dy", .vertical) ?? []
        span.rotateList = parseNumberList(att, "rotate") ?? []
        (span.textLength, span.lengthAdjust) = parseTextLength(att)
        span.whiteSpace = parseWhiteSpace(e, att: att)
        return span
    }

    /// CSS `white-space`, else `xml:space`; nil when neither is set, and the parent's applies.
    func parseWhiteSpace(_ e: XML.Element, att: any AttributeParser) -> DOM.WhiteSpace? {
        if let value = try? att.parseString("white-space") {
            switch XMLParser.Attributes.removingImportant(from: value).trimmingCharacters(in: .whitespaces).lowercased()
            {
            case "pre", "pre-wrap", "break-spaces":
                return .preserve
            case "normal", "nowrap", "pre-line":
                return .collapse
            default:
                break
            }
        }
        switch e.attributes["xml:space"]?.trimmingCharacters(in: .whitespaces) {
        case "preserve":
            return .preserve
        case "default":
            return .collapse
        default:
            return nil
        }
    }

    /// id, class, presentation attributes and style of a `<textPath>` or `<tspan>`
    func applyTextContentAttributes(of e: XML.Element, att: any AttributeParser, to element: DOM.GraphicsElement) throws
    {
        let elementAtt = try parseElementAttributes(att)
        element.id = elementAtt.id
        element.class = elementAtt.class
        element.attributes = try parsePresentationAttributes(e)
        applyStyle(of: e, to: element)
    }

    func parseText(_ att: any AttributeParser, value: String) throws -> DOM.Text {
        let element = DOM.Text(value: value)
        applyPositions(att, to: element)
        return element
    }

    /// SVG 2 §11.5.2: x, y, dx, dy and rotate are lists, one value per character.
    func applyPositions(_ att: any AttributeParser, to element: DOM.Text) {
        element.xList = parseDefaultedLengthList(att, "x", .horizontal) ?? []
        element.yList = parseDefaultedLengthList(att, "y", .vertical) ?? []
        element.dxList = parseDefaultedLengthList(att, "dx", .horizontal) ?? []
        element.dyList = parseDefaultedLengthList(att, "dy", .vertical) ?? []
        element.rotateList = parseNumberList(att, "rotate") ?? []
        (element.textLength, element.lengthAdjust) = parseTextLength(att)
        element.x = element.xList.first
        element.y = element.yList.first
    }

    /// A `<list-of-lengths>` separated by commas and/or whitespace; nil when missing or any value is invalid.
    func parseDefaultedLengthList(
        _ att: any AttributeParser,
        _ key: String,
        _ direction: LengthDirection
    ) -> [DOM.Coordinate]? {
        try? att.parse(key) { try parseLengthList($0, direction) } as [DOM.Coordinate]?
    }

    /// `textLength` (a non-negative length; `inherit` and invalid values are ignored) and `lengthAdjust`
    func parseTextLength(_ att: any AttributeParser) -> (DOM.Coordinate?, DOM.LengthAdjust?) {
        let length = (try? att.parse("textLength") { try resolveLength($0, .horizontal) } as DOM.Coordinate?)
            .flatMap { $0 }
            .flatMap { $0 >= 0 && $0.isFinite ? $0 : nil }
        let adjust = (try? att.parseString("lengthAdjust")).flatMap {
            DOM.LengthAdjust(rawValue: $0.trimmingCharacters(in: .whitespaces))
        }
        return (length, adjust)
    }

    /// A `<list-of-numbers>` such as `rotate`; nil when missing or any value is invalid (`5mm`).
    func parseNumberList(_ att: any AttributeParser, _ key: String) -> [DOM.Float]? {
        guard let value = try? att.parseString(key) else { return nil }
        let separators = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ","))
        let values = value.components(separatedBy: separators).filter { !$0.isEmpty }
        guard !values.isEmpty else { return nil }
        var numbers = [DOM.Float]()
        for value in values {
            var scanner = XMLParser.Scanner(text: value)
            guard let number = try? scanner.scanDouble(), scanner.isEOF else { return nil }
            numbers.append(DOM.Float(number))
        }
        return numbers
    }

    func parseLengthList(_ value: String, _ direction: LengthDirection) throws -> [DOM.Coordinate] {
        let separators = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ","))
        let values = value.components(separatedBy: separators).filter { !$0.isEmpty }
        guard !values.isEmpty else { throw XMLParser.Error.invalid }
        return try values.map { try resolveLength($0, direction) }
    }
}

package extension DOM.TextRun {

    /// The characters of the runs, in order
    static func plainText(of runs: [DOM.TextRun]) -> String {
        runs.map { run in
            switch run {
            case .text(let text): return text
            case .span(let span): return plainText(of: span.runs)
            }
        }.joined()
    }

    /// SVG 1.1 §10.15 white space. Where it collapses (xml:space="default"), newlines and tabs become
    /// spaces, runs of spaces collapse to one across element boundaries, and leading and trailing spaces
    /// of the whole text are removed. Where it is preserved, each newline and tab is a space and every
    /// space is kept. A `<tspan>` may change the mode for its own characters.
    static func collapsingWhitespace(_ runs: [DOM.TextRun], whiteSpace: DOM.WhiteSpace = .collapse) -> [DOM.TextRun] {
        var previousIsSpace = true
        var collapsed = collapse(runs, whiteSpace: whiteSpace, previousIsSpace: &previousIsSpace)
        trimTrailingSpace(&collapsed, whiteSpace: whiteSpace)
        return collapsed
    }

    private static func collapse(
        _ runs: [DOM.TextRun],
        whiteSpace: DOM.WhiteSpace,
        previousIsSpace: inout Bool
    ) -> [DOM.TextRun] {
        runs.map { run in
            switch run {
            case .text(let text):
                var result = ""
                for character in text {
                    if isXMLSpace(character) {
                        if whiteSpace == .preserve || !previousIsSpace { result.append(" ") }
                        previousIsSpace = true
                    } else {
                        result.append(character)
                        previousIsSpace = false
                    }
                }
                return .text(result)
            case .span(let span):
                span.runs = collapse(
                    span.runs,
                    whiteSpace: span.whiteSpace ?? whiteSpace,
                    previousIsSpace: &previousIsSpace
                )
                return .span(span)
            }
        }
    }

    /// XML white space only: a no-break space (U+00A0) is a character like any other
    private static func isXMLSpace(_ character: Character) -> Bool {
        character == " " || character == "\n" || character == "\t" || character == "\r" || character == "\r\n"
    }

    /// Removes the collapsible space at the end of the last characters; true once characters were found.
    @discardableResult
    private static func trimTrailingSpace(_ runs: inout [DOM.TextRun], whiteSpace: DOM.WhiteSpace) -> Bool {
        for index in runs.indices.reversed() {
            switch runs[index] {
            case .text(let text):
                guard !text.isEmpty else { continue }
                if whiteSpace == .collapse, text.hasSuffix(" ") {
                    let trimmed = String(text.dropLast())
                    runs[index] = .text(trimmed)
                    if trimmed.isEmpty { continue }
                }
                return true
            case .span(let span):
                if trimTrailingSpace(&span.runs, whiteSpace: span.whiteSpace ?? whiteSpace) { return true }
            }
        }
        return false
    }
}
