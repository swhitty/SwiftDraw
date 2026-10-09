//
//  Parser.XML.Length.swift
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

// SVG 1.1 §7.10 "Units": geometry lengths in user units, resolved while parsing.
package extension XMLParser {

    /// Which side of the nearest viewport a percentage refers to (SVG 1.1 §7.10).
    enum LengthDirection {
        /// x, cx, x1, x2, rx, width
        case horizontal
        /// y, cy, y1, y2, ry, height
        case vertical
        /// r and other lengths: the viewport diagonal / √2
        case other
    }

    /// `<number>`, `<number><unit>` or `<number>%` in user units.
    /// Percentages resolve against the nearest viewport, `em` against the element's font-size
    /// and `ex` as half of it (CSS 2.1 §4.3.2 when the x-height is unknown).
    /// Without a viewport (an element parsed on its own) a percentage stays its raw number.
    func resolveLength(_ value: String, _ direction: LengthDirection) throws -> DOM.Coordinate {
        var scanner = XMLParser.Scanner(text: value)
        let number = try scanner.scanDouble()

        if scanner.scanStringIfPossible("%") {
            guard let viewport = lengthContext.viewports.last else {
                return DOM.Coordinate(number)
            }
            return DOM.Coordinate(number / 100) * viewport.reference(for: direction)
        }

        switch scanner.scanUnit() {
        case .em:
            return DOM.Coordinate(number) * lengthContext.fontSize
        case .ex:
            return DOM.Coordinate(number) * lengthContext.fontSize / 2
        case let unit?:
            return DOM.Coordinate(number.apply(unit: unit))
        case nil:
            return DOM.Coordinate(number)
        }
    }

    func parseLength(_ att: any AttributeParser, _ key: String, _ direction: LengthDirection) throws -> DOM.Coordinate {
        try att.parse(key) { try resolveLength($0, direction) }
    }

    func parseLength(_ att: any AttributeParser, _ key: String, _ direction: LengthDirection) throws -> DOM.Coordinate? {
        try att.parse(key, exp: { try resolveLength($0, direction) })
    }
}

extension XMLParser.Viewport {

    func reference(for direction: XMLParser.LengthDirection) -> DOM.Coordinate {
        switch direction {
        case .horizontal:
            return width
        case .vertical:
            return height
        case .other:
            return ((width * width + height * height) / 2).squareRoot()
        }
    }
}
