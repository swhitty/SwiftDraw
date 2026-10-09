//
//  Parser.XML.StyleSheet.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 18/8/22.
//  Copyright 2022 Simon Whitty
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

    func findStyleElements(within element: XML.Element) -> [XML.Element] {
        return element.children.reduce(into: [XML.Element]()) {
            if $1.name == "style" {
                $0.append($1)
            } else {
                $0.append(contentsOf: findStyleElements(within: $1))
            }
        }
    }

    func parseStyleSheetElements(within element: XML.Element) -> [DOM.StyleSheet] {
        var sheets = [DOM.StyleSheet]()

        for e in findStyleElements(within: element) {
            do {
                try sheets.append(parseStyleSheetElement(e.innerText))
            } catch {
                Self.logParsingError(for: error, filename: filename, parsing: e)
            }
        }

        return sheets
    }

    // stop-color and stop-opacity through the cascade (attribute < rules < style="" < !important),
    // e.g. Illustrator's <stop class="st0"/> with .st0 { stop-color: … }; nil without a stylesheet
    func cascadedStop(_ e: XML.Element) -> (color: DOM.Color?, opacity: DOM.Float?)? {
        guard let matched = styleContext.matcher?.match(e) else { return nil }
        let style = parseStyleDeclarations(e)
        let attributes = ((try? parsePresentationAttributes(e.attributes)) ?? DOM.PresentationAttributes())
            .applyingAttributes(matched.attributes)
            .applyingAttributes(style.normal)
            .applyingAttributes(matched.importantAttributes)
            .applyingAttributes(style.important)
        return (attributes.stopColor, attributes.stopOpacity)
    }

    // CSS Syntax Level 3 error recovery: a malformed rule or declaration is dropped on its own,
    // the rest of the sheet is kept.
    func parseStyleSheetElement(_ text: String?) throws -> DOM.StyleSheet {
        var sheet = DOM.StyleSheet()
        guard let text else { return sheet }
        let blocks = Self.parseCSSBlocks(text)

        for (prelude, declarations) in blocks.rules {
            guard let selectors = DOM.StyleSheet.ComplexSelector.parseList(prelude) else { continue }
            let important = declarations.filter(\.important)
            let attributes = parsePresentationAttributes(important.isEmpty ? declarations : declarations.filter { !$0.important })
            let importantAttributes = important.isEmpty ? DOM.PresentationAttributes() : parsePresentationAttributes(important)

            for selector in selectors {
                sheet.rules.append(DOM.StyleSheet.Rule(selector: selector,
                                                       attributes: attributes,
                                                       importantAttributes: importantAttributes))
                if let simple = selector.simple {
                    sheet.attributes[simple] = (sheet.attributes[simple] ?? DOM.PresentationAttributes())
                        .applyingAttributes(attributes)
                        .applyingAttributes(importantAttributes)
                }
            }
        }

        sheet.fonts = blocks.fontFaces.compactMap { try? parseFontFace(Self.makeDictionary($0)) }
        return sheet
    }

    static func parseSelectorEntries(_ text: String?) throws -> [DOM.StyleSheet.Selector: [String: String]] {
        guard let text = text else { return [:] }
        var entries = [DOM.StyleSheet.Selector: [String: String]]()

        for (prelude, declarations) in parseCSSBlocks(text).rules {
            guard let selectors = DOM.StyleSheet.ComplexSelector.parseList(prelude) else { continue }
            for selector in selectors.compactMap(\.simple) {
                var copy = entries[selector] ?? [:]
                for d in declarations {
                    copy[d.name] = d.value
                }
                entries[selector] = copy
            }
        }

        return entries
    }

    static func parseFontFaceEntries(_ text: String?) throws -> [[String: String]] {
        guard let text = text else { return [] }
        return parseCSSBlocks(text).fontFaces.map(makeDictionary)
    }

    struct CSSDeclaration: Equatable {
        var name: String
        var value: String
        var important: Bool
    }

    static func makeDictionary(_ declarations: [CSSDeclaration]) -> [String: String] {
        var dict = [String: String]()
        for d in declarations {
            dict[d.name] = d.value
        }
        return dict
    }

    // Splits a sheet into qualified rules and @font-face blocks; other at-rules
    // (@media, @supports, @import…) are skipped with their nested blocks.
    static func parseCSSBlocks(_ text: String) -> (rules: [(prelude: String, declarations: [CSSDeclaration])], fontFaces: [[CSSDeclaration]]) {
        let chars = Array(removeCSSComments(from: text))
        var i = 0
        var rules = [(prelude: String, declarations: [CSSDeclaration])]()
        var fontFaces = [[CSSDeclaration]]()

        // Reads up to (not including) the first top-level character in `stops`, skipping strings, (), [].
        func scanPrelude(stops: Set<Character>) -> String {
            var result = ""
            var depth = 0
            var quote: Character?
            while i < chars.count {
                let c = chars[i]
                if let q = quote {
                    if c == "\\", i + 1 < chars.count {
                        result.append(c)
                        result.append(chars[i + 1])
                        i += 2
                        continue
                    } else if c == q || c.isNewline {
                        // an unescaped newline ends a string (CSS Syntax §4.3.5, bad-string)
                        quote = nil
                    }
                } else if c == "\\", i + 1 < chars.count {
                    // an escaped character is never a delimiter
                    result.append(c)
                    result.append(chars[i + 1])
                    i += 2
                    continue
                } else if c == "\"" || c == "'" {
                    quote = c
                } else if c == "(" || c == "[" {
                    depth += 1
                } else if c == ")" || c == "]" {
                    depth = max(0, depth - 1)
                } else if (depth == 0 || c == "{") && stops.contains(c) {
                    // a block always starts at `{`, even after an unclosed `(` or `[`
                    return result
                }
                result.append(c)
                i += 1
            }
            return result
        }

        // Reads a {} block whose opening brace is at i; returns its inner text.
        func scanBlock() -> String {
            i += 1
            var result = ""
            var depth = 1
            var quote: Character?
            while i < chars.count {
                let c = chars[i]
                i += 1
                if let q = quote {
                    if c == "\\", i < chars.count {
                        result.append(c)
                        result.append(chars[i])
                        i += 1
                        continue
                    } else if c == q || c.isNewline {
                        quote = nil
                    }
                } else if c == "\\", i < chars.count {
                    result.append(c)
                    result.append(chars[i])
                    i += 1
                    continue
                } else if c == "\"" || c == "'" {
                    quote = c
                } else if c == "{" {
                    depth += 1
                } else if c == "}" {
                    depth -= 1
                    if depth == 0 { return result }
                }
                result.append(c)
            }
            return result
        }

        while i < chars.count {
            let c = chars[i]
            if c.isWhitespace || c == "}" || c == ";" {
                i += 1
                continue
            }
            // HTML comment markers are allowed at the top level of a sheet
            if chars[i...].starts(with: "<!--") {
                i += 4
                continue
            }
            if chars[i...].starts(with: "-->") {
                i += 3
                continue
            }
            if c == "@" {
                let prelude = scanPrelude(stops: ["{", ";"])
                guard i < chars.count, chars[i] == "{" else {
                    i += 1
                    continue
                }
                let block = scanBlock()
                let name = prelude.dropFirst().prefix { !$0.isWhitespace }.lowercased()
                if name == "font-face" {
                    fontFaces.append(parseCSSDeclarations(block))
                }
                continue
            }

            let prelude = scanPrelude(stops: ["{"])
            guard i < chars.count else { break }
            let block = scanBlock()
            rules.append((prelude.trimmingCharacters(in: .whitespacesAndNewlines), parseCSSDeclarations(block)))
        }

        return (rules, fontFaces)
    }

    static func hasBadString(_ text: String) -> Bool {
        var quote: Character?
        var escaped = false
        for c in text {
            if escaped {
                escaped = false
            } else if c == "\\" {
                escaped = true
            } else if let q = quote {
                if c == q { quote = nil }
                if c.isNewline { return true }
            } else if c == "\"" || c == "'" {
                quote = c
            }
        }
        // a string still open at the end of the value is closed by EOF, not bad
        return false
    }

    // A declaration without a name or a value is skipped; the others are kept (CSS Syntax §5.4.5).
    static func parseCSSDeclarations(_ text: String) -> [CSSDeclaration] {
        DOM.StyleSheet.ComplexSelector.splitTopLevel(text, separator: ";").compactMap { declaration in
            guard let colon = declaration.firstIndex(of: ":") else { return nil }
            let name = declaration[..<colon].trimmingCharacters(in: .whitespacesAndNewlines)
            var value = declaration[declaration.index(after: colon)...].trimmingCharacters(in: .whitespacesAndNewlines)
            // a nested block (CSS nesting) is not a declaration
            guard !name.isEmpty, !name.contains("{"), !name.contains("}") else { return nil }

            // a string cut by a newline makes the declaration invalid
            guard !Self.hasBadString(String(declaration[declaration.index(after: colon)...])) else { return nil }

            let stripped = XMLParser.Attributes.removingImportant(from: value)
            let important = stripped != value
            value = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return nil }
            // CSS-wide keywords are not supported: drop them so a lower rule still applies
            guard !["inherit", "initial", "unset", "revert", "revert-layer"].contains(value.lowercased()) else { return nil }
            return CSSDeclaration(name: name.hasPrefix("--") ? name : name.lowercased(), value: value, important: important)
        }
    }

    static func removeCSSComments(from text: String) -> String {
        // non-greedy, across lines; an unterminated comment runs to the end of the sheet
        let regex = try! NSRegularExpression(pattern: "/\\*[\\s\\S]*?(?:\\*/|$)", options: [])
        let range = NSMakeRange(0, (text as NSString).length)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
    }
}

extension XMLParser.Scanner {

    enum BlockDeclaration {
        case selector([DOM.StyleSheet.Selector])
        case atRule(String)
    }

    mutating func scanNextBlockDecl() throws -> (BlockDeclaration, [String: String])? {
        if let attributes = try scanNextFontFace() {
            return (.atRule("font-face"), attributes)
        }
        if let name = scanUnknownAtRule() {
            return (.atRule(name), [:])
        }
        let selectorTypes = try scanSelectorTypes()
        guard !selectorTypes.isEmpty else { return nil }
        return (.selector(selectorTypes), try scanAtttributes())
    }

    private mutating func scanNextClass() throws -> String? {
        guard doScanString(".") else { return nil }
        return try scanSelectorName()
    }

    private mutating func scanNextID() throws -> String? {
        guard doScanString("#") else { return nil }
        return try scanSelectorName()
    }

    mutating func scanNextFontFace() throws -> [String: String]? {
        guard doScanString("@font-face") else {
            return nil
        }
        return try scanAtttributes()
    }

    /// Skips unknown @ rules (e.g. @media, @supports) including nested blocks.
    /// Returns the rule name if an unknown @ rule was consumed, nil otherwise.
    mutating func scanUnknownAtRule() -> String? {
        guard doScanString("@") else { return nil }
        guard let name = try? scanString(upTo: .init(charactersIn: "{")),
              doScanString("{") else { return nil }
        var depth = 1
        while depth > 0 && !isEOF {
            if doScanString("{") {
                depth += 1
            } else if doScanString("}") {
                depth -= 1
            } else {
                _ = try? scanString(upTo: .init(charactersIn: "{}"))
            }
        }
        return name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private mutating func scanNextElement() throws -> String? {
        do {
            return try scanSelectorName()
        } catch {
            guard isEOF else {
                throw error
            }
            return nil
        }
    }

    private mutating func scanSelectorName() throws -> String? {
        guard !nextScanString("{") else { return nil }
        let name = try scanString(upTo: .init(charactersIn: "{,")).trimmingCharacters(in: .whitespacesAndNewlines)
        scanStringIfPossible(",")
        return name
    }

     mutating func scanSelectorTypes() throws -> [DOM.StyleSheet.Selector] {
        var selectors: [DOM.StyleSheet.Selector] = []
        while let next = try scanNextSelectorType() {
            selectors.append(next)
        }
        return selectors
    }

    private mutating func scanNextSelectorType() throws -> DOM.StyleSheet.Selector? {
        if let name = try scanNextClass() {
            return .class(name)
        } else if let name = try scanNextID() {
            return .id(name)
        } else if let name = try scanNextElement() {
            return .element(name)
        } else {
            return nil
        }
    }

    mutating func scanAtttributes() throws -> [String: String] {
        _ = doScanString("{")
        var attributes = [String: String]()
        var last: String?
        repeat {
            last = try scanNextAttributeKey()
            if let last = last {
                let val = try scanNextAttributeValue()
                attributes[last] = val
            }
        } while last != nil
        return attributes
    }

    mutating func scanNextAttribute() throws -> (key: String, value: String)? {
        if let key = try scanNextAttributeKey() {
            return (key: key, value: try scanNextAttributeValue())
        }
        return nil
    }

    mutating func scanNextAttributeKey() throws -> String? {
        guard !doScanString("}") else { return nil }
        let key = try scanString(upTo: ":")
        _ = try scanString(":")
        return key.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    mutating func scanNextAttributeValue() throws -> String {
        let value = try scanString(upTo: .init(charactersIn: ";\n}"), preservingStrings: true)
        _ = doScanString(";")
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension String {
    var unquoted: String {
        if (hasPrefix("'") && hasSuffix("'")) ||
           (hasPrefix("\"") && hasSuffix("\"")) {
            return String(dropFirst().dropLast())
        }
        return self
    }
}
//Allow Dictionary to become an attribute parser
extension Dictionary: AttributeParser where Key == String, Value == String {
    package var parser: any AttributeValueParser { return XMLParser.ValueParser() }
    package var options: XMLParser.Options { return [] }

    package func parse<T>(_ key: String, _ exp: (String) throws -> T) throws -> T {
        guard let value = self[key] else {
            throw XMLParser.Error.missingAttribute(name: key)
        }
        return try exp(XMLParser.Attributes.removingImportant(from: value))
    }
}
