//
//  DOM.swift
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

package enum DOM { /* namespace */  }

package extension DOM {
    typealias Float = Swift.Float
    typealias Coordinate = Swift.Float
    typealias Length = Swift.Int
    typealias Opacity = Swift.Float
    typealias Bool = Swift.Bool
    typealias URL = Foundation.URL
}

extension DOM {
    /// A `stroke-width`, `stroke-dasharray` or `stroke-dashoffset` length; a percentage is relative
    /// to the viewport diagonal and `em` to the element's font-size, both resolved in LayerTree.
    package enum DashLength: Equatable {
        case absolute(Float)
        case percentage(Float)
        /// A multiple of the font-size; `ex` is stored as half an `em` (CSS 2.1 §4.3.2)
        case em(Float)

        var isNegative: Bool {
            switch self {
            case .absolute(let v), .percentage(let v), .em(let v): return v < 0
            }
        }
    }

    package struct Point: Equatable {
        package var x: Coordinate
        package var y: Coordinate

        package init(_ x: Coordinate, _ y: Coordinate) {
            self.x = x
            self.y = y
        }
    }

    package enum Fill: Equatable {
        case url(URL)
        case color(DOM.Color)
        case urlWithFallback(URL, DOM.Color)

        package func getColor() throws -> DOM.Color {
            switch self {
            case .url, .urlWithFallback:
                throw Error.missing("Color")
            case .color(let c):
                return c
            }
        }
    }

    package enum FillRule: String {
        case nonzero
        case evenodd
    }

    package enum DisplayMode: String {
        case none
        case inline
        case block
    }

    package enum Visibility: String {
        case visible
        case hidden
        case collapse
    }

    /// CSS Overflow §3: `visible` and `auto` do not clip; `hidden` and `scroll` clip to the viewport
    package enum Overflow: String {
        case visible
        case hidden
        case scroll
        case auto
    }

    /// SVG 2 §13.6 `paint-order`: the order the fill, stroke and markers of a shape are painted in.
    /// Always holds all three; keywords left out of the value follow in the default order.
    package struct PaintOrder: Hashable, Sendable {
        package enum Layer: String, CaseIterable, Sendable {
            case fill
            case stroke
            case markers
        }

        package var layers: [Layer]

        package static let normal = PaintOrder(layers: Layer.allCases)

        package init(layers: [Layer]) {
            self.layers = layers
        }

        /// `normal`, or one to three distinct keywords; nil for anything else (a duplicate, an
        /// unknown keyword or an empty value), so the declaration is dropped.
        package init?(_ text: String) {
            let tokens =
                text
                .split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" || $0 == "\r" })
                .map { $0.lowercased() }
            if tokens == ["normal"] {
                self = .normal
                return
            }
            var layers = [Layer]()
            for token in tokens {
                guard let layer = Layer(rawValue: token), !layers.contains(layer) else { return nil }
                layers.append(layer)
            }
            guard !layers.isEmpty else { return nil }
            self.layers = layers + Layer.allCases.filter { !layers.contains($0) }
        }

        /// The shortest value that serialises this order.
        package var value: String {
            guard self != .normal else { return "normal" }
            // trailing keywords that are in their default order anyway are left out
            func value(_ count: Int) -> String {
                layers.prefix(count).map(\.rawValue).joined(separator: " ")
            }
            let count = (1..<layers.count).first { PaintOrder(value($0)) == self } ?? layers.count
            return value(count)
        }
    }

    // SVG 1.1 §12.7.1 color-interpolation (and Filter Effects 1 §10 color-interpolation-filters):
    // the space gradients interpolate and masks compute luminance in; `auto` is sRGB
    package enum ColorInterpolation: String, Hashable {
        case auto
        case sRGB
        case linearRGB
    }

    // CSS Masking §7.2: whether a mask uses the luminance or the alpha of its contents
    package enum MaskType: String {
        case luminance
        case alpha
    }

    package enum LineCap: String {
        case butt
        case round
        case square
    }

    package enum LineJoin: String {
        case miter
        case round
        case bevel
    }

    package enum TextAnchor: String {
        case start
        case middle
        case end
    }

    /// CSS `font-weight`: a keyword, or a number from 1 to 1000. `bolder` and `lighter` are relative to the
    /// inherited weight.
    package enum FontWeight: Hashable {
        case normal
        case bold
        case bolder
        case lighter
        case number(Int)

        package init?(_ text: String) {
            switch text.trimmingCharacters(in: .whitespaces).lowercased() {
            case "normal": self = .normal
            case "bold": self = .bold
            case "bolder": self = .bolder
            case "lighter": self = .lighter
            case let value:
                guard let number = Double(value), number >= 1, number <= 1000 else { return nil }
                self = .number(Int(number.rounded()))
            }
        }

        /// The numeric weight, given the inherited one (CSS Fonts 4 §2.2).
        package func resolved(inheriting parent: Int) -> Int {
            switch self {
            case .normal: return 400
            case .bold: return 700
            case .number(let value): return value
            case .bolder:
                if parent < 350 { return 400 }
                if parent < 550 { return 700 }
                return max(parent, 900)
            case .lighter:
                if parent < 550 { return min(parent, 100) }
                if parent < 750 { return 400 }
                return 700
            }
        }
    }

    /// CSS `font-style`. An oblique angle (`oblique 10deg`) is accepted and treated as oblique.
    package enum FontStyle: Hashable {
        case normal
        case italic
        case oblique

        package init?(_ text: String) {
            let keyword =
                text.trimmingCharacters(in: .whitespaces).lowercased()
                .split(separator: " ").first.map(String.init) ?? ""
            switch keyword {
            case "normal": self = .normal
            case "italic": self = .italic
            case "oblique": self = .oblique
            default: return nil
            }
        }
    }

    /// `dominant-baseline` and `alignment-baseline` (CSS Inline 3, SVG 1.1): the baseline of the
    /// font that sits on the text's `y`
    package enum TextBaseline: String {
        case auto
        case alphabetic
        case middle
        case central
        case hanging
        case mathematical
        case ideographic
        case textBeforeEdge = "text-before-edge"
        case textAfterEdge = "text-after-edge"
        /// the parent's value; `alignment-baseline` is not inherited otherwise
        case inherit

        /// A value, with the aliases SVG 1.1 and CSS Inline 3 give some of them. nil for unknown
        /// values, which leave the inherited baseline.
        package init?(css value: String) {
            switch value.trimmingCharacters(in: .whitespaces).lowercased() {
            case "auto", "baseline", "use-script": self = .auto
            // SVG 1.1: keep the parent's baseline, as `inherit`
            case "no-change", "reset-size": return nil
            case "text-top", "before-edge": self = .textBeforeEdge
            case "text-bottom", "after-edge": self = .textAfterEdge
            case let other: self.init(rawValue: other)
            }
        }
    }

    /// `baseline-shift`: how far a `<tspan>` (and the text within it) is raised from the baseline of
    /// its parent. Shifts of nested elements add up.
    package enum BaselineShift: Equatable {
        case baseline
        case sub
        case `super`
        /// positive raises; a percentage is of the font-size (the line-height)
        case length(DashLength)
        /// the value of the parent element: `baseline-shift` is not inherited otherwise
        case inherit

        package init?(css value: String) {
            switch value.trimmingCharacters(in: .whitespaces).lowercased() {
            case "baseline": self = .baseline
            case "sub": self = .sub
            case "super": self = .super
            case "inherit": self = .inherit
            default:
                guard let length = XMLParser.parseDashLength(value) else { return nil }
                self = .length(length)
            }
        }
    }

    package enum Transform: Equatable {
        case matrix(a: Float, b: Float, c: Float, d: Float, e: Float, f: Float)
        case translate(tx: Float, ty: Float)
        case scale(sx: Float, sy: Float)
        case rotate(angle: Float)
        case rotatePoint(angle: Float, cx: Float, cy: Float)
        case skewX(angle: Float)
        case skewY(angle: Float)
    }

    package enum Unit {
        case pixel
        case inch
        case centimeter
        case millimeter
        case point
        case pica
        case em
        case ex
    }

    package enum Error: Swift.Error {
        case missing(String)
    }
}

package extension DOM.Unit {
    var rawValue: String {
        switch self {
        case .pixel:
            return "px"
        case .inch:
            return "in"
        case .centimeter:
            return "cm"
        case .millimeter:
            return "mm"
        case .point:
            return "pt"
        case .pica:
            return "pc"
        case .em:
            return "em"
        case .ex:
            return "ex"
        }
    }
}

package extension Double {
    func apply(unit: DOM.Unit) -> Double {
        switch unit {
        case .pixel:
            return self
        case .inch:
            return self * 96
        case .centimeter:
            return self * 96 / 2.54
        case .millimeter:
            return self * 96 / 25.4
        case .point:
            return self * 96 / 72
        case .pica:
            return self * 16
        case .em, .ex:
            return self
        }
    }
}

extension DOM.DashLength: ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral {
    package init(floatLiteral value: Float) {
        self = .absolute(value)
    }

    package init(integerLiteral value: Int) {
        self = .absolute(Float(value))
    }
}
