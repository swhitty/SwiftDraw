//
//  Parser.XML.TransformOriginTests.swift
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
import Testing
@testable import SwiftDrawDOM

struct ParserXMLTransformOriginTests {

    typealias Origin = DOM.TransformOrigin

    @Test(arguments: [
        ("left", Origin(x: .fraction(0), y: .fraction(0.5))),
        ("center", Origin(x: .fraction(0.5), y: .fraction(0.5))),
        ("right", Origin(x: .fraction(1), y: .fraction(0.5))),
        ("top", Origin(x: .fraction(0.5), y: .fraction(0))),
        ("bottom", Origin(x: .fraction(0.5), y: .fraction(1))),
        ("top left", Origin(x: .fraction(0), y: .fraction(0))),
        ("left top", Origin(x: .fraction(0), y: .fraction(0))),
        ("bottom right", Origin(x: .fraction(1), y: .fraction(1))),
        ("center left", Origin(x: .fraction(0), y: .fraction(0.5))),
        ("center bottom", Origin(x: .fraction(0.5), y: .fraction(1))),
        ("RIGHT  Bottom", Origin(x: .fraction(1), y: .fraction(1))),
    ])
    func keywords(_ text: String, _ expected: Origin) {
        #expect(XMLParser().parseTransformOrigin(text) == expected)
    }

    @Test(arguments: [
        ("10", Origin(x: .length(10), y: .fraction(0.5))),
        ("10px", Origin(x: .length(10), y: .fraction(0.5))),
        ("25%", Origin(x: .fraction(0.25), y: .fraction(0.5))),
        ("10 20", Origin(x: .length(10), y: .length(20))),
        ("100px 100px", Origin(x: .length(100), y: .length(100))),
        ("50% 50%", Origin(x: .fraction(0.5), y: .fraction(0.5))),
        ("1in 25%", Origin(x: .length(96), y: .fraction(0.25))),
        ("-5 0.5", Origin(x: .length(-5), y: .length(0.5))),
        ("25% top", Origin(x: .fraction(0.25), y: .fraction(0))),
        ("left 30px", Origin(x: .fraction(0), y: .length(30))),
        ("10px 20px 30px", Origin(x: .length(10), y: .length(20))),
        ("right bottom 5", Origin(x: .fraction(1), y: .fraction(1))),
    ])
    func lengthsAndPercentages(_ text: String, _ expected: Origin) {
        #expect(XMLParser().parseTransformOrigin(text) == expected)
    }

    @Test(arguments: [
        "",
        "middle",
        "10px,20px",
        "top 10px",
        "10px left",
        "left right",
        "top bottom",
        "10 20 30%",
        "1 2 3 4",
        "2em",
        "10qq",
    ])
    func invalidValuesAreDropped(_ text: String) {
        #expect(XMLParser().parseTransformOrigin(text) == nil)
    }

    @Test
    func attributeStyleAndStylesheet() throws {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="200" height="200">
          <style>.c { transform-origin: right bottom; }</style>
          <rect id="a" width="10" height="10" transform-origin="center" />
          <rect id="b" width="10" height="10" style="transform-origin: 10px 20px" />
          <rect id="c" class="c" width="10" height="10" />
          <rect id="d" width="10" height="10" transform-origin="nonsense" />
        </svg>
        """)

        func origin(_ id: String) throws -> Origin? {
            let element = try #require(svg.firstGraphicsElement(with: id))
            return DOM.presentationAttributes(for: element, styles: svg.styles).transformOrigin
        }
        #expect(try origin("a") == Origin(x: .fraction(0.5), y: .fraction(0.5)))
        #expect(try origin("b") == Origin(x: .length(10), y: .length(20)))
        #expect(try origin("c") == Origin(x: .fraction(1), y: .fraction(1)))
        #expect(try origin("d") == nil)
    }

    @Test
    func paintServers() throws {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="200" height="200">
          <linearGradient id="l" gradientTransform="scale(2)" transform-origin="0.5 0.5" />
          <radialGradient id="r" transform-origin="center" />
          <pattern id="p" width="1" height="1" transform-origin="top" />
        </svg>
        """)
        #expect(svg.defs.linearGradients.first?.transformOrigin == Origin(x: .length(0.5), y: .length(0.5)))
        #expect(svg.defs.radialGradients.first?.transformOrigin == Origin(x: .fraction(0.5), y: .fraction(0.5)))
        #expect(svg.defs.patterns.first?.transformOrigin == Origin(x: .fraction(0.5), y: .fraction(0)))
    }
}
