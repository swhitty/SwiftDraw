//
//  Parser.XML.Color.swift
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

    func parseFill(_ data: String) throws -> DOM.Fill {
        if let c = try parseColorRGB(data: data) {
            return .color(c)
        } else if let c = try parseColorHex(data: data) {
            return .color(c)
        } else if let c = try parseColorP3(data: data) {
            return .color(c)
        } else if let c = parseCurrentColor(data: data) {
            return .color(c)
        } else if let c = parseColorKeyword(data: data) {
            return .color(c)
        } else if let c = parseColorNone(data: data) {
            return .color(c)
        } else if let paint = try parseURLPaint(data: data) {
            return paint
        } else if let c = parseColorHSL(data: data) {
            return .color(c)
        }

        throw Error.invalid
    }

    private func parseColorNone(data: String) -> DOM.Color? {
        let trimmed = data.trimmingCharacters(in: .whitespaces).lowercased()
        if trimmed == "none" || trimmed == "transparent" {
            return DOM.Color.none  // .none resolves to Optional.none
        }
        return nil
    }

    private func parseCurrentColor(data: String) -> DOM.Color? {
        let raw = data.trimmingCharacters(in: .whitespaces)
        guard raw.lowercased() == "currentcolor" else {
            return nil
        }
        return .currentColor
    }

    private func parseColorKeyword(data: String) -> DOM.Color? {
        let raw = data.trimmingCharacters(in: .whitespaces).lowercased()
        guard let keyword = DOM.Color.Keyword(rawValue: raw) else {
            return nil
        }
        return .keyword(keyword)
    }

    /// `rgb()` and `rgba()` (CSS Color 4 §5.1): both take an optional alpha, with commas or
    /// `r g b / a`. Red, green and blue are all numbers (0–255, fractions allowed) or all
    /// percentages, clamped to range; mixing them is invalid. Alpha is a number or a percentage.
    private func parseColorRGB(data: String) throws -> DOM.Color? {
        let raw = data.trimmingCharacters(in: .whitespaces).lowercased()
        guard let open = raw.firstIndex(of: "("),
            ["rgb", "rgba"].contains(raw[raw.startIndex..<open].trimmingCharacters(in: .whitespaces))
        else {
            return nil
        }
        guard raw.hasSuffix(")") else { throw Error.invalid }
        let body = raw[raw.index(after: open)..<raw.index(before: raw.endIndex)]

        var parts: [Substring]
        var alphaPart: Substring?
        if body.contains(",") {
            parts = body.split(separator: ",", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces)[...] }
            guard parts.count == 3 || parts.count == 4 else { throw Error.invalid }
            if parts.count == 4 { alphaPart = parts.removeLast() }
        } else {
            let slash = body.split(separator: "/", omittingEmptySubsequences: false)
            guard slash.count <= 2 else { throw Error.invalid }
            parts = slash[0].split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard parts.count == 3 else { throw Error.invalid }
            if slash.count == 2 { alphaPart = slash[1].trimmingCharacters(in: .whitespaces)[...] }
        }

        enum Component {
            case number(DOM.Float)
            case percentage(DOM.Float)
        }
        func component(_ text: Substring) throws -> Component {
            if text.hasSuffix("%"), let v = Double(text.dropLast()), v.isFinite {
                return .percentage(DOM.Float(min(max(v, 0), 100) / 100))
            }
            guard let v = Double(text), v.isFinite else { throw Error.invalid }
            return .number(DOM.Float(v))
        }

        var alpha: DOM.Float = 1
        if let alphaPart {
            switch try component(alphaPart) {
            case .number(let v): alpha = min(max(v, 0), 1)
            case .percentage(let v): alpha = v
            }
        }

        switch try (component(parts[0]), component(parts[1]), component(parts[2])) {
        case let (.number(r), .number(g), .number(b)):
            let channels = [r, g, b].map { min(max($0, 0), 255) }
            if channels.allSatisfy({ $0 == $0.rounded() }) {
                return .rgbi(UInt8(channels[0]), UInt8(channels[1]), UInt8(channels[2]), alpha)
            }
            return .rgbf(channels[0] / 255, channels[1] / 255, channels[2] / 255, alpha)
        case let (.percentage(r), .percentage(g), .percentage(b)):
            return .rgbf(r, g, b, alpha)
        default:
            throw Error.invalid
        }
    }

    /// SVG 1.1 §11.2: `<funciri> [ none | currentColor | <color> ]`, the fallback is used when the server does not resolve.
    /// An unreadable fallback (`icc-color(…)`, which browsers do not support) makes the whole value invalid.
    private func parseURLPaint(data: String) throws -> DOM.Fill? {
        var scanner = XMLParser.Scanner(text: data)
        guard data.trimmingCharacters(in: .whitespaces).lowercased().hasPrefix("url(") else {
            return nil
        }
        let url = try scanner.scanURLFunction("url")
        if scanner.isEOF {
            return .url(url)
        }
        let remainder = String(data[scanner.currentIndex...])
            .trimmingCharacters(in: .whitespaces)
        guard !remainder.isEmpty else { return .url(url) }
        guard remainder.lowercased().hasPrefix("url(") == false,
            case .color(let fallback)? = try? parseFill(remainder)
        else {
            throw Error.invalid
        }
        return .urlWithFallback(url, fallback)
    }

    private func parseURLSelector(data: String) throws -> DOM.URL? {
        var scanner = XMLParser.Scanner(text: data)
        guard (try? scanner.scanString("url(")) == true else {
            return nil
        }

        let urlText = try scanner.scanString(upTo: ")")
        _ = try? scanner.scanString(")")

        let urlTrimmed = urlText.trimmingCharacters(in: .whitespaces)

        guard scanner.isEOF, let url = URL(string: urlTrimmed) else {
            throw XMLParser.Error.invalid
        }

        return url
    }

    private func parseColorP3(data: String) throws -> DOM.Color? {
        var scanner = XMLParser.Scanner(text: data)
        guard scanner.scanStringIfPossible("color(display-p3") else { return nil }

        let r = try scanner.scanFloat()
        scanner.scanStringIfPossible(",")
        let g = try scanner.scanFloat()
        scanner.scanStringIfPossible(",")
        let b = try scanner.scanFloat()
        try scanner.scanString(")")

        return .p3(r, g, b)
    }

    // hsl(120, 100%, 50%) and hsla(120 100% 50% / 0.5), SVG 2 / CSS Color 3
    // https://www.w3.org/TR/css-color-3/#hsl-color
    private func parseColorHSL(data: String) -> DOM.Color? {
        let raw = data.trimmingCharacters(in: .whitespaces).lowercased()
        guard raw.hasPrefix("hsl"), raw.hasSuffix(")"),
            let open = raw.firstIndex(of: "(")
        else {
            return nil
        }
        let name = raw[raw.startIndex..<open]
        guard name == "hsl" || name == "hsla" else { return nil }

        let body = raw[raw.index(after: open)..<raw.index(before: raw.endIndex)]
        let parts =
            body
            .split(whereSeparator: { $0 == "," || $0 == "/" || $0 == " " || $0 == "\t" })
            .map(String.init)
        guard parts.count == 3 || parts.count == 4 else { return nil }

        func number(_ text: String, suffix: String) -> DOM.Float? {
            var t = text
            if t.hasSuffix(suffix) { t.removeLast(suffix.count) }
            return DOM.Float(t)
        }
        func percentage(_ text: String) -> DOM.Float? {
            guard text.hasSuffix("%"), let v = number(text, suffix: "%") else { return nil }
            return min(max(v / 100, 0), 1)
        }

        guard let h = number(parts[0], suffix: "deg"),
            let s = percentage(parts[1]),
            let l = percentage(parts[2])
        else {
            return nil
        }

        var alpha: DOM.Float = 1
        if parts.count == 4 {
            if parts[3].hasSuffix("%") {
                guard let a = percentage(parts[3]) else { return nil }
                alpha = a
            } else {
                guard let a = DOM.Float(parts[3]) else { return nil }
                alpha = min(max(a, 0), 1)
            }
        }

        let hue = (h.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 360
        let q = l < 0.5 ? l * (1 + s) : l + s - l * s
        let p = 2 * l - q

        func channel(_ t: DOM.Float) -> DOM.Float {
            var t = t
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            if t < 1.0 / 6 { return p + (q - p) * 6 * t }
            if t < 0.5 { return q }
            if t < 2.0 / 3 { return p + (q - p) * (2.0 / 3 - t) * 6 }
            return p
        }

        return .rgbf(channel(hue + 1.0 / 3), channel(hue), channel(hue - 1.0 / 3), alpha)
    }

    // #a5F should be parsed as #aa55FF, #a5F8 as #aa55FF88
    private func padHex(_ data: String) -> String? {
        let chars = data.unicodeScalars.map({ $0 })
        guard chars.count == 3 || chars.count == 4 else { return data }
        return chars.map { "\($0)\($0)" }.joined()
    }

    private func parseColorHex(data: String) throws -> DOM.Color? {
        var scanner = XMLParser.Scanner(text: data)
        guard scanner.scanStringIfPossible("#") else { return nil }
        let hexadecimal = Foundation.CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
        let code = try scanner.scanString(matchingAny: hexadecimal)
        guard
            let paddedCode = padHex(code),
            paddedCode.count == 6 || paddedCode.count == 8,
            let hex = Int(paddedCode, radix: 16)
        else {
            throw Error.invalid
        }

        if paddedCode.count == 8 {
            let r = UInt8((hex >> 24) & 0xff)
            let g = UInt8((hex >> 16) & 0xff)
            let b = UInt8((hex >> 8) & 0xff)
            let a = DOM.Float(hex & 0xff) / 255
            return .rgbi(r, g, b, a)
        }

        let r = UInt8((hex >> 16) & 0xff)
        let g = UInt8((hex >> 8) & 0xff)
        let b = UInt8(hex & 0xff)

        return .hex(r, g, b)
    }
}
