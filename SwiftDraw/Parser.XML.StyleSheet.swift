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

    func parseStyleSheetElement(_ text: String?) throws -> DOM.StyleSheet {
        var scanner = XMLParser.Scanner(text: text ?? "")
        var sheet = DOM.StyleSheet()

        var last: (DOM.StyleSheet.Selector, String)?
        repeat {
            last = try scanner.scanNextSelector()
            if let last = last {
                sheet.entries[last.0] = DOM.GraphicsElement()
            }
        } while last != nil

        return sheet
    }
}

extension XMLParser.Scanner {

    mutating func scanNextSelector() throws -> (DOM.StyleSheet.Selector, String)? {
        try scanPastComments()
        if let c = try scanNextClass() {
            return (.class(c), try scanNextBody())
        } else if let id = try scanNextID() {
            return (.id(id), try scanNextBody())
        } else if let e = try scanNextElement() {
            return (.element(e), try scanNextBody())
        }
        return nil
    }

    mutating func scanPastComments() throws {
        while try scanPastNextComment() {
            ()
        }
    }

    mutating func scanPastNextComment() throws -> Bool {
        guard scanStringIfPossible("/*") else { return false }
        _ = try scanString(upTo: "*/")
        _ = try scanString("*/")
        return true
    }

    mutating func scanNextClass() throws -> String? {
        guard scanStringIfPossible(".") else { return nil }
        return try scanSelectorName()
    }

    mutating func scanNextID() throws -> String? {
        guard scanStringIfPossible("#") else { return nil }
        return try scanSelectorName()
    }

    mutating func scanNextElement() throws -> String? {
        do {
            return try scanSelectorName()
        } catch {
            guard isEOF else {
                throw error
            }
            return nil
        }
    }

    mutating func scanSelectorName() throws -> String? {
        try scanString(upTo: "{").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    mutating func scanNextBody() throws -> String {
        _ = try scanString("{")
        let body = try scanString(upTo: "}")
        _ = try scanString("}")
        return body
    }
}
