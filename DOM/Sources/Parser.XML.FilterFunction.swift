//
//  Parser.XML.FilterFunction.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 16/11/26.
//  Copyright 2026 Simon Whitty
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

package extension XMLParser {

    /// The `filter` property (Filter Effects 1 §12): `none`, or a whitespace separated list of `url()`
    /// references and filter functions. `none` is the empty list. Any invalid entry makes the whole
    /// value invalid, so it is dropped like any other invalid property value.
    static func parseFilterValue(_ value: String) throws -> [DOM.FilterValue] {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.lowercased() == "none" {
            return []
        }
        let functions = try splitFunctions(value)
        guard !functions.isEmpty else { throw Error.invalid }
        return try functions.map { name, arguments in
            if name == "url" {
                return .url(try parseFilterURL(arguments))
            }
            return .function(try parseFilterFunction(name, arguments))
        }
    }

    /// `name(arguments)` repeated, separated by optional whitespace; names lowercased
    private static func splitFunctions(_ value: String) throws -> [(name: String, arguments: String)] {
        var functions = [(name: String, arguments: String)]()
        var index = value.startIndex
        while index < value.endIndex {
            if value[index].isWhitespace {
                index = value.index(after: index)
                continue
            }
            let nameStart = index
            while index < value.endIndex, value[index].isLetter || value[index] == "-" {
                index = value.index(after: index)
            }
            guard index > nameStart, index < value.endIndex, value[index] == "(" else {
                throw Error.invalid
            }
            let name = value[nameStart..<index].lowercased()
            index = value.index(after: index)
            let argumentsStart = index
            var depth = 0
            var quote: Character?
            while true {
                guard index < value.endIndex else { throw Error.invalid }
                let c = value[index]
                if let q = quote {
                    if c == q { quote = nil }
                } else if c == "\"" || c == "'" {
                    quote = c
                } else if c == "(" {
                    depth += 1
                } else if c == ")" {
                    if depth == 0 { break }
                    depth -= 1
                }
                index = value.index(after: index)
            }
            functions.append((name, String(value[argumentsStart..<index])))
            index = value.index(after: index)
        }
        return functions
    }

    private static func parseFilterURL(_ arguments: String) throws -> DOM.URL {
        let body = arguments.trimmingCharacters(in: .whitespacesAndNewlines).unquoted
        guard !body.isEmpty, let url = URL(maybeData: body) else { throw Error.invalid }
        return url
    }

    /// arguments separated by whitespace outside parentheses, e.g. `rgb(0, 0, 255) 4 5`
    private static func splitArguments(_ arguments: String) -> [String] {
        var tokens = [String]()
        var current = ""
        var depth = 0
        for c in arguments {
            if c.isWhitespace && depth == 0 {
                if !current.isEmpty { tokens.append(current) }
                current = ""
                continue
            }
            if c == "(" { depth += 1 }
            if c == ")" { depth -= 1 }
            current.append(c)
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    private static func parseFilterFunction(_ name: String, _ arguments: String) throws -> DOM.FilterFunction {
        let tokens = splitArguments(arguments)
        switch name {
        case "blur":
            guard tokens.count <= 1 else { throw Error.invalid }
            let length = try tokens.first.map(parseLength) ?? DOM.UnitLength(0)
            guard length.value >= 0 else { throw Error.invalid }
            return .blur(length)
        case "drop-shadow":
            return try parseDropShadow(tokens)
        case "hue-rotate":
            guard tokens.count <= 1 else { throw Error.invalid }
            return .hueRotate(degrees: try tokens.first.map(parseAngle) ?? 0)
        case "grayscale", "sepia", "saturate", "invert", "opacity", "brightness", "contrast":
            guard tokens.count <= 1 else { throw Error.invalid }
            let amount = try tokens.first.map(parseAmount) ?? 1
            switch name {
            case "grayscale": return .grayscale(amount)
            case "sepia": return .sepia(amount)
            case "saturate": return .saturate(amount)
            case "invert": return .invert(amount)
            case "opacity": return .opacity(amount)
            case "brightness": return .brightness(amount)
            default: return .contrast(amount)
            }
        default:
            throw Error.invalid
        }
    }

    /// `drop-shadow( <color>? && <length>{2,3} )`: the color first or last, and a non-negative blur
    private static func parseDropShadow(_ tokens: [String]) throws -> DOM.FilterFunction {
        var tokens = tokens
        var color: DOM.Color?
        if let first = tokens.first, let c = parseShadowColor(first) {
            color = c
            tokens.removeFirst()
        } else if let last = tokens.last, let c = parseShadowColor(last) {
            color = c
            tokens.removeLast()
        }
        guard (2...3).contains(tokens.count) else { throw Error.invalid }
        let lengths = try tokens.map(parseLength)
        let stdDeviation = lengths.count == 3 ? lengths[2] : DOM.UnitLength(0)
        guard stdDeviation.value >= 0 else { throw Error.invalid }
        if color == .currentColor {
            color = nil
        }
        return .dropShadow(color: color, dx: lengths[0], dy: lengths[1], stdDeviation: stdDeviation)
    }

    private static func parseShadowColor(_ token: String) -> DOM.Color? {
        // a number is never a colour
        guard let first = token.first, !first.isNumber, first != "-", first != "+", first != "." else { return nil }
        guard let color = try? XMLParser().parseFill(token).getColor(), color != .none else { return nil }
        return color
    }

    /// `<number><unit>?`: user units, absolute units, `em` or `ex`; percentages are invalid
    private static func parseLength(_ token: String) throws -> DOM.UnitLength {
        let (number, suffix) = try parseNumber(token)
        guard number.isFinite else { throw Error.invalid }
        if suffix.isEmpty {
            return DOM.UnitLength(DOM.Float(number))
        }
        guard let unit = Self.units[suffix] else { throw Error.invalid }
        return DOM.UnitLength(DOM.Float(number), unit: unit)
    }

    private static let units: [String: DOM.Unit] = [
        "px": .pixel, "in": .inch, "cm": .centimeter, "mm": .millimeter,
        "pt": .point, "pc": .pica, "em": .em, "ex": .ex,
    ]

    /// `<angle> | <zero>` in degrees
    private static func parseAngle(_ token: String) throws -> DOM.Float {
        let (number, suffix) = try parseNumber(token)
        let degrees: Double
        switch suffix {
        case "deg": degrees = number
        case "rad": degrees = number * 180 / .pi
        case "grad": degrees = number * 0.9
        case "turn": degrees = number * 360
        case "" where number == 0: degrees = 0
        default: throw Error.invalid
        }
        guard degrees.isFinite else { throw Error.invalid }
        return DOM.Float(degrees)
    }

    /// `<number> | <percentage>`, not negative
    private static func parseAmount(_ token: String) throws -> DOM.Float {
        var (number, suffix) = try parseNumber(token)
        switch suffix {
        case "%": number /= 100
        case "": break
        default: throw Error.invalid
        }
        guard number.isFinite, number >= 0 else { throw Error.invalid }
        return DOM.Float(number)
    }

    /// a CSS number and what follows it, lowercased
    private static func parseNumber(_ token: String) throws -> (Double, suffix: String) {
        let chars = Array(token)
        var i = 0
        if i < chars.count, chars[i] == "+" || chars[i] == "-" { i += 1 }
        var digits = 0
        while i < chars.count, chars[i].isASCII, chars[i].isNumber { i += 1; digits += 1 }
        if i < chars.count, chars[i] == "." {
            i += 1
            while i < chars.count, chars[i].isASCII, chars[i].isNumber { i += 1; digits += 1 }
        }
        guard digits > 0 else { throw Error.invalid }
        // an exponent only when digits follow: `1em` is one em
        if i < chars.count, chars[i] == "e" || chars[i] == "E" {
            var j = i + 1
            if j < chars.count, chars[j] == "+" || chars[j] == "-" { j += 1 }
            if j < chars.count, chars[j].isASCII, chars[j].isNumber {
                while j < chars.count, chars[j].isASCII, chars[j].isNumber { j += 1 }
                i = j
            }
        }
        guard let number = Double(String(chars[0..<i])) else { throw Error.invalid }
        return (number, String(chars[i...]).lowercased())
    }
}
