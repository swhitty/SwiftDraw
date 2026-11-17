//
//  Parser.XML.GradientAttributesTests.swift
//  SwiftDraw
//
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
import Testing
@testable import SwiftDrawDOM

/// `color-interpolation`, `fr` and `gradientTransform` on <linearGradient> and <radialGradient>.
struct ParserXMLGradientAttributesTests {

    enum Kind: String, CaseIterable, CustomTestStringConvertible {
        case linearGradient
        case radialGradient

        var testDescription: String { rawValue }
    }

    static let interpolations: [(markup: String, expected: DOM.ColorInterpolation?)] = [
        (#"<g id="g" />"#, nil),
        (#"<g id="g" color-interpolation="linearRGB" />"#, .linearRGB),
        (#"<g id="g" color-interpolation="sRGB" />"#, .sRGB),
        (#"<g id="g" color-interpolation="auto" />"#, .sRGB),
        (#"<g id="g" color-interpolation="bogus" />"#, nil),
        (#"<g id="g" style="color-interpolation: linearRGB" />"#, .linearRGB),
        (#"<g color-interpolation="linearRGB"><g id="g" /></g>"#, .linearRGB),
        (#"<defs color-interpolation="linearRGB"><g id="g" color-interpolation="sRGB" /></defs>"#, .sRGB),
        (#"<style>.c { color-interpolation: linearRGB }</style><g class="c"><g id="g" /></g>"#, .linearRGB)
    ]

    @Test(arguments: Kind.allCases, interpolations)
    func colorInterpolation(_ kind: Kind, _ test: (markup: String, expected: DOM.ColorInterpolation?)) throws {
        // the placeholder <g id="g" /> becomes the gradient, keeping its attributes
        let markup = test.markup.replacingOccurrences(of: #"<g id="g""#, with: "<\(kind) id=\"g\"")
        let svg = try parse(markup.replacingOccurrences(of: "<\(kind) id=\"g\" />", with: "<\(kind) id=\"g\"></\(kind)>"))
        #expect(colorInterpolation(kind, svg) == test.expected)
    }

    static let frValues: [(fr: String, expected: DOM.Coordinate?)] = [
        ("0.2", 0.2),
        ("0", 0),
        ("-1", nil),
        ("-10%", nil)
    ]

    @Test(arguments: frValues)
    func negativeFrIsDropped(_ test: (fr: String, expected: DOM.Coordinate?)) throws {
        let svg = try parse(#"<radialGradient id="g" fr="\#(test.fr)" />"#)
        #expect(svg.defs.radialGradients.first?.fr == test.expected)
    }

    static let transforms: [(value: String, isSpecified: Bool)] = [
        ("rotate(90)", true),
        ("", true),
        ("  ", true),
        ("none", false),
        ("rotate(", false)
    ]

    @Test(arguments: Kind.allCases, transforms)
    func gradientTransformIsSpecified(_ kind: Kind, _ test: (value: String, isSpecified: Bool)) throws {
        let svg = try parse(#"<\#(kind) id="g" gradientTransform="\#(test.value)" />"#)
        switch kind {
        case .linearGradient: #expect(svg.defs.linearGradients.first?.hasGradientTransform == test.isSpecified)
        case .radialGradient: #expect(svg.defs.radialGradients.first?.hasGradientTransform == test.isSpecified)
        }
    }

    func parse(_ contents: String) throws -> DOM.SVG {
        try DOM.SVG.parse(xml: #"<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">\#(contents)</svg>"#)
    }

    func colorInterpolation(_ kind: Kind, _ svg: DOM.SVG) -> DOM.ColorInterpolation? {
        switch kind {
        case .linearGradient: return svg.defs.linearGradients.first?.colorInterpolation
        case .radialGradient: return svg.defs.radialGradients.first?.colorInterpolation
        }
    }
}
