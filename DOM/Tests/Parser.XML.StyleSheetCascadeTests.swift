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
import Foundation
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

    // MARK: - Second review

    private func cascaded(_ id: String, style: String, body: String) throws -> DOM.PresentationAttributes {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">
        <style>\(style)</style>
        \(body)
        </svg>
        """)
        let element = try #require(Self.find(id, in: svg.childElements))
        return DOM.presentationAttributes(for: element, styles: svg.styles)
    }

    @Test
    func mediaBlocksAreSkippedInADocument() throws {
        let body = #"<rect id="r" class="a" width="1" height="1"/>"#
        #expect(try fill(of: "r", style: "@media (min-width: 1px) { .a { fill: red } } .a { stroke: blue }", body: body) == nil)
        #expect(try cascaded("r", style: "@media print { .a { fill: red } } .a { stroke: blue }", body: body).stroke == .color(.keyword(.blue)))
    }

    @Test
    func unterminatedStringEndsAtTheNewline() throws {
        let sheet = try XMLParser().parseStyleSheetElement(
            """
            .a { font-family: "Foo
            ; fill: red }
            .b { fill: blue }
            """
        )
        #expect(sheet.attributes[.class("a")]?.fill == .color(.keyword(.red)))
        #expect(sheet.attributes[.class("a")]?.fontFamily == nil)
        #expect(sheet.attributes[.class("b")]?.fill == .color(.keyword(.blue)))
    }

    @Test
    func unterminatedStringInAPrelude() throws {
        let sheet = try XMLParser().parseStyleSheetElement(
            """
            [title="x
            ] { fill: red }
            .b { fill: blue }
            """
        )
        #expect(sheet.attributes[.class("b")]?.fill == .color(.keyword(.blue)))
    }

    @Test
    func unclosedParenStopsAtTheBlock() throws {
        let sheet = try XMLParser().parseStyleSheetElement(
            """
            .a:not( { fill: red }
            .b { fill: blue; stroke: rgb(1, 2 }
            .c { fill: green }
            """
        )
        #expect(sheet.attributes[.class("a")] == nil)
        #expect(sheet.attributes[.class("b")]?.fill == .color(.keyword(.blue)))
        #expect(sheet.attributes[.class("c")]?.fill == .color(.keyword(.green)))
    }

    @Test
    func escapedBackslashInAPrelude() throws {
        let sheet = try XMLParser().parseStyleSheetElement(#"[data-x="a\"b"] { fill: red } .b { fill: blue }"#)
        #expect(sheet.rules.first?.selector.compounds[0].attributes[0].value == #"a"b"#)
        #expect(sheet.attributes[.class("b")]?.fill == .color(.keyword(.blue)))
    }

    @Test
    func inlineImportantBeatsAuthorImportant() throws {
        let body = #"<rect id="r" class="a" style="fill: red !important" width="1" height="1"/>"#
        #expect(try fill(of: "r", style: "rect.a { fill: blue !important }", body: body) == .color(.keyword(.red)))
        let plain = #"<rect id="r" class="a" style="fill: red" width="1" height="1"/>"#
        #expect(try fill(of: "r", style: "rect.a { fill: blue !important }", body: plain) == .color(.keyword(.blue)))
    }

    @Test
    func importantBeatsHigherSpecificity() throws {
        let body = #"<g id="g"><rect id="r" class="a" width="1" height="1"/></g>"#
        #expect(try fill(of: "r", style: "rect { fill: red !important } #g > #r.a { fill: blue }", body: body) == .color(.keyword(.red)))
    }

    @Test
    func commaListMembersKeepTheirOwnSpecificity() throws {
        let style = "#r, circle { fill: red } .a { fill: blue }"
        let body = #"<rect id="r" class="a" width="1" height="1"/><circle id="c" class="a" r="1"/>"#
        #expect(try fill(of: "r", style: style, body: body) == .color(.keyword(.red)))
        #expect(try fill(of: "c", style: style, body: body) == .color(.keyword(.blue)))
    }

    @Test
    func fallbackDeclarationsKeepTheLastValidValue() throws {
        let body = #"<rect id="r" class="a" width="1" height="1"/>"#
        #expect(try fill(of: "r", style: ".a { fill: #f00; fill: color(rec2020 1 0 0) }", body: body) == .color(.hex(255, 0, 0)))
        #expect(try fill(of: "r", style: ".a { fill: #f00; fill: color(display-p3 1 0 0) }", body: body) == .color(.p3(1, 0, 0)))
        #expect(try fill(of: "r", style: ".a { fill: red; fill: var(--x) }", body: body) == .color(.keyword(.red)))
        let inline = #"<rect id="r" style="fill: red; fill: var(--x)" width="1" height="1"/>"#
        #expect(try fill(of: "r", style: "", body: inline) == .color(.keyword(.red)))
    }

    @Test
    func noneOverridesALowerRule() throws {
        let style = """
        rect { clip-path: url(#c); mask: url(#m); filter: url(#f); transform: scale(2) }
        #r { clip-path: none; mask: none; filter: none; transform: none }
        """
        let att = try cascaded("r", style: style, body: #"<rect id="r" width="1" height="1"/>"#)
        #expect(att.clipPath == DOM.noneURL)
        #expect(att.mask == DOM.noneURL)
        #expect(att.filter == DOM.noneURL)
        #expect(att.transform == [])
    }

    @Test
    func rootInlineStyleBeatsStyleSheet() throws {
        for selector in ["svg", ":root", "*"] {
            let svg = try DOM.SVG.parse(xml: """
            <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10" fill="green" style="fill: red">
            <style>\(selector) { fill: blue; stroke: blue }</style>
            </svg>
            """)
            let att = DOM.presentationAttributes(for: svg, styles: svg.styles)
            #expect(att.fill == .color(.keyword(.red)))
            #expect(att.stroke == .color(.keyword(.blue)))
        }
    }

    @Test
    func stopPropertiesFromTheCascade() throws {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">
        <style>.st0 { stop-color: #00ff00; stop-opacity: 0.5 } .st1 { stop-color: red }</style>
        <linearGradient id="g">
          <stop offset="0" class="st0"/>
          <stop offset="1" class="st1" style="stop-color: blue" stop-opacity="0.25"/>
        </linearGradient>
        <radialGradient id="r"><stop offset="0" class="st0"/></radialGradient>
        </svg>
        """)
        let stops = try #require(svg.defs.linearGradients.first).stops
        #expect(stops[0].color == .hex(0, 255, 0))
        #expect(stops[0].opacity == 0.5)
        #expect(stops[1].color == .keyword(.blue))
        #expect(stops[1].opacity == 0.25)
        #expect(try #require(svg.defs.radialGradients.first).stops[0].color == .hex(0, 255, 0))
    }

    @Test
    func manyRulesOnALargeDocumentStayFast() throws {
        let rules = (0..<300).map { ".c\($0) { fill: #\(String(format: "%06x", $0)) }" }.joined(separator: "\n")
        let elements = (0..<5000).map { #"<rect class="x c\#($0 % 300)" width="1" height="1"/>"# }.joined()
        let siblings = "g > rect ~ rect + rect { stroke: red } svg rect:last-child { stroke-width: 2 }"
        let start = Date()
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">
        <style>\(rules) \(siblings)</style><g>\(elements)</g>
        </svg>
        """)
        let elapsed = Date().timeIntervalSince(start)
        let group = try #require(svg.childElements.first as? DOM.Group)
        #expect(group.childElements.count == 5000)
        let last = DOM.presentationAttributes(for: group.childElements[4999], styles: svg.styles)
        #expect(last.fill == .color(.hex(0, 0, 199)))
        #expect(last.stroke == .color(.keyword(.red)))
        #expect(last.strokeWidth == 2)
        #expect(DOM.presentationAttributes(for: group.childElements[0], styles: svg.styles).stroke == nil)
        // generous bound for debug builds on CI; the quadratic matcher took far longer
        #expect(elapsed < 20)
    }

    // MARK: - Third review

    @Test
    func sfSymbolLayerClassesKeepTheirAnnotation() throws {
        let s = try #require(Selector.parse(".multicolor-0:systemYellowColor"))
        #expect(s.compounds[0].classes == ["multicolor-0:systemYellowColor"])
        #expect(s.compounds[0].pseudoClasses.isEmpty)
        #expect(s.simple == .class("multicolor-0:systemYellowColor"))
        #expect(try #require(Selector.parse(".hierarchical-0:secondary")).simple == .class("hierarchical-0:secondary"))
        #expect(try #require(Selector.parse(".monochrome-1:primary")).simple == .class("monochrome-1:primary"))
        // other classes still take a pseudo-class
        #expect(try #require(Selector.parse(".a:first-child")).compounds[0].pseudoClasses == [.firstChild])

        let body = #"<rect id="r" class="hierarchical-0:secondary" width="1" height="1"/>"#
        #expect(try fill(of: "r", style: ".hierarchical-0:secondary { fill: red }", body: body) == .color(.keyword(.red)))
    }

    @Test
    func cssWideKeywordsAreDropped() throws {
        let body = #"<text id="t" class="a" x="0" y="0">t</text>"#
        let att = try cascaded("t", style: "text { font-family: Helvetica; fill: red } .a { font-family: inherit; fill: unset }", body: body)
        #expect(att.fontFamily == [.name("Helvetica")])
        #expect(att.fill == .color(.keyword(.red)))
        let inline = #"<text id="t" style="fill: initial" x="0" y="0">t</text>"#
        #expect(try cascaded("t", style: "text { fill: red }", body: inline).fill == .color(.keyword(.red)))
    }

    @Test
    func quoteOpenAtEndOfValueIsKept() throws {
        let decls = XMLParser.parseCSSDeclarations("font-family:'Foo")
        #expect(decls.count == 1)
        #expect(decls.first?.value == "'Foo")
    }

    @Test
    func escapedBraceOutsideAString() throws {
        let sheet = try XMLParser().parseStyleSheetElement(#".a\{b { fill: red } .c { fill: blue }"#)
        #expect(sheet.attributes[.class("a{b")]?.fill == .color(.keyword(.red)))
        #expect(sheet.attributes[.class("c")]?.fill == .color(.keyword(.blue)))
    }

    private func matcher(style: String, body: String) throws -> (DOM.StyleSheet.Matcher, XML.Element) {
        let root = try XML.SAXParser.parse(data: Data("""
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">\(body)</svg>
        """.utf8))
        let sheet = try XMLParser().parseStyleSheetElement(style)
        return (DOM.StyleSheet.Matcher(sheets: [sheet], root: root), root)
    }

    private func allElements(_ root: XML.Element) -> [XML.Element] {
        var result = [XML.Element]()
        var stack = [root]
        while let e = stack.popLast() {
            result.append(e)
            stack.append(contentsOf: e.children)
        }
        return result
    }

    @Test
    func classRulesUseTheIndex() throws {
        let rules = (0..<300).map { ".c\($0) { fill: red }" }.joined(separator: " ")
        let body = (0..<5000).map { #"<rect class="c\#($0 % 300)"/>"# }.joined()
        let (m, root) = try matcher(style: rules, body: body)
        let elements = allElements(root)
        for e in elements { _ = m.match(e) }
        // one candidate rule per rect; scanning every rule would be 300 × 5,000
        #expect(m.evaluations <= elements.count)
    }

    @Test
    func failingSiblingWalkIsLinear() throws {
        let body = "<g>" + String(repeating: #"<rect/>"#, count: 5000) + "</g>"
        let (m, root) = try matcher(style: "g > circle ~ rect { fill: red }", body: body)
        let elements = allElements(root)
        for e in elements {
            #expect(m.match(e)?.attributes.fill == nil)
        }
        // without the memo every rect walks back over all its previous siblings (~12.5 M)
        #expect(m.evaluations < 3 * elements.count)
    }

    @Test
    func failingAncestorWalkIsLinear() throws {
        let open = String(repeating: "<g><rect/>", count: 500)
        let close = String(repeating: "</g>", count: 500)
        let (m, root) = try matcher(style: "circle rect { fill: red }", body: open + close)
        let elements = allElements(root)
        for e in elements {
            #expect(m.match(e)?.attributes.fill == nil)
        }
        // without the memo every rect walks up all its ancestors (~125 k)
        #expect(m.evaluations < 3 * elements.count)
    }
}
