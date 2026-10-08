//
//  Parser.TolerantTests.swift
//  SwiftDraw
//
//  Created by Misoservices on 08/10/26.
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

@testable import SwiftDrawDOM
import Foundation
import Testing

// SD4: a bad value drops the attribute, never the document
struct TolerantParsingTests {

    private func parse(_ svg: String) throws -> DOM.SVG {
        try DOM.SVG.parse(data: Data(svg.utf8))
    }

    private func color(_ value: String) throws -> DOM.Color {
        try SwiftDrawDOM.XMLParser().parseFill(value).getColor()
    }

    private func expectRGBA(_ value: String, _ r: DOM.Float, _ g: DOM.Float, _ b: DOM.Float, _ a: DOM.Float,
                            sourceLocation: SourceLocation = #_sourceLocation) throws {
        guard case let .rgbf(cr, cg, cb, ca) = try color(value) else {
            Issue.record("not rgbf: \(value)", sourceLocation: sourceLocation)
            return
        }
        for (x, y) in zip([cr, cg, cb, ca], [r, g, b, a]) {
            #expect(abs(x - y) < 0.001, sourceLocation: sourceLocation)
        }
    }

    @Test
    func hsl() throws {
        try expectRGBA("hsl(0, 100%, 50%)", 1, 0, 0, 1)
        try expectRGBA("hsl(120, 100%, 25%)", 0, 0.5, 0, 1)
        try expectRGBA("hsla(240 100% 50% / 0.5)", 0, 0, 1, 0.5)
        try expectRGBA("hsl(360deg, 100%, 50%)", 1, 0, 0, 1)
        #expect(throws: (any Error).self) { try color("hsl(a, b, c)") }
    }

    @Test
    func keywordsAreCaseInsensitive() throws {
        #expect(try color("Red") == .keyword(.red))
        #expect(try color("DARKBLUE") == .keyword(.darkblue))
        #expect(try color("CurrentColor") == .currentColor)
        #expect(try color("None") == .none)
        #expect(try color("rebeccapurple") == .keyword(.rebeccapurple))
        #expect(DOM.Color.Keyword.rebeccapurple.rgbi == (102, 51, 153))
    }

    @Test
    func hexWithAlpha() throws {
        #expect(try color("#ff0000") == .hex(255, 0, 0))
        #expect(try color("#f00") == .hex(255, 0, 0))
        #expect(try color("#ff0000ff") == .rgbi(255, 0, 0, 1))
        #expect(try color("#ff000000") == .rgbi(255, 0, 0, 0))
        #expect(try color("#f00f") == .rgbi(255, 0, 0, 1))
        #expect(throws: (any Error).self) { _ = try color("#ff000") }
    }

    @Test
    func invalidValuesDropTheAttribute() throws {
        let svg = try parse("""
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">
          <rect id="a" width="5" height="5" fill="" stroke="inherit" opacity="abc"
                stroke-width="wide" display="inline-block" stroke-linecap="none"
                dominant-baseline="text-top" clip-path="none" mask="none" filter="none"
                transform="none"/>
        </svg>
        """)
        #expect(svg.childElements.count == 1)
        let att = svg.childElements[0].attributes
        #expect(att.fill == nil)
        #expect(att.stroke == nil)
        #expect(att.opacity == nil)
        #expect(att.strokeWidth == nil)
        #expect(att.display == nil)
        #expect(att.strokeLineCap == nil)
        #expect(att.dominantBaseline == nil)
        // `none` is a valid value: it is kept so it overrides a lower stylesheet rule (SD10)
        #expect(att.clipPath == DOM.URL.none)
        #expect(att.mask == DOM.URL.none)
        #expect(att.filter == DOM.URL.none)
        #expect(att.transform == [])
    }

    @Test
    func goodAttributesSurviveBadNeighbours() throws {
        let svg = try parse("""
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">
          <rect width="5" height="5" fill="red" stroke-linecap="none" stroke-width="3"/>
        </svg>
        """)
        let att = svg.childElements[0].attributes
        #expect(att.fill == .color(.keyword(.red)))
        #expect(att.strokeWidth == 3)
        #expect(att.strokeLineCap == nil)
    }

    @Test
    func opacityIsClamped() throws {
        let svg = try parse("""
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">
          <rect width="5" height="5" opacity="2" fill-opacity="-1" stroke-opacity="0.5"/>
        </svg>
        """)
        let att = svg.childElements[0].attributes
        #expect(att.opacity == 1)
        #expect(att.fillOpacity == 0)
        #expect(att.strokeOpacity == 0.5)
    }

    @Test
    func importantIsIgnored() throws {
        let svg = try parse("""
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">
          <rect width="5" height="5" style="fill: red !important; stroke-width: 2 ! important"/>
        </svg>
        """)
        // the priority flag is kept apart (SD10) so inline !important beats stylesheet !important
        let att = svg.childElements[0].importantStyle
        #expect(att.fill == .color(.keyword(.red)))
        #expect(att.strokeWidth == 2)
    }

    @Test
    func transformUnitsAreAccepted() throws {
        let parser = SwiftDrawDOM.XMLParser()
        #expect(try parser.parseTransform("translate(10px, 20px)") == [.translate(tx: 10, ty: 20)])
        #expect(try parser.parseTransform("rotate(45deg)") == [.rotate(angle: 45)])
    }

    @Test
    func plainHrefOnImageAndGradients() throws {
        let svg = try parse("""
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">
          <defs>
            <linearGradient id="base"><stop offset="0" stop-color="red"/></linearGradient>
            <linearGradient id="derived" href="#base"/>
            <radialGradient id="rbase"><stop offset="0" stop-color="red"/></radialGradient>
            <radialGradient id="rderived" href="#rbase"/>
          </defs>
          <image width="4" height="4" href="data:image/png;base64,iVBORw0KGgo="/>
        </svg>
        """)
        #expect(svg.childElements.count == 1)
        #expect(svg.childElements[0] is DOM.Image)
        #expect(svg.defs.linearGradients.first { $0.id == "derived" }?.href?.fragment == "base")
        #expect(svg.defs.radialGradients.first { $0.id == "rderived" }?.href?.fragment == "rbase")
    }

    @Test
    func hslEdgeCases() throws {
        // hue wraps: -120 == 240, 480 == 120
        try expectRGBA("hsl(-120, 100%, 50%)", 0, 0, 1, 1)
        try expectRGBA("hsl(480, 100%, 50%)", 0, 1, 0, 1)
        // l > 0.5
        try expectRGBA("hsl(0, 100%, 75%)", 1, 0.5, 0.5, 1)
        // s = 0 is grey
        try expectRGBA("hsl(200, 0%, 40%)", 0.4, 0.4, 0.4, 1)
        // percentage alpha and comma-form hsla
        try expectRGBA("hsla(0 100% 50% / 50%)", 1, 0, 0, 0.5)
        try expectRGBA("hsla(0, 100%, 50%, 0.25)", 1, 0, 0, 0.25)
    }

    @Test
    func hexWithAlphaEightDigits() throws {
        guard case let .rgbi(r, g, b, a) = try color("#11223344") else {
            Issue.record("expected rgbi")
            return
        }
        #expect(r == 0x11 && g == 0x22 && b == 0x33)
        #expect(abs(a - 0x44 / 255.0) < 0.001)
    }

    @Test
    func emptyStyleDeclarationsAreSkipped() throws {
        let parser = SwiftDrawDOM.XMLParser()
        #expect(try parser.parseStyleAttributes("fill:;stroke:red") == ["stroke": "red"])
        #expect(try parser.parseStyleAttributes("fill: ") == [:])
        #expect(try parser.parseStyleAttributes("fill") == [:])
        #expect(try parser.parseStyleAttributes("; ;") == [:])
        #expect(try parser.parseStyleAttributes(";") == [:])
        #expect(try parser.parseStyleAttributes("fill:red;;stroke:blue;") == ["fill": "red", "stroke": "blue"])

        let svg = try parse("""
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">
          <rect width="5" height="5" style="fill:;stroke:red"/>
        </svg>
        """)
        #expect(svg.childElements.count == 1)
        #expect(svg.childElements[0].style.stroke == .color(.keyword(.red)))
    }

    @Test
    func invalidGradientTransformIsDropped() throws {
        let svg = try parse("""
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">
          <defs>
            <linearGradient id="a" gradientTransform="none"><stop offset="0" stop-color="red"/></linearGradient>
            <radialGradient id="b" gradientTransform="junk(1)"><stop offset="0" stop-color="red"/></radialGradient>
          </defs>
          <rect width="5" height="5"/>
        </svg>
        """)
        #expect(svg.childElements.count == 1)
        #expect(svg.defs.linearGradients.first { $0.id == "a" }?.gradientTransform == [])
        #expect(svg.defs.radialGradients.first { $0.id == "b" }?.gradientTransform == [])
    }

    @Test
    func importantWithSpaces() {
        typealias A = SwiftDrawDOM.XMLParser.Attributes
        #expect(A.removingImportant(from: "red !important") == "red ")
        #expect(A.removingImportant(from: "red ! important") == "red ")
        #expect(A.removingImportant(from: "red !IMPORTANT") == "red ")
        #expect(A.removingImportant(from: "important") == "important")
        #expect(A.removingImportant(from: "red") == "red")
    }

    @Test
    func invalidHrefFallsBackToXLink() throws {
        let att: [String: String] = ["href": "", "xlink:href": "#base"]
        #expect(try att.parseHref().fragment == "base")
        let valid: [String: String] = ["href": "#new", "xlink:href": "#old"]
        #expect(try valid.parseHref().fragment == "new")
    }

    @Test
    func negativeStrokeWidthIsDropped() throws {
        let svg = try parse("""
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">
          <rect width="5" height="5" stroke-width="-2" font-size="12"/>
          <rect width="5" height="5" stroke-width="0"/>
        </svg>
        """)
        #expect(svg.childElements[0].attributes.strokeWidth == nil)
        #expect(svg.childElements[0].attributes.fontSize == 12)
        #expect(svg.childElements[1].attributes.strokeWidth == 0)
    }
}
