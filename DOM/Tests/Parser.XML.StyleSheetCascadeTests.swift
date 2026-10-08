//
//  Parser.XML.StyleSheetCascadeTests.swift
//  SwiftDraw
//
//  Added by Misoservices for the Backdrop fork of SwiftDraw (altered source version).
//  Copyright 2026 Misoservices
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

@Suite("Parser XML StyleSheet Cascade Tests")
struct ParserXMLStyleSheetCascadeTests {

    typealias Selector = DOM.StyleSheet.ComplexSelector

    // MARK: - Selector parsing

    @Test
    func parsesCombinatorsAndCompounds() throws {
        let s = try #require(Selector.parse("g.layer > rect#a.b[fill='red']:first-child ~ circle + path  text"))
        #expect(s.compounds.count == 5)
        #expect(s.combinators == [.child, .generalSibling, .adjacentSibling, .descendant])
        #expect(s.compounds[1].element == "rect")
        #expect(s.compounds[1].ids == ["a"])
        #expect(s.compounds[1].classes == ["b"])
        #expect(s.compounds[1].attributes == [.init(name: "fill", match: .equals, value: "red", caseInsensitive: false)])
        #expect(s.compounds[1].pseudoClasses == [.firstChild])
    }

    @Test
    func specificity() throws {
        #expect(try #require(Selector.parse("*")).specificity == .init(a: 0, b: 0, c: 0))
        #expect(try #require(Selector.parse("g rect")).specificity == .init(a: 0, b: 0, c: 2))
        #expect(try #require(Selector.parse("rect.a[x]:first-child")).specificity == .init(a: 0, b: 3, c: 1))
        #expect(try #require(Selector.parse("#a .b")).specificity == .init(a: 1, b: 1, c: 0))
    }

    @Test
    func malformedSelectorDropsTheRule() {
        #expect(Selector.parseList(".a, .b..c") == nil)
        #expect(Selector.parseList("rect[") == nil)
        #expect(Selector.parseList("svg|rect") == nil)
        #expect(Selector.parseList("") == nil)
        #expect(Selector.parseList(".a, rect:hover")?.count == 2)
    }

    @Test
    func escapedIdentifiers() throws {
        let s = try #require(Selector.parse(#"[inkscape\:label="x"]"#))
        #expect(s.compounds[0].attributes[0].name == "inkscape:label")
    }

    // MARK: - Tolerant sheet parsing

    @Test
    func badDeclarationKeepsTheSheet() throws {
        let sheet = try XMLParser().parseStyleSheetElement(
            """
            :root { --x: red; }
            .a { fill: var(--x); stroke: blue; }
            .b { fill: green }
            """
        )
        #expect(sheet.attributes[.class("a")]?.fill == nil)
        #expect(sheet.attributes[.class("a")]?.stroke == .color(.keyword(.blue)))
        #expect(sheet.attributes[.class("b")]?.fill == .color(.keyword(.green)))
    }

    @Test
    func malformedRulesAreSkipped() throws {
        let sheet = try XMLParser().parseStyleSheetElement(
            """
            <!--
            @import url("other.css");
            @charset "utf-8";
            .a { fill }
            .b..c { fill: red }
            .d { fill: blue; ; stroke : ; }
            /* a */ .e { fill: url("data:image/png;base64,AA==") } /* b */
            .f { fill: lime }
            -->
            .g { fill: navy
            """
        )
        #expect(sheet.attributes[.class("a")] != nil)
        #expect(sheet.attributes[.class("a")]?.fill == nil)
        #expect(sheet.attributes[.class("c")] == nil)
        #expect(sheet.attributes[.class("d")]?.fill == .color(.keyword(.blue)))
        #expect(sheet.attributes[.class("e")] != nil)
        #expect(sheet.attributes[.class("f")]?.fill == .color(.keyword(.lime)))
        #expect(sheet.attributes[.class("g")]?.fill == .color(.keyword(.navy)))
    }

    @Test
    func commentsAreNotGreedy() throws {
        let entries = try XMLParser.parseSelectorEntries(
            """
            /* one */ .a { fill: red } /* two */
            .b { fill: blue } /* unterminated
            .c { fill: green }
            """
        )
        #expect(entries == [.class("a"): ["fill": "red"], .class("b"): ["fill": "blue"]])
    }

    @Test
    func parsesImportantDeclarations() throws {
        let sheet = try XMLParser().parseStyleSheetElement(".a { fill: red !important; stroke: blue }")
        #expect(sheet.rules.count == 1)
        #expect(sheet.rules[0].importantAttributes.fill == .color(.keyword(.red)))
        #expect(sheet.rules[0].attributes.fill == nil)
        #expect(sheet.rules[0].attributes.stroke == .color(.keyword(.blue)))
    }

    @Test
    func badFontFaceKeepsTheSheet() throws {
        let sheet = try XMLParser().parseStyleSheetElement(
            """
            @font-face { font-family: Broken; }
            .a { fill: red }
            """
        )
        #expect(sheet.fonts.isEmpty)
        #expect(sheet.attributes[.class("a")]?.fill == .color(.keyword(.red)))
    }

    // MARK: - Matching and cascade

    private func fill(of id: String, style: String, body: String) throws -> DOM.Fill? {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">
        <style>\(style)</style>
        \(body)
        </svg>
        """)
        let element = try #require(Self.find(id, in: svg.childElements))
        return DOM.presentationAttributes(for: element, styles: svg.styles).fill
    }

    static func find(_ id: String, in elements: [DOM.GraphicsElement]) -> DOM.GraphicsElement? {
        for e in elements {
            if e.id == id { return e }
            if let c = e as? any ContainerElement, let found = find(id, in: c.childElements) {
                return found
            }
        }
        return nil
    }

    @Test
    func descendantAndChildCombinators() throws {
        let body = #"<g class="l"><g><rect id="r" width="1" height="1"/></g><circle id="c" r="1"/></g>"#
        #expect(try fill(of: "r", style: ".l rect { fill: red }", body: body) == .color(.keyword(.red)))
        #expect(try fill(of: "r", style: ".l > rect { fill: red }", body: body) == nil)
        #expect(try fill(of: "c", style: ".l > circle { fill: red }", body: body) == .color(.keyword(.red)))
        #expect(try fill(of: "c", style: "svg > g > circle { fill: red }", body: body) == .color(.keyword(.red)))
    }

    @Test
    func siblingCombinatorsAndStructuralPseudoClasses() throws {
        let body = #"<g><rect id="a" width="1" height="1"/><title>t</title><rect id="b" width="1" height="1"/><rect id="c" width="1" height="1"/></g>"#
        #expect(try fill(of: "a", style: "rect:first-child { fill: red }", body: body) == .color(.keyword(.red)))
        #expect(try fill(of: "b", style: "rect:first-child { fill: red }", body: body) == nil)
        #expect(try fill(of: "c", style: "rect:last-child { fill: red }", body: body) == .color(.keyword(.red)))
        #expect(try fill(of: "b", style: "title + rect { fill: red }", body: body) == .color(.keyword(.red)))
        #expect(try fill(of: "c", style: "title + rect { fill: red }", body: body) == nil)
        #expect(try fill(of: "c", style: "#a ~ rect { fill: red }", body: body) == .color(.keyword(.red)))
        #expect(try fill(of: "a", style: "#a ~ rect { fill: red }", body: body) == nil)
    }

    @Test
    func compoundAndAttributeSelectors() throws {
        let body = #"<rect id="r" class="x y" data-k="one-two three" width="1" height="1"/>"#
        #expect(try fill(of: "r", style: "rect.x.y { fill: red }", body: body) == .color(.keyword(.red)))
        #expect(try fill(of: "r", style: "rect.x.z { fill: red }", body: body) == nil)
        #expect(try fill(of: "r", style: "[data-k] { fill: red }", body: body) == .color(.keyword(.red)))
        #expect(try fill(of: "r", style: "[data-k~=three] { fill: red }", body: body) == .color(.keyword(.red)))
        #expect(try fill(of: "r", style: "[data-k|=one] { fill: red }", body: body) == .color(.keyword(.red)))
        #expect(try fill(of: "r", style: "[data-k^='one'] { fill: red }", body: body) == .color(.keyword(.red)))
        #expect(try fill(of: "r", style: "[data-k$=ree] { fill: red }", body: body) == .color(.keyword(.red)))
        #expect(try fill(of: "r", style: "[data-k*=two] { fill: red }", body: body) == .color(.keyword(.red)))
        #expect(try fill(of: "r", style: "[data-k=one] { fill: red }", body: body) == nil)
        #expect(try fill(of: "r", style: "[id=R i] { fill: red }", body: body) == .color(.keyword(.red)))
    }

    @Test
    func specificityBeatsSourceOrder() throws {
        let body = #"<g class="l"><rect id="r" class="a" width="1" height="1"/></g>"#
        #expect(try fill(of: "r", style: ".l .a { fill: red } .a { fill: blue }", body: body) == .color(.keyword(.red)))
        #expect(try fill(of: "r", style: "#r { fill: red } .l > rect.a { fill: blue }", body: body) == .color(.keyword(.red)))
    }

    @Test
    func sourceOrderBreaksTies() throws {
        let body = #"<rect id="r" class="a b" width="1" height="1"/>"#
        #expect(try fill(of: "r", style: ".b { fill: red } .a { fill: blue }", body: body) == .color(.keyword(.blue)))
        #expect(try fill(of: "r", style: ".a { fill: blue } .b { fill: red }", body: body) == .color(.keyword(.red)))
        // later <style> elements come later in source order
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">
        <style>.b { fill: red }</style>\(body)<style>.a { fill: blue }</style>
        </svg>
        """)
        #expect(DOM.presentationAttributes(for: svg.childElements[0], styles: svg.styles).fill == .color(.keyword(.blue)))
    }

    @Test
    func cascadeOrigins() throws {
        // presentation attribute < stylesheet < style="" < !important
        let body = #"<rect id="r" class="a" fill="black" style="fill: blue" width="1" height="1"/>"#
        #expect(try fill(of: "r", style: ".a { fill: red }", body: body) == .color(.keyword(.blue)))
        #expect(try fill(of: "r", style: ".a { fill: red !important }", body: body) == .color(.keyword(.red)))
        let plain = #"<rect id="r" class="a" fill="black" width="1" height="1"/>"#
        #expect(try fill(of: "r", style: ".a { fill: red }", body: plain) == .color(.keyword(.red)))
    }

    @Test
    func unsupportedSelectorInGroupKeepsTheOthers() throws {
        let body = #"<rect id="r" class="a" width="1" height="1"/>"#
        #expect(try fill(of: "r", style: ".a:hover, .a { fill: red }", body: body) == .color(.keyword(.red)))
        #expect(try fill(of: "r", style: ".a:hover { fill: red }", body: body) == nil)
        #expect(try fill(of: "r", style: ".a, .. { fill: red }", body: body) == nil)
    }

    @Test
    func matchesInsideDefsAndMasks() throws {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">
        <style>mask > rect { fill: white } #m { opacity: 0.5 }</style>
        <defs><mask id="m"><rect width="1" height="1"/></mask></defs>
        </svg>
        """)
        let mask = try #require(svg.defs.masks.first)
        #expect(DOM.presentationAttributes(for: mask, styles: svg.styles).opacity == 0.5)
        #expect(DOM.presentationAttributes(for: mask.childElements[0], styles: svg.styles).fill == .color(.keyword(.white)))
    }
}
