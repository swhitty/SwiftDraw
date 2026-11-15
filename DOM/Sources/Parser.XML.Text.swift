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
        if let textPath = element.children.first(where: { $0.name == "textPath" }) {
            // text outside the <textPath> is not drawn
            guard let path = try parseTextPath(textPath) else { return nil }
            let text = try parseText(att, value: DOM.TextRun.plainText(of: path.runs))
            text.textPath = path
            return text
        }

        guard
            let text = element.innerText?.trimmingCharacters(in: .whitespacesAndNewlines),
            !text.isEmpty else {
            if let tspan = element.children.first(where: { $0.name == "tspan" }),
               let text = tspan.innerText?.trimmingCharacters(in: .whitespacesAndNewlines) {
                let tspanAtt = try parseAttributes(tspan)
                return try parseText(tspanAtt, value: text)
            }
            return nil
        }

        return try parseText(att, value: text)
    }

    func parseAnchor(_ att: any AttributeParser, element: XML.Element) throws -> DOM.Anchor? {
        let anchor = DOM.Anchor()
        // an <a> without a valid href (or xlink:href) is a plain group (SVG 2)
        anchor.href = try? att.parseHref()
        return anchor
    }

    /// A `<textPath>` with its runs of text and `<tspan>`, or nil when it has no characters to draw.
    func parseTextPath(_ e: XML.Element) throws -> DOM.TextPath? {
        let att = try parseAttributes(e)
        let runs = DOM.TextRun.collapsingWhitespace(try parseTextRuns(e))
        guard !DOM.TextRun.plainText(of: runs).isEmpty else { return nil }

        let textPath = DOM.TextPath(href: try? att.parseHref(), runs: runs)
        // SVG 2: a `path` attribute takes precedence over `href`
        if let data = e.attributes["path"] {
            textPath.path = try? parsePath(from: data)
        }
        textPath.startOffset = try? att.parse("startOffset") { try Self.parseTextPathOffset($0) }
        textPath.side = e.attributes["side"].flatMap { DOM.TextPath.Side(rawValue: $0.trimmingCharacters(in: .whitespaces)) }
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
                let span = DOM.TextSpan(runs: try parseTextRuns(child))
                try applyTextContentAttributes(of: child, att: try parseAttributes(child), to: span)
                runs.append(.span(span))
            case .element:
                // other children (<title>, <desc>, nested <textPath>…) draw nothing
                ()
            }
        }
        return runs
    }

    /// id, class, presentation attributes and style of a `<textPath>` or `<tspan>`
    func applyTextContentAttributes(of e: XML.Element, att: any AttributeParser, to element: DOM.GraphicsElement) throws {
        let elementAtt = try parseElementAttributes(att)
        element.id = elementAtt.id
        element.class = elementAtt.class
        element.attributes = try parsePresentationAttributes(e)
        applyStyle(of: e, to: element)
    }

    func parseText(_ att: any AttributeParser, value: String) throws -> DOM.Text {
        let element = DOM.Text(value: value)
        element.x = parseDefaultedLength(att, "x", .horizontal)
        element.y = parseDefaultedLength(att, "y", .vertical)
        return element
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

    /// SVG 1.1 §10.15 white space (xml:space="default"): newlines and tabs become spaces, runs of spaces
    /// collapse to one across element boundaries, and leading and trailing spaces are removed.
    static func collapsingWhitespace(_ runs: [DOM.TextRun]) -> [DOM.TextRun] {
        var previousIsSpace = true
        var collapsed = collapse(runs, previousIsSpace: &previousIsSpace)
        trimTrailingSpace(&collapsed)
        return collapsed
    }

    private static func collapse(_ runs: [DOM.TextRun], previousIsSpace: inout Bool) -> [DOM.TextRun] {
        runs.map { run in
            switch run {
            case .text(let text):
                var result = ""
                for character in text {
                    if character.isWhitespace {
                        if !previousIsSpace { result.append(" ") }
                        previousIsSpace = true
                    } else {
                        result.append(character)
                        previousIsSpace = false
                    }
                }
                return .text(result)
            case .span(let span):
                span.runs = collapse(span.runs, previousIsSpace: &previousIsSpace)
                return .span(span)
            }
        }
    }

    /// Removes the space at the end of the last characters; true once characters were found.
    @discardableResult
    private static func trimTrailingSpace(_ runs: inout [DOM.TextRun]) -> Bool {
        for index in runs.indices.reversed() {
            switch runs[index] {
            case .text(let text):
                guard !text.isEmpty else { continue }
                if text.hasSuffix(" ") {
                    let trimmed = String(text.dropLast())
                    runs[index] = .text(trimmed)
                    if trimmed.isEmpty { continue }
                }
                return true
            case .span(let span):
                if trimTrailingSpace(&span.runs) { return true }
            }
        }
        return false
    }
}
