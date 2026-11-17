//
//  Parser.XML.PaintOrderTests.swift
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


import Testing
@testable import SwiftDrawDOM

struct ParserXMLPaintOrderTests {

    typealias Layer = DOM.PaintOrder.Layer

    @Test(arguments: [
        ("normal", [.fill, .stroke, .markers]),
        ("fill", [.fill, .stroke, .markers]),
        ("stroke", [.stroke, .fill, .markers]),
        ("markers", [.markers, .fill, .stroke]),
        ("markers stroke", [.markers, .stroke, .fill]),
        ("stroke markers", [.stroke, .markers, .fill]),
        ("fill markers stroke", [.fill, .markers, .stroke]),
        ("  STROKE   markers\tfill ", [.stroke, .markers, .fill])
    ] as [(String, [Layer])])
    func validValues(text: String, layers: [Layer]) {
        #expect(DOM.PaintOrder(text)?.layers == layers)
    }

    @Test(arguments: ["", "  ", "stroke stroke", "fill normal", "normal fill", "stroke,fill", "none", "fill stroke markers fill"])
    func invalidValues(text: String) {
        #expect(DOM.PaintOrder(text) == nil)
    }

    @Test(arguments: [
        ("normal", "normal"),
        ("fill stroke markers", "normal"),
        ("stroke", "stroke"),
        ("stroke fill markers", "stroke"),
        ("markers", "markers"),
        ("fill markers", "fill markers"),
        ("stroke markers fill", "stroke markers")
    ] as [(String, String)])
    func shortestValue(text: String, value: String) throws {
        let order = try #require(DOM.PaintOrder(text))
        #expect(order.value == value)
        #expect(DOM.PaintOrder(order.value) == order)
    }

    @Test
    func attributeAndCSS() throws {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">
          <style>.a { paint-order: markers }</style>
          <path d="M0 0 H 10" paint-order="stroke"/>
          <path d="M0 0 H 10" style="paint-order: stroke markers"/>
          <path d="M0 0 H 10" class="a" paint-order="stroke"/>
          <path d="M0 0 H 10" paint-order="stroke stroke"/>
          <path d="M0 0 H 10"/>
        </svg>
        """)
        let orders = svg.childElements.map { DOM.presentationAttributes(for: $0, styles: svg.styles).paintOrder?.layers }
        #expect(orders == [
            [.stroke, .fill, .markers],
            [.stroke, .markers, .fill],
            [.markers, .fill, .stroke],
            nil,
            nil
        ])
    }
}
