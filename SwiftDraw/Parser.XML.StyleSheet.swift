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
        let entries = try Self.parseEntries(text)

        var sheet = DOM.StyleSheet()
        sheet.entries = try entries.mapValues(parsePresentationAttributes)
        return sheet
    }

    static func parseEntries(_ text: String?) throws -> [DOM.StyleSheet.Selector: [String: String]] {
        guard let text = text else { return [:] }
        var scanner = XMLParser.Scanner(text: removeCSSComments(from: text))
        var entries = [DOM.StyleSheet.Selector: [String: String]]()

        var last: (DOM.StyleSheet.Selector, [String: String])?
        repeat {
            last = try scanner.scanNextSelector()
            if let last = last {
                entries[last.0] = last.1
            }
        } while last != nil

        return entries
    }

    static func removeCSSComments(from text: String) -> String {
        let regex = try! NSRegularExpression(pattern: "\\/\\*.*\\*\\/", options: .caseInsensitive)
        let range = NSMakeRange(0, (text as NSString).length)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
    }
}

extension XMLParser.Scanner {

    mutating func scanNextSelector() throws -> (DOM.StyleSheet.Selector, [String: String])? {
        if let c = try scanNextClass() {
            return (.class(c), try scanAtttributes())
        } else if let id = try scanNextID() {
            return (.id(id), try scanAtttributes())
        } else if let e = try scanNextElement() {
            return (.element(e), try scanAtttributes())
        }
        return nil
    }

    private mutating func scanNextClass() throws -> String? {
        guard doScanString(".") else { return nil }
        return try scanSelectorName()
    }

    private mutating func scanNextID() throws -> String? {
        guard doScanString("#") else { return nil }
        return try scanSelectorName()
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
        try scanString(upTo: "{").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private mutating func scanAtttributes() throws -> [String: String] {
        _ = doScanString("{")
        var attributes = [String: String]()
        var last: String?
        repeat {
            last = try scanNextAttributeKey()
            if let last = last {
                attributes[last] = try scanNextAttributeValue()
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
        let value = try scanString(upTo: .init(charactersIn: ";\n}"))
        _ = doScanString(";")
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

//Allow Dictionary to become an attribute parser
extension Dictionary: AttributeParser {
  var parser: AttributeValueParser { return XMLParser.ValueParser() }
  var options: SwiftDraw.XMLParser.Options { return [] }

  func parse<T>(_ key: String, _ exp: (String) throws -> T) throws -> T {
    guard let dict = self as? [String: String],
      let value = dict[key] else { throw XMLParser.Error.missingAttribute(name: key) }

    return try exp(value)
  }
}
