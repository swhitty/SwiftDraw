//
//  Parser.XML.ColorTests.swift
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
        #expect(att.clipPath == nil)
        #expect(att.mask == nil)
        #expect(att.filter == nil)
        #expect(att.transform == nil)
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
        let att = svg.childElements[0].style
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
}
