//
//  Parser.InvalidElementTests.swift
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

// SD15: an invalid element is skipped, never the document
struct InvalidElementTests {

    private let bad = [
        #"<path fill="red"/>"#,                  // no d
        #"<rect height="5"/>"#,                  // no width
        #"<rect width="5" height="5" x=""/>"#,   // unparseable geometry
        #"<circle r="abc"/>"#,
        #"<polygon points="1,2,3"/>"#,
        #"<image width="5" height="5"/>"#,       // no href
        #"<line x1="a" y1="0" x2="1" y2="1"/>"#,
    ]

    private func parse(_ body: String, options: SwiftDrawDOM.XMLParser.Options = [.skipInvalidElements]) throws -> DOM.SVG {
        try DOM.SVG.parse(xml: #"<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">\#(body)</svg>"#,
                          options: options)
    }

    @Test
    func invalidElementKeepsSiblings() throws {
        for element in bad {
            let svg = try parse(#"<rect id="a" width="1" height="1"/>\#(element)<rect id="b" width="1" height="1"/>"#)
            #expect(svg.childElements.compactMap { $0.id } == ["a", "b"], "\(element)")
        }
    }

    @Test
    func invalidElementDropsItsSubtreeOnly() throws {
        let svg = try parse(#"<g id="g"><path/><rect id="r" width="1" height="1"/></g><rect id="after" width="1" height="1"/>"#)
        #expect(svg.childElements.count == 2)
        let group = try #require(svg.childElements.first as? DOM.Group)
        #expect(group.childElements.compactMap { $0.id } == ["r"])
    }

    @Test
    func invalidElementInsideDefsMaskAndClipKeepsDocument() throws {
        let svg = try parse(#"""
        <defs><clipPath id="c"><path/><rect width="1" height="1"/></clipPath></defs>
        <rect id="ok" width="1" height="1"/>
        """#)
        #expect(svg.childElements.compactMap { $0.id } == ["ok"])
        #expect(svg.defs.clipPaths.first?.childElements.count == 1)
    }

    @Test
    func badContainerKeepsValidChildrenOfSiblings() throws {
        let svg = try parse(#"<g id="a"><rect id="r1" width="1" height="1"/></g><svg width="abc"><rect id="gone" width="1" height="1"/></svg><g id="b"><rect id="r2" width="1" height="1"/></g>"#)
        #expect(svg.childElements.compactMap { $0.id } == ["a", "b"])
    }

    @Test
    func nestedGroupWithBadElement() throws {
        let svg = try parse(#"<g id="outer"><g id="inner"><path/><rect id="r" width="1" height="1"/></g></g>"#)
        let outer = try #require(svg.childElements.first as? DOM.Group)
        let inner = try #require(outer.childElements.first as? DOM.Group)
        #expect(inner.childElements.compactMap { $0.id } == ["r"])
    }

    @Test
    func defsChildWithoutIdIsSkipped() throws {
        let svg = try parse(#"<defs><path d="M0 0"/><rect id="ok" width="1" height="1"/></defs><rect id="r" width="1" height="1"/>"#)
        #expect(svg.childElements.compactMap { $0.id } == ["r"])
        #expect(Array(svg.defs.elements.keys) == ["ok"])
    }

    @Test
    func badChildrenInMaskAndPattern() throws {
        let svg = try parse(#"""
        <mask id="m"><path/><rect width="1" height="1"/></mask>
        <pattern id="p" width="2" height="2"><rect height="1"/><rect width="1" height="1"/></pattern>
        <rect id="r" width="1" height="1"/>
        """#)
        #expect(svg.childElements.compactMap { $0.id } == ["r"])
        #expect(svg.defs.masks.first?.childElements.count == 1)
        #expect(svg.defs.patterns.first?.childElements.count == 1)
    }

    @Test
    func badDefinitionsAreDroppedNotTheDocument() throws {
        let svg = try parse(#"""
        <clipPath><rect width="1" height="1"/></clipPath>
        <clipPath id="c" clipPathUnits="bogus"><rect width="1" height="1"/></clipPath>
        <mask><rect width="1" height="1"/></mask>
        <linearGradient><stop offset="0"/></linearGradient>
        <linearGradient id="lg" gradientUnits="bogus"/>
        <radialGradient/>
        <radialGradient id="rg"><stop offset="0" stop-opacity="abc"/></radialGradient>
        <filter/>
        <linearGradient id="good"><stop offset="0" stop-color="red"/></linearGradient>
        <rect id="r" width="1" height="1"/>
        """#)
        #expect(svg.childElements.compactMap { $0.id } == ["r"])
        // since SD8 a bad clipPathUnits drops only that attribute (userSpaceOnUse, as browsers do); the id-less one is skipped
        #expect(svg.defs.clipPaths.map { $0.id } == ["c"])
        #expect(svg.defs.clipPaths.first?.clipPathUnits == nil)
        #expect(svg.defs.masks.isEmpty)
        // since SD6 a bad stop-opacity drops only that attribute, so "rg" survives; the id-less one is skipped
        #expect(svg.defs.radialGradients.map { $0.id } == ["rg"])
        #expect(svg.defs.filters.isEmpty)
        #expect(svg.defs.linearGradients.map { $0.id } == ["good"])
    }

    @Test
    func anchorWithoutHrefIsAPlainGroup() throws {
        let svg = try parse(#"<a><rect id="r" width="1" height="1"/></a>"#)
        let anchor = try #require(svg.childElements.first as? DOM.Anchor)
        #expect(anchor.href == nil)
        #expect(anchor.childElements.compactMap { $0.id } == ["r"])
    }

    @Test
    func rootSvgProblemsStillThrow() {
        for root in [#"<svg xmlns="http://www.w3.org/2000/svg"></svg>"#,
                     #"<svg xmlns="http://www.w3.org/2000/svg" width="abc" height="10"></svg>"#] {
            #expect(throws: (any Error).self) {
                try DOM.SVG.parse(xml: root, options: [.skipInvalidElements])
            }
        }
    }

    @Test
    func nestedSvgSkipsBadElement() throws {
        let svg = try parse(#"<svg id="n" width="5" height="5"><path/><rect id="r" width="1" height="1"/></svg>"#)
        let nested = try #require(svg.childElements.first as? DOM.SVG)
        // (a nested svg lists its children twice on main as well; unrelated to this item)
        #expect(Set(nested.childElements.compactMap { $0.id }) == ["r"])
    }

    @Test
    func strictModeReportsInvalidElementWithLine() throws {
        let xml = """
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">
          <rect width="1" height="1"/>
          <path/>
        </svg>
        """
        do {
            _ = try DOM.SVG.parse(xml: xml, options: [])
            Issue.record("expected a throw")
        } catch let SwiftDrawDOM.XMLParser.Error.invalidElement(name, _, line, _) {
            #expect(name == "path")
            #expect(line == 3)
        }
    }

    @Test
    func strictModeStillThrows() {
        #expect(throws: (any Error).self) {
            try parse(#"<path/>"#, options: [])
        }
    }
}
