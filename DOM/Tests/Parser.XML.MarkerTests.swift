//
//  Parser.XML.MarkerTests.swift
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

struct ParserXMLMarkerTests {

    private func parse(_ body: String) throws -> DOM.SVG {
        try DOM.SVG.parse(
            xml: """
                <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">\(body)</svg>
                """
        )
    }

    @Test
    func markerAttributes() throws {
        let svg = try parse(
            """
            <defs>
              <marker id="m" markerWidth="6" markerHeight="8" refX="1" refY="2" orient="auto"
                      markerUnits="userSpaceOnUse" viewBox="0 0 10 20" preserveAspectRatio="xMinYMax slice">
                <path d="M 0 0 L 10 5 Z"/>
                <circle r="2"/>
              </marker>
            </defs>
            """
        )

        let marker = try #require(svg.defs.markers.first)
        #expect(svg.defs.markers.count == 1)
        #expect(marker.id == "m")
        #expect(marker.markerWidth == 6)
        #expect(marker.markerHeight == 8)
        #expect(marker.refX == 1)
        #expect(marker.refY == 2)
        #expect(marker.orient == .auto)
        #expect(marker.markerUnits == .userSpaceOnUse)
        #expect(marker.viewBox == DOM.SVG.ViewBox(x: 0, y: 0, width: 10, height: 20))
        #expect(marker.preserveAspectRatio == DOM.PreserveAspectRatio(align: .xMinYMax, meetOrSlice: .slice))
        #expect(marker.childElements.count == 2)
        // markers are only drawn where referenced, never as part of the document
        #expect(svg.childElements.allSatisfy { !($0 is DOM.Marker) })
    }

    @Test
    func missingOrInvalidAttributesUseTheDefaults() throws {
        let svg = try parse(
            """
            <marker id="m" markerWidth="wide" markerUnits="pixels" orient="sideways" viewBox="0 0"/>
            <marker/>
            """
        )

        let marker = try #require(svg.defs.markers.first)
        #expect(svg.defs.markers.count == 1)
        #expect(marker.markerWidth == nil)
        #expect(marker.markerHeight == nil)
        #expect(marker.refX == nil)
        #expect(marker.markerUnits == nil)
        #expect(marker.orient == nil)
        #expect(marker.viewBox == nil)
    }

    @Test
    func markersAnywhereInTheDocument() throws {
        let svg = try parse(
            """
            <marker id="a"/>
            <g><defs><marker id="b"/></defs></g>
            """
        )
        #expect(svg.defs.markers.map(\.id) == ["a", "b"])
    }

    static let orients: [(text: String, orient: DOM.Marker.Orient)] = [
        ("auto", .auto),
        ("auto-start-reverse", .autoStartReverse),
        ("45", .angle(45)),
        (" -30 ", .angle(-30)),
        ("45deg", .angle(45)),
        ("100grad", .angle(90)),
        ("0.5turn", .angle(180)),
    ]

    @Test(arguments: orients)
    func orient(text: String, orient: DOM.Marker.Orient) {
        #expect(XMLParser.parseMarkerOrient(text) == orient)
    }

    @Test
    func orientInRadians() throws {
        guard case let .angle(degrees) = try #require(XMLParser.parseMarkerOrient("1rad")) else {
            Issue.record("not an angle")
            return
        }
        #expect(abs(degrees - 57.29578) < 0.001)
    }

    @Test(arguments: ["", "Auto", "sideways", "45px", "deg", "nan"])
    func invalidOrient(text: String) {
        #expect(XMLParser.parseMarkerOrient(text) == nil)
    }

    @Test
    func markerProperties() throws {
        let att = try XMLParser().parsePresentationAttributes([
            "marker-start": "url(#a)",
            "marker-mid": "url(#b)",
            "marker-end": "none",
            "overflow": "visible",
        ])
        #expect(att.markerStart?.fragmentID == "a")
        #expect(att.markerMid?.fragmentID == "b")
        #expect(att.markerEnd == DOM.noneURL)
        #expect(att.overflow == .visible)
    }

    @Test
    func markerShorthandIsNotAPresentationAttribute() throws {
        let att = try XMLParser().parsePresentationAttributes(["marker": "url(#a)"])
        #expect(att.markerStart == nil)
        #expect(att.markerMid == nil)
        #expect(att.markerEnd == nil)
    }

    @Test
    func markerShorthandInStyle() throws {
        let svg = try parse(
            """
            <path d="M 0 0 L 10 10" style="marker: url(#a); marker-end: url(#b)"/>
            <path d="M 0 0 L 10 10" style="marker-end: url(#b); marker: url(#a)"/>
            """
        )
        let first = DOM.presentationAttributes(for: svg.childElements[0], styles: svg.styles)
        #expect(first.markerStart?.fragmentID == "a")
        #expect(first.markerMid?.fragmentID == "a")
        #expect(first.markerEnd?.fragmentID == "b")

        // a later shorthand overrides an earlier longhand
        let second = DOM.presentationAttributes(for: svg.childElements[1], styles: svg.styles)
        #expect(second.markerEnd?.fragmentID == "a")
    }

    @Test
    func markerShorthandInStyleSheet() throws {
        let svg = try parse(
            """
            <style>
              .series { marker: url(#dot) }
              .series.last { marker-start: none }
              marker { overflow: visible }
            </style>
            <marker id="dot"/>
            <polyline class="series last" points="0,0 10,10 20,0"/>
            """
        )
        let att = DOM.presentationAttributes(for: svg.childElements[0], styles: svg.styles)
        #expect(att.markerStart == DOM.noneURL)
        #expect(att.markerMid?.fragmentID == "dot")
        #expect(att.markerEnd?.fragmentID == "dot")

        let marker = try #require(svg.defs.markers.first)
        #expect(DOM.presentationAttributes(for: marker, styles: svg.styles).overflow == .visible)
    }
}
