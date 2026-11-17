//
//  DOM.TransformOrigin.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 17/11/26.
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

package extension DOM {

    /// `transform-origin` (CSS Transforms 1 §6, SVG 2): the point a `transform` is applied around,
    /// `translate(origin) · transform · translate(-origin)`. The default is `0 0`.
    /// Percentages and keywords are kept unresolved: they refer to the viewport (`transform-box: view-box`),
    /// which is only known when the transform is turned into a matrix. A third value (z) has no effect in 2D.
    struct TransformOrigin: Equatable, Sendable {
        package var x: Offset
        package var y: Offset

        package init(x: Offset, y: Offset) {
            self.x = x
            self.y = y
        }

        package enum Offset: Equatable, Sendable {
            /// A length in user units
            case length(Float)
            /// A fraction of the reference box: `50%` and `center` are 0.5
            case fraction(Float)

            package func resolved(against reference: Float) -> Float {
                switch self {
                case .length(let value): return value
                case .fraction(let value): return value * reference
                }
            }
        }
    }
}

package extension XMLParser {

    /// Parses `transform-origin`: one to three values, keywords (`left`, `center`, `right`, `top`, `bottom`),
    /// lengths and percentages (CSS Transforms 1 §6). nil when the value is invalid.
    func parseTransformOrigin(_ text: String) -> DOM.TransformOrigin? {
        let tokens = Attributes.removingImportant(from: text)
            .split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" || $0 == "\r" })
            .map { $0.lowercased() }
        guard (1...3).contains(tokens.count) else { return nil }

        // a third value is z: a length (not a percentage) with no effect on 2D rendering
        if tokens.count == 3 {
            guard case .length = Self.transformOriginValue(tokens[2]) else { return nil }
        }

        let values = tokens.prefix(2).map(Self.transformOriginValue)
        guard values.allSatisfy({ $0 != nil }) else { return nil }
        let center = DOM.TransformOrigin.Offset.fraction(0.5)

        if values.count == 1 {
            switch values[0]! {
            case .length(let value):
                return .init(x: .length(value), y: center)
            case .fraction(let value):
                return .init(x: .fraction(value), y: center)
            case .keyword(let keyword):
                if keyword.isVertical {
                    return .init(x: center, y: keyword.offset)
                }
                return .init(x: keyword.offset, y: center)
            }
        }

        // `[left | center | right | <length-percentage>] [top | center | bottom | <length-percentage>]`
        // or two keywords in either order: `top left`
        let first = values[0]!, second = values[1]!
        if let x = first.horizontal, let y = second.vertical {
            return .init(x: x, y: y)
        }
        if case .keyword(let a) = first, case .keyword(let b) = second,
            let y = first.vertical, let x = second.horizontal,
            a.isVertical || b.isHorizontal
        {
            return .init(x: x, y: y)
        }
        return nil
    }

    private enum TransformOriginKeyword: String {
        case left, center, right, top, bottom

        var isHorizontal: Bool { self == .left || self == .right }
        var isVertical: Bool { self == .top || self == .bottom }

        var offset: DOM.TransformOrigin.Offset {
            switch self {
            case .left, .top: return .fraction(0)
            case .center: return .fraction(0.5)
            case .right, .bottom: return .fraction(1)
            }
        }
    }

    private enum TransformOriginValue: Equatable {
        case length(Float)
        case fraction(Float)
        case keyword(TransformOriginKeyword)

        var horizontal: DOM.TransformOrigin.Offset? {
            switch self {
            case .length(let value): return .length(value)
            case .fraction(let value): return .fraction(value)
            case .keyword(let keyword): return keyword.isVertical ? nil : keyword.offset
            }
        }

        var vertical: DOM.TransformOrigin.Offset? {
            switch self {
            case .length(let value): return .length(value)
            case .fraction(let value): return .fraction(value)
            case .keyword(let keyword): return keyword.isHorizontal ? nil : keyword.offset
            }
        }
    }

    private static func transformOriginValue(_ token: String) -> TransformOriginValue? {
        if let keyword = TransformOriginKeyword(rawValue: token) {
            return .keyword(keyword)
        }
        var scanner = XMLParser.Scanner(text: token)
        guard let number = try? scanner.scanDouble(), number.isFinite else { return nil }
        if scanner.scanStringIfPossible("%") {
            guard scanner.isEOF else { return nil }
            return .fraction(Float(number / 100))
        }
        let unit = scanner.scanUnit()
        guard scanner.isEOF else { return nil }
        switch unit {
        case nil:
            // SVG presentation attributes accept unitless user units
            return .length(Float(number))
        case .em, .ex:
            // font-relative lengths need the element's font-size, unknown here
            return nil
        case let unit?:
            return .length(Float(number.apply(unit: unit)))
        }
    }
}
