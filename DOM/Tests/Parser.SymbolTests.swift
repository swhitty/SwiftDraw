//
//  Parser.SymbolTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 15/11/26.
//  Copyright 2026 WhileLoop Pty Ltd. All rights reserved.
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
import Testing

struct ParserSymbolTests {

    @Test
    func symbolIsParsedWithItsViewport() throws {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <symbol id="icon" viewBox="0 0 24 12" preserveAspectRatio="xMinYMax slice" refX="2" refY="3" overflow="visible">
            <rect width="10" height="10"/>
            <g><circle r="5"/></g>
          </symbol>
        </svg>
        """)
        let symbol = try #require(svg.childElements.first as? DOM.Symbol)
        #expect(symbol.id == "icon")
        #expect(symbol.viewBox == DOM.SVG.ViewBox(x: 0, y: 0, width: 24, height: 12))
        #expect(symbol.preserveAspectRatio == DOM.PreserveAspectRatio(align: .xMinYMax, meetOrSlice: .slice))
        #expect(symbol.refX == 2)
        #expect(symbol.refY == 3)
        #expect(symbol.overflow == .visible)
        #expect(symbol.clipsToViewport == false)
        #expect(symbol.childElements.count == 2)
        #expect(symbol.childElements.first is DOM.Rect)
        let group = try #require(symbol.childElements.last as? DOM.Group)
        #expect(group.childElements.count == 1)
    }

    @Test
    func symbolDefaults() throws {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <symbol id="icon" viewBox="0 0 bad"><rect width="10" height="10"/></symbol>
        </svg>
        """)
        let symbol = try #require(svg.childElements.first as? DOM.Symbol)
        // an invalid viewBox is ignored rather than dropping the symbol
        #expect(symbol.viewBox == nil)
        #expect(symbol.preserveAspectRatio == nil)
        #expect(symbol.refX == nil)
        #expect(symbol.refY == nil)
        #expect(symbol.overflow == nil)
        #expect(symbol.clipsToViewport)
    }

    @Test(arguments: [
        ("visible", false),
        ("auto", false),
        ("hidden", true),
        ("scroll", true),
        ("unknown", true)
    ])
    func overflowClipsToViewport(value: String, clips: Bool) throws {
        let symbol = try XMLParser().parseSymbol(XML.Element(name: "symbol"), ["overflow": value])
        #expect(symbol.clipsToViewport == clips)
    }

    @Test
    func symbolInDefsIsReferenced() throws {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <defs><symbol id="icon"><rect width="10" height="10"/></symbol></defs>
          <use href="#icon"/>
        </svg>
        """)
        #expect(svg.firstGraphicsElement(with: "icon") is DOM.Symbol)
        #expect(svg.defs.elements["icon"] is DOM.Symbol)
    }

    @Test
    func useWidthAndHeight() throws {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 200 50">
          <use href="#icon" width="24" height="50%"/>
          <use href="#icon"/>
          <use href="#icon" width="bad"/>
        </svg>
        """)
        let uses = svg.childElements.compactMap { $0 as? DOM.Use }
        #expect(uses.count == 3)
        #expect(uses[0].width == 24)
        #expect(uses[0].height == 25)
        // missing or invalid: 100% of the viewport (here the viewBox)
        #expect(uses[1].width == 200)
        #expect(uses[1].height == 50)
        #expect(uses[2].width == 200)
    }

    @Test
    func useParsedAloneHasNoDefaultSize() throws {
        let use = try XMLParser().parseUse(["href": "#icon"])
        #expect(use.width == nil)
        #expect(use.height == nil)
    }
}
