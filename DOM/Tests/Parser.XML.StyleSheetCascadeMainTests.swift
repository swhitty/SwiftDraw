//
//  Parser.XML.StyleSheetCascadeMainTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 15/11/26.
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

/// The SD10 cascade where it meets main's lengths, clip paths, fonts and @font-face handling.
struct ParserXMLStyleSheetCascadeMainTests {

    private func parse(_ body: String) throws -> DOM.SVG {
        try DOM.SVG.parse(data: Data("""
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">\(body)</svg>
        """.utf8))
    }

    @Test
    func emResolvesAgainstComplexSelectorFontSize() throws {
        let svg = try parse("""
        <style>g > rect { font-size: 20px }</style>
        <g><rect width="2em" height="1em"/></g>
        """)
        let rect = try #require((svg.childElements.first as? DOM.Group)?.childElements.first as? DOM.Rect)
        #expect(rect.width == 40)
        #expect(rect.height == 20)
    }

    @Test
    func emFollowsImportantRuleOverStyleAttribute() throws {
        let svg = try parse("""
        <style>.big { font-size: 30px !important }</style>
        <rect class="big" style="font-size: 10px" width="1em" height="1em"/>
        """)
        let rect = try #require(svg.childElements.first as? DOM.Rect)
        #expect(rect.width == 30)
    }

    @Test
    func rootFontSizeComesFromRootSelector() throws {
        let svg = try parse("""
        <style>:root { font-size: 8px }</style>
        <rect width="2em" height="1em"/>
        """)
        let rect = try #require(svg.childElements.first as? DOM.Rect)
        #expect(rect.width == 16)
    }

    @Test
    func clipPathOwnCascadeUsesComplexSelectors() throws {
        let svg = try parse("""
        <style>defs > clipPath { clip-rule: evenodd } #c { transform: scale(2) !important }</style>
        <defs><clipPath id="c" style="transform: scale(3)"><rect width="5" height="5"/></clipPath></defs>
        """)
        let clip = try #require(svg.defs.clipPaths.first)
        let attributes = DOM.presentationAttributes(for: clip, styles: svg.styles)
        #expect(attributes.clipRule == .evenodd)
        #expect(attributes.transform == [.scale(sx: 2, sy: 2)])
    }

    @Test
    func clipPathDisplayFromAttributeSelector() throws {
        let svg = try parse("""
        <style>clipPath[data-hidden] rect { display: none }</style>
        <defs><clipPath id="c" data-hidden="1"><rect width="5" height="5"/></clipPath></defs>
        """)
        let clip = try #require(svg.defs.clipPaths.first)
        let rect = try #require(clip.childElements.first)
        #expect(DOM.presentationAttributes(for: rect, styles: svg.styles).display == DOM.DisplayMode.none)
    }

    @Test
    func fontWeightAndStyleCascadeFromComplexSelectors() throws {
        let svg = try parse("""
        <style>g text:first-child { font-weight: bold; font-style: italic }</style>
        <g><text font-weight="300">a</text><text font-weight="300">b</text></g>
        """)
        let group = try #require(svg.childElements.first as? DOM.Group)
        let first = DOM.presentationAttributes(for: group.childElements[0], styles: svg.styles)
        let second = DOM.presentationAttributes(for: group.childElements[1], styles: svg.styles)
        #expect(first.fontWeight == .bold)
        #expect(first.fontStyle == .italic)
        #expect(second.fontWeight == .number(300))
    }

    @Test
    func invalidFontFaceKeepsComplexRules() throws {
        let sheet = try XMLParser(options: .skipInvalidElements).parseStyleSheetElement("""
        g > .a { fill: red; }
        @font-face { font-family: 'NoSource'; }
        @font-face { font-family: 'Valid'; src: local('Helvetica'); }
        rect:first-child { fill: blue; }
        """)
        #expect(sheet.fonts.map(\.family) == ["Valid"])
        #expect(sheet.rules.count == 2)
    }
}
