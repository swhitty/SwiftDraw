//
//  DOM.FilterFunction.swift
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

package extension DOM {

    /// One entry of the `filter` property (Filter Effects 1 §12): a reference to a `<filter>` element
    /// or a filter function. The entries apply in order, each to the result of the one before.
    enum FilterValue: Hashable {
        case url(DOM.URL)
        case function(FilterFunction)

        package var url: DOM.URL? {
            guard case .url(let url) = self else { return nil }
            return url
        }
    }

    /// A length kept with its unit: `em` and `ex` resolve against the font-size of the element
    /// the property applies to, which is only known once the cascade is done.
    struct UnitLength: Hashable {
        package var value: DOM.Float
        package var unit: DOM.Unit?

        package init(_ value: DOM.Float, unit: DOM.Unit? = nil) {
            self.value = value
            self.unit = unit
        }

        /// in user units
        package func resolve(fontSize: DOM.Float) -> DOM.Float {
            switch unit {
            case .em:
                return value * fontSize
            case .ex:
                return value * fontSize / 2
            case let unit?:
                return DOM.Float(Double(value).apply(unit: unit))
            case nil:
                return value
            }
        }
    }

    /// Filter Effects 1 §12.2: the filter functions, with their defaults applied.
    /// Amounts are numbers (a percentage divided by 100) and never negative.
    enum FilterFunction: Hashable {
        case blur(UnitLength)
        /// a nil color is currentColor
        case dropShadow(color: DOM.Color?, dx: UnitLength, dy: UnitLength, stdDeviation: UnitLength)
        case hueRotate(degrees: DOM.Float)
        case grayscale(DOM.Float)
        case sepia(DOM.Float)
        case saturate(DOM.Float)
        case invert(DOM.Float)
        case opacity(DOM.Float)
        case brightness(DOM.Float)
        case contrast(DOM.Float)
    }
}
