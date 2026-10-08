//
//  DOM.StyleSheet.Selector.swift
//  SwiftDraw
//
//  Added by Misoservices for the Backdrop fork of SwiftDraw (altered source version).
//  Copyright 2026 Misoservices
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

package extension DOM.StyleSheet {

    // One selector of a rule, kept in source order with its declarations.
    struct Rule {
        package var selector: ComplexSelector
        package var attributes: DOM.PresentationAttributes
        package var importantAttributes: DOM.PresentationAttributes

        package init(selector: ComplexSelector,
                     attributes: DOM.PresentationAttributes,
                     importantAttributes: DOM.PresentationAttributes = DOM.PresentationAttributes()) {
            self.selector = selector
            self.attributes = attributes
            self.importantAttributes = importantAttributes
        }
    }

    // Selectors Level 3: compound selectors joined by combinators, matched right to left.
    struct ComplexSelector: Hashable {
        package var compounds: [Compound]
        // combinators[i] joins compounds[i] and compounds[i + 1]
        package var combinators: [Combinator]

        package enum Combinator: Hashable {
            case descendant
            case child
            case adjacentSibling
            case generalSibling
        }

        package struct Compound: Hashable {
            // nil is the universal selector
            package var element: String?
            package var ids: [String] = []
            package var classes: [String] = []
            package var attributes: [AttributeMatch] = []
            package var pseudoClasses: [PseudoClass] = []
        }

        package struct AttributeMatch: Hashable {
            package var name: String
            package var match: Operator?
            package var value: String
            package var caseInsensitive: Bool

            package enum Operator: String, Hashable {
                case equals = "="
                case includes = "~="
                case dashMatch = "|="
                case prefix = "^="
                case suffix = "$="
                case substring = "*="
            }
        }

        package enum PseudoClass: Hashable {
            case firstChild
            case lastChild
            case onlyChild
            case root
            // valid syntax that never matches a static document (:hover, ::before, :nth-child(2n)…)
            case unsupported(String)
        }

        // (ids, classes + attributes + pseudo-classes, types) — Selectors Level 3 §9
        package var specificity: Specificity {
            var s = Specificity(a: 0, b: 0, c: 0)
            for c in compounds {
                s.a += c.ids.count
                s.b += c.classes.count + c.attributes.count + c.pseudoClasses.count
                s.c += c.element == nil ? 0 : 1
            }
            return s
        }

        // The upstream selector model, when this selector is one of its three forms.
        package var simple: Selector? {
            guard compounds.count == 1 else { return nil }
            let c = compounds[0]
            guard c.attributes.isEmpty, c.pseudoClasses.isEmpty else { return nil }
            switch (c.element, c.ids.count, c.classes.count) {
            case (let name?, 0, 0): return .element(name)
            case (nil, 1, 0): return .id(c.ids[0])
            case (nil, 0, 1): return .class(c.classes[0])
            default: return nil
            }
        }
    }

    struct Specificity: Comparable {
        package var a: Int
        package var b: Int
        package var c: Int

        package static func < (lhs: Self, rhs: Self) -> Bool {
            (lhs.a, lhs.b, lhs.c) < (rhs.a, rhs.b, rhs.c)
        }
    }

    // The declarations of every matching rule, already sorted by specificity then source order.
    struct Matched {
        package var attributes = DOM.PresentationAttributes()
        package var importantAttributes = DOM.PresentationAttributes()

        package init(attributes: DOM.PresentationAttributes = DOM.PresentationAttributes(),
                     importantAttributes: DOM.PresentationAttributes = DOM.PresentationAttributes()) {
            self.attributes = attributes
            self.importantAttributes = importantAttributes
        }
    }
}

// MARK: - Parsing

package extension DOM.StyleSheet.ComplexSelector {

    // Parses a selector list (`a, b > c`). Returns nil when any selector is malformed:
    // CSS drops the whole rule then (Selectors Level 3 §5).
    static func parseList(_ text: String) -> [Self]? {
        let parts = splitTopLevel(text, separator: ",")
        var result = [Self]()
        for part in parts {
            guard let selector = parse(part) else { return nil }
            result.append(selector)
        }
        return result.isEmpty ? nil : result
    }

    static func parse(_ text: String) -> Self? {
        var s = SelectorScanner(text)
        var compounds = [Compound]()
        var combinators = [Combinator]()

        s.skipWhitespace()
        while !s.isEOF {
            if !compounds.isEmpty {
                let hadSpace = s.skipWhitespace()
                guard !s.isEOF else { break }
                if let c = s.scanCombinator() {
                    combinators.append(c)
                    s.skipWhitespace()
                } else if hadSpace {
                    combinators.append(.descendant)
                } else {
                    return nil
                }
            }
            guard let compound = s.scanCompound() else { return nil }
            compounds.append(compound)
        }

        guard !compounds.isEmpty, combinators.count == compounds.count - 1 else { return nil }
        return Self(compounds: compounds, combinators: combinators)
    }

    // Splits on `separator` outside strings, brackets and parentheses.
    static func splitTopLevel(_ text: String, separator: Character) -> [String] {
        var parts = [String]()
        var current = ""
        var depth = 0
        var quote: Character?
        var escaped = false
        for ch in text {
            if escaped {
                escaped = false
            } else if ch == "\\" {
                escaped = true
            } else if let q = quote {
                if ch == q { quote = nil }
            } else if ch == "\"" || ch == "'" {
                quote = ch
            } else if ch == "(" || ch == "[" {
                depth += 1
            } else if ch == ")" || ch == "]" {
                depth = max(0, depth - 1)
            } else if ch == separator && depth == 0 {
                parts.append(current)
                current = ""
                continue
            }
            current.append(ch)
        }
        parts.append(current)
        return parts
    }
}

private struct SelectorScanner {
    let chars: [Character]
    var index = 0

    init(_ text: String) {
        chars = Array(text)
    }

    var isEOF: Bool { index >= chars.count }
    var current: Character? { isEOF ? nil : chars[index] }

    @discardableResult
    mutating func skipWhitespace() -> Bool {
        let start = index
        while let c = current, c.isWhitespace { index += 1 }
        return index > start
    }

    mutating func scan(_ c: Character) -> Bool {
        guard current == c else { return false }
        index += 1
        return true
    }

    mutating func scanCombinator() -> DOM.StyleSheet.ComplexSelector.Combinator? {
        if scan(">") { return .child }
        if scan("+") { return .adjacentSibling }
        if scan("~") { return .generalSibling }
        return nil
    }

    static func isNameCharacter(_ c: Character) -> Bool {
        c.isLetter || c.isNumber || c == "-" || c == "_" || !c.isASCII
    }

    // CSS identifier; `\:` and other escapes yield the escaped character.
    mutating func scanIdentifier() -> String? {
        var name = ""
        while let c = current {
            if c == "\\" {
                index += 1
                guard let escaped = current else { return nil }
                name.append(escaped)
                index += 1
            } else if Self.isNameCharacter(c) {
                name.append(c)
                index += 1
            } else {
                break
            }
        }
        return name.isEmpty ? nil : name
    }

    mutating func scanCompound() -> DOM.StyleSheet.ComplexSelector.Compound? {
        var compound = DOM.StyleSheet.ComplexSelector.Compound()
        var scannedAny = false

        if scan("*") {
            scannedAny = true
        } else if let name = scanIdentifier() {
            compound.element = name
            scannedAny = true
        }
        // namespace prefixes (`svg|rect`) are not supported: drop the rule
        if current == "|" { return nil }

        while let c = current {
            switch c {
            case ".":
                index += 1
                guard let name = scanIdentifier() else { return nil }
                compound.classes.append(name)
            case "#":
                index += 1
                guard let name = scanIdentifier() else { return nil }
                compound.ids.append(name)
            case "[":
                index += 1
                guard let match = scanAttribute() else { return nil }
                compound.attributes.append(match)
            case ":":
                index += 1
                guard let pseudo = scanPseudoClass() else { return nil }
                compound.pseudoClasses.append(pseudo)
            default:
                return scannedAny ? compound : nil
            }
            scannedAny = true
        }
        return scannedAny ? compound : nil
    }

    mutating func scanAttribute() -> DOM.StyleSheet.ComplexSelector.AttributeMatch? {
        skipWhitespace()
        guard let name = scanIdentifier() else { return nil }
        skipWhitespace()
        if scan("]") {
            return .init(name: name, match: nil, value: "", caseInsensitive: false)
        }

        var op: DOM.StyleSheet.ComplexSelector.AttributeMatch.Operator?
        if scan("=") {
            op = .equals
        } else if let c = current, "~|^$*".contains(c) {
            index += 1
            guard scan("=") else { return nil }
            op = .init(rawValue: "\(c)=")
        }
        guard let op else { return nil }

        skipWhitespace()
        let value: String
        if let q = current, q == "\"" || q == "'" {
            index += 1
            var v = ""
            while let c = current, c != q {
                if c == "\\" {
                    index += 1
                    guard let escaped = current else { return nil }
                    v.append(escaped)
                } else {
                    v.append(c)
                }
                index += 1
            }
            guard scan(q) else { return nil }
            value = v
        } else {
            guard let v = scanIdentifier() else { return nil }
            value = v
        }
        skipWhitespace()
        var caseInsensitive = false
        if current == "i" || current == "I" {
            caseInsensitive = true
            index += 1
            skipWhitespace()
        } else if current == "s" || current == "S" {
            index += 1
            skipWhitespace()
        }
        guard scan("]") else { return nil }
        return .init(name: name, match: op, value: value, caseInsensitive: caseInsensitive)
    }

    mutating func scanPseudoClass() -> DOM.StyleSheet.ComplexSelector.PseudoClass? {
        let isElement = scan(":")
        guard let name = scanIdentifier() else { return nil }
        if scan("(") {
            // functional pseudo-classes (:not(), :nth-child()) are skipped as never matching
            var depth = 1
            while let c = current, depth > 0 {
                if c == "(" { depth += 1 }
                if c == ")" { depth -= 1 }
                index += 1
            }
            guard depth == 0 else { return nil }
            return .unsupported(name)
        }
        guard !isElement else { return .unsupported("::\(name)") }
        switch name.lowercased() {
        case "first-child": return .firstChild
        case "last-child": return .lastChild
        case "only-child": return .onlyChild
        case "root": return .root
        default: return .unsupported(name)
        }
    }
}

// MARK: - Matching

package extension DOM.StyleSheet {

    // Matches stylesheet rules against the XML tree they were parsed with,
    // so combinators and structural pseudo-classes see every element (Selectors Level 3 §6.6.5, §8).
    final class Matcher {
        private let rules: [Rule]
        private var parents = [ObjectIdentifier: XML.Element]()
        private var siblingIndex = [ObjectIdentifier: Int]()

        package init(sheets: [DOM.StyleSheet], root: XML.Element) {
            self.rules = sheets.flatMap(\.rules)
            guard !rules.isEmpty else { return }
            var stack = [root]
            while let e = stack.popLast() {
                for (i, child) in e.children.enumerated() {
                    parents[ObjectIdentifier(child)] = e
                    siblingIndex[ObjectIdentifier(child)] = i
                    stack.append(child)
                }
            }
        }

        package var isEmpty: Bool { rules.isEmpty }

        package func match(_ element: XML.Element) -> Matched? {
            guard !rules.isEmpty else { return nil }
            let matching = rules.enumerated()
                .filter { matches($0.element.selector, element) }
                .sorted { lhs, rhs in
                    let l = lhs.element.selector.specificity
                    let r = rhs.element.selector.specificity
                    return l == r ? lhs.offset < rhs.offset : l < r
                }
                .map(\.element)

            var result = Matched()
            for rule in matching {
                result.attributes = result.attributes.applyingAttributes(rule.attributes)
                result.importantAttributes = result.importantAttributes.applyingAttributes(rule.importantAttributes)
            }
            return result
        }

        func matches(_ selector: ComplexSelector, _ element: XML.Element) -> Bool {
            matches(selector, at: selector.compounds.count - 1, element)
        }

        private func matches(_ selector: ComplexSelector, at i: Int, _ element: XML.Element) -> Bool {
            guard matches(selector.compounds[i], element) else { return false }
            guard i > 0 else { return true }

            switch selector.combinators[i - 1] {
            case .child:
                guard let p = parent(of: element) else { return false }
                return matches(selector, at: i - 1, p)
            case .descendant:
                var p = parent(of: element)
                while let ancestor = p {
                    if matches(selector, at: i - 1, ancestor) { return true }
                    p = parent(of: ancestor)
                }
                return false
            case .adjacentSibling:
                guard let s = previousSiblings(of: element).last else { return false }
                return matches(selector, at: i - 1, s)
            case .generalSibling:
                return previousSiblings(of: element).contains { matches(selector, at: i - 1, $0) }
            }
        }

        private func parent(of element: XML.Element) -> XML.Element? {
            parents[ObjectIdentifier(element)]
        }

        private func previousSiblings(of element: XML.Element) -> ArraySlice<XML.Element> {
            guard let p = parent(of: element),
                  let i = siblingIndex[ObjectIdentifier(element)] else { return [] }
            return p.children[..<i]
        }

        private func matches(_ c: ComplexSelector.Compound, _ e: XML.Element) -> Bool {
            if let name = c.element, name != e.name { return false }
            if !c.ids.isEmpty {
                guard let id = e.attributes["id"], c.ids.allSatisfy({ $0 == id }) else { return false }
            }
            if !c.classes.isEmpty {
                let classes = (e.attributes["class"] ?? "").split(whereSeparator: \.isWhitespace)
                guard c.classes.allSatisfy({ classes.contains(Substring($0)) }) else { return false }
            }
            for a in c.attributes where !matches(a, e) { return false }
            for p in c.pseudoClasses where !matches(p, e) { return false }
            return true
        }

        private func matches(_ a: ComplexSelector.AttributeMatch, _ e: XML.Element) -> Bool {
            guard var actual = e.attributes[a.name] else { return false }
            guard let op = a.match else { return true }
            var expected = a.value
            if a.caseInsensitive {
                actual = actual.lowercased()
                expected = expected.lowercased()
            }
            switch op {
            case .equals:
                return actual == expected
            case .includes:
                return !expected.isEmpty && actual.split(whereSeparator: \.isWhitespace).contains(Substring(expected))
            case .dashMatch:
                return actual == expected || actual.hasPrefix(expected + "-")
            case .prefix:
                return !expected.isEmpty && actual.hasPrefix(expected)
            case .suffix:
                return !expected.isEmpty && actual.hasSuffix(expected)
            case .substring:
                return !expected.isEmpty && actual.contains(expected)
            }
        }

        private func matches(_ p: ComplexSelector.PseudoClass, _ e: XML.Element) -> Bool {
            switch p {
            case .firstChild:
                return parent(of: e) != nil && siblingIndex[ObjectIdentifier(e)] == 0
            case .lastChild:
                guard let parent = parent(of: e) else { return false }
                return siblingIndex[ObjectIdentifier(e)] == parent.children.count - 1
            case .onlyChild:
                guard let parent = parent(of: e) else { return false }
                return parent.children.count == 1
            case .root:
                return parent(of: e) == nil
            case .unsupported:
                return false
            }
        }
    }
}
