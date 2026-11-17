//
//  Parser.XML.FontShorthand.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 18/11/26.
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

extension XMLParser {

    /// The longhands of the CSS `font` shorthand (CSS Fonts 4 §2.8):
    /// `[ <font-style> || <font-variant-css2> || <font-weight> || <font-stretch-css3> ]? <font-size> [ / <line-height> ]? <font-family>`,
    /// or a system font keyword. The parts it leaves out are reset to their initial values. Only the
    /// longhands SwiftDraw draws are returned (`font-variant`, `font-stretch` and `line-height` are
    /// checked but dropped). nil when the value is invalid, so the declaration is ignored.
    static func parseFontShorthand(_ value: String) -> [(name: String, value: String)]? {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = text.lowercased()

        // system fonts: the platform's UI font, approximated by 13px sans-serif as macOS draws it
        if systemFontKeywords.contains(lowercased) {
            return longhands(style: "normal", weight: "normal", size: "13px", family: "sans-serif")
        }

        var style: String?
        var variant: String?
        var weight: String?
        var stretch: String?

        var tokens = Tokens(text)
        var preambleCount = 0
        while let token = tokens.peek() {
            let word = token.lowercased()
            let next = tokens.peek(offset: 1)
            if word == "normal" {
                // `normal` sets whichever of the four is still unset to its initial value
                guard preambleCount < 4 else { return nil }
            } else if style == nil, word == "italic" || word == "oblique" {
                style = word
                // `oblique <angle>`: drawn as oblique
                if word == "oblique", let angle = next, isAngle(angle) {
                    tokens.advance()
                }
            } else if variant == nil, word == "small-caps" {
                variant = word
            } else if weight == nil, isWeight(word), next != nil, DOM.FontWeight(word) != nil {
                // a unitless number is a weight when a size still follows it
                weight = word
            } else if stretch == nil, stretchKeywords.contains(word) {
                stretch = word
            } else {
                break
            }
            preambleCount += 1
            guard preambleCount <= 4 else { return nil }
            tokens.advance()
        }

        // <font-size> [ / <line-height> ]?
        guard let sizeToken = tokens.peek() else { return nil }
        tokens.advance()
        let sizeParts = sizeToken.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        let size = sizeParts[0]
        guard DOM.FontSize(size) != nil else { return nil }
        if sizeParts.count == 2 {
            // `12px/1.5` or `12px/ 1.5`
            if sizeParts[1].isEmpty {
                guard tokens.peek() != nil else { return nil }
                tokens.advance()
            }
        } else if let slash = tokens.peek(), slash.hasPrefix("/") {
            // `12px /1.5` or `12px / 1.5`
            tokens.advance()
            if slash == "/" {
                guard tokens.peek() != nil else { return nil }
                tokens.advance()
            }
        }

        let family = tokens.remainder.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !family.isEmpty else { return nil }

        return longhands(style: style ?? "normal", weight: weight ?? "normal", size: size, family: family)
    }

    private static func longhands(
        style: String,
        weight: String,
        size: String,
        family: String
    ) -> [(name: String, value: String)] {
        [("font-style", style), ("font-weight", weight), ("font-size", size), ("font-family", family)]
    }

    private static let systemFontKeywords: Set<String> = [
        "caption", "icon", "menu", "message-box", "small-caption", "status-bar",
    ]

    private static let stretchKeywords: Set<String> = [
        "ultra-condensed", "extra-condensed", "condensed", "semi-condensed",
        "semi-expanded", "expanded", "extra-expanded", "ultra-expanded",
    ]

    private static func isWeight(_ word: String) -> Bool {
        switch word {
        case "bold", "bolder", "lighter": return true
        default: return Double(word) != nil
        }
    }

    private static func isAngle(_ token: String) -> Bool {
        let token = token.lowercased()
        for unit in ["deg", "grad", "rad", "turn"] where token.hasSuffix(unit) {
            return Double(token.dropLast(unit.count)) != nil
        }
        return false
    }

    /// Whitespace-separated words of the value, keeping the unscanned rest (the family list) as written.
    private struct Tokens {
        private let text: Substring
        private var position: Substring.Index

        init(_ text: String) {
            self.text = Substring(text)
            self.position = self.text.startIndex
        }

        /// The words from the current position, the first `offset + 1` of them
        private func words(_ count: Int) -> [Substring] {
            Array(text[position...].split(whereSeparator: \.isWhitespace).prefix(count))
        }

        func peek(offset: Int = 0) -> String? {
            let words = words(offset + 1)
            return words.count > offset ? String(words[offset]) : nil
        }

        mutating func advance() {
            guard let word = words(1).first else { return }
            position = word.endIndex
        }

        var remainder: Substring { text[position...] }
    }
}
