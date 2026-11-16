//
//  DOM.FontSize.swift
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

    /// CSS `font-size` as specified (CSS Fonts 4 §2.5). Relative values are resolved against the
    /// parent's computed font-size by `resolved(inheriting:)` while cascading.
    enum FontSize: Hashable, Sendable {
        /// An absolute size in px (units already applied)
        case length(Float)
        /// A multiple of the parent's font-size: `em`, or `%` / 100
        case relative(Float)
        /// A multiple of the parent's x-height, taken as half its font-size (CSS 2.1 §4.3.2)
        case ex(Float)
        case keyword(Keyword)
        case larger
        case smaller

        /// `<absolute-size>`
        package enum Keyword: String, Hashable, Sendable, CaseIterable {
            case xxSmall = "xx-small"
            case xSmall = "x-small"
            case small
            case medium
            case large
            case xLarge = "x-large"
            case xxLarge = "xx-large"
            case xxxLarge = "xxx-large"

            /// The sizes browsers use when `medium` is 16px (CSS Fonts 4 §2.5.1 scaling factors, rounded).
            package var size: Float {
                switch self {
                case .xxSmall: return 9
                case .xSmall: return 10
                case .small: return 13
                case .medium: return 16
                case .large: return 18
                case .xLarge: return 24
                case .xxLarge: return 32
                case .xxxLarge: return 48
                }
            }
        }

        /// The initial value, `medium`, as in Chrome and Safari
        package static let initial: Float = 16

        /// The ratio between adjacent sizes used by `larger` and `smaller` (CSS 2.1 §15.7)
        package static let scale: Float = 1.2

        /// Parses `<absolute-size> | <relative-size> | <length-percentage [0,∞]>`.
        /// Negative sizes are invalid (nil), so the declaration is ignored.
        package init?(_ text: String) {
            let value = text.trimmingCharacters(in: .whitespaces).lowercased()
            switch value {
            case "larger": self = .larger; return
            case "smaller": self = .smaller; return
            default: ()
            }
            if let keyword = Keyword(rawValue: value) {
                self = .keyword(keyword)
                return
            }

            var scanner = XMLParser.Scanner(text: value)
            guard let number = try? scanner.scanDouble(), number.isFinite, number >= 0 else {
                return nil
            }
            if scanner.scanStringIfPossible("%") {
                self = .relative(Float(number / 100))
            } else {
                switch scanner.scanUnit() {
                case .em: self = .relative(Float(number))
                case .ex: self = .ex(Float(number))
                case let unit?: self = .length(Float(number.apply(unit: unit)))
                case nil: self = .length(Float(number))
                }
            }
            guard scanner.isEOF else { return nil }
        }

        /// The computed font-size in px, given the parent's computed font-size.
        package func resolved(inheriting parent: Float) -> Float {
            switch self {
            case .length(let size): return size
            case .relative(let factor): return factor * parent
            case .ex(let factor): return factor * parent / 2
            case .keyword(let keyword): return keyword.size
            case .larger: return parent * Self.scale
            case .smaller: return parent / Self.scale
            }
        }
    }
}

extension DOM.FontSize: ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral {
    package init(floatLiteral value: Float) {
        self = .length(value)
    }

    package init(integerLiteral value: Int) {
        self = .length(Float(value))
    }
}
