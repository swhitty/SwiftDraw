//
//  Parser.XML.Symbol.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 15/11/26.
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

    func parseSymbol(_ e: XML.Element, _ att: any AttributeParser) throws -> DOM.Symbol {
        guard e.name == "symbol" else {
            throw Error.invalid
        }

        let symbol = DOM.Symbol()
        // an invalid viewBox is ignored, as on <svg> in browsers: the contents are drawn unscaled
        symbol.viewBox = try? parseViewBox(try att.parseString("viewBox"))
        symbol.preserveAspectRatio = parsePreserveAspectRatio(try? att.parseString("preserveAspectRatio"))
        symbol.refX = parseDefaultedLength(att, "refX", .horizontal)
        symbol.refY = parseDefaultedLength(att, "refY", .vertical)
        symbol.overflow = (try? att.parseString("overflow")).flatMap {
            DOM.Symbol.Overflow(rawValue: $0.trimmingCharacters(in: .whitespaces))
        }
        // SVG 2 §5.6: percentages resolve against the enclosing viewport
        symbol.x = parseDefaultedLength(att, "x", .horizontal)
        symbol.y = parseDefaultedLength(att, "y", .vertical)
        symbol.width = parseDefaultedLength(att, "width", .horizontal)
        symbol.height = parseDefaultedLength(att, "height", .vertical)

        // The contents resolve percentages against the symbol's viewport: its viewBox, or else the size
        // the <use> gives it. Lengths are resolved once, so that is the size every <use> of it agrees on.
        let id = e.attributes["id"]
        let enclosing = lengthContext.viewports.last
        let viewport =
            symbol.viewBox.map { Viewport(width: $0.width, height: $0.height) }
            ?? id.flatMap { lengthContext.symbolViewports[$0] }.map {
                Viewport(
                    width: $0.width ?? symbol.width ?? enclosing?.width ?? 0,
                    height: $0.height ?? symbol.height ?? enclosing?.height ?? 0
                )
            }
            ?? Viewport(
                width: symbol.width ?? enclosing?.width ?? 0,
                height: symbol.height ?? enclosing?.height ?? 0
            )
        lengthContext.viewports.append(viewport)
        defer { lengthContext.viewports.removeLast() }
        symbol.childElements = try parseGraphicsElements(e.children)
        return symbol
    }

    /// The width and height every `<use>` referencing a symbol gives it, by the symbol's id.
    /// Only `<use>` elements with absolute lengths are known while parsing; a symbol whose uses
    /// disagree, or set a percentage, is left out. nil sides are left for the symbol to size.
    func makeSymbolUseSizes(within root: XML.Element) -> [String: (width: DOM.Coordinate?, height: DOM.Coordinate?)] {
        var sizes = [String: (width: DOM.Coordinate?, height: DOM.Coordinate?)]()
        var ambiguous = Set<String>()
        var stack = [root]
        while let e = stack.popLast() {
            stack.append(contentsOf: e.children)
            guard e.name == "use",
                let href = e.attributes["href"] ?? e.attributes["xlink:href"],
                href.hasPrefix("#")
            else { continue }
            let id = String(href.dropFirst())
            func absolute(_ key: String, _ direction: LengthDirection) -> DOM.Coordinate?? {
                guard let raw = e.attributes[key] else { return .some(nil) }
                guard !raw.contains("%"), let value = try? resolveLength(raw, direction) else { return nil }
                return .some(value)
            }
            guard let width = absolute("width", .horizontal),
                let height = absolute("height", .vertical)
            else {
                ambiguous.insert(id)
                continue
            }
            if let existing = sizes[id], existing != (width, height) {
                ambiguous.insert(id)
            }
            sizes[id] = (width, height)
        }
        return sizes.filter { !ambiguous.contains($0.key) }
    }
}
