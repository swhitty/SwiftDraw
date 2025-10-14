//
//  Parser.XML.RadialGradientTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 13/8/22.
//  Copyright 2022 Simon Whitty
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

@Suite("Parser XML Radial Gradient Tests")
struct ParserXMLRadialGradientTests {

    @Test
    func parseGradients() throws {
        let child = XML.Element(name: "child")
        child.children = [XML.Element.makeMockGradient(), XML.Element.makeMockGradient()]

        let parent = XML.Element(name: "parent")
        parent.children = [XML.Element.makeMockGradient(), child]

        #expect(try XMLParser().parseRadialGradients(child).count == 2)
        #expect(try XMLParser().parseRadialGradients(parent).count == 3)
    }

    @Test
    func parseCoordinates() throws {
        let element = XML.Element.makeMockGradient()
        element.attributes["r"] = "0.1"
        element.attributes["cx"] = "0.2"
        element.attributes["cy"] = "0.3"
        element.attributes["fr"] = "0.4"
        element.attributes["fx"] = "0.5"
        element.attributes["fy"] = "0.6"

        let gradient = try XMLParser().parseRadialGradient(element)
        #expect(gradient.r == 0.1)
        #expect(gradient.cx == 0.2)
        #expect(gradient.cy == 0.3)
        #expect(gradient.fr == 0.4)
        #expect(gradient.fx == 0.5)
        #expect(gradient.fy == 0.6)
    }

    @Test
    func parseFile() throws {

        let dom = try DOM.SVG.parse(fileNamed: "radialGradient.svg", in: .test)

        #expect(dom.defs.radialGradients.count == 5)
        #expect(dom.defs.radialGradients.first(where: { $0.id == "snow" }) != nil)
        #expect(dom.defs.radialGradients.first(where: { $0.id == "blue" }) != nil)
        #expect(dom.defs.radialGradients.first(where: { $0.id == "purple" }) != nil)
        #expect(dom.defs.radialGradients.first(where: { $0.id == "salmon" }) != nil)
        #expect(dom.defs.radialGradients.first(where: { $0.id == "green" }) != nil)

        #expect(dom.childElements.count > 2)
        #expect(dom.childElements[0].attributes.fill == .url(URL(string: "#snow")!))
        #expect(dom.childElements[1].attributes.fill == .url(URL(string: "#blue")!))
    }
}

private extension XML.Element {

    static func makeMockGradient() -> XML.Element {
        return XML.Element(name: "radialGradient", attributes: ["id": "mock"])
    }
}
