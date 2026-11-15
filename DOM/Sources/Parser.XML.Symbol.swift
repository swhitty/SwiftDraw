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
        return symbol
    }
}
