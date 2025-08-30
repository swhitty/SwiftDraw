//
//  XML.SAXParserTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 16/11/18.
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

import Foundation
import Testing
@testable import SwiftDrawDOM

@Suite("SAX Parser Tests")
struct SAXParserTests {

    @Test
    func missingFileThrows() {
        let missingFile = URL(fileURLWithPath: "/user/tmp/SWIFTDraw/SwiftDraw/missing")
        #expect(throws: (any Error).self) {
            _ = try XML.SAXParser.parse(contentsOf: missingFile)
        }
    }

    @Test
    func invalidXMLThrows() {
        let xml = "hi"
        #expect(throws: (any Error).self) {
            _ = try XML.SAXParser.parse(data: xml.data(using: .utf8)!)
        }
    }

    @Test
    func validSVGParses() throws {
        let xml = """
        <svg xmlns="http://www.w3.org/2000/svg">
        </svg>
        """

        let root = try XML.SAXParser.parse(data: xml.data(using: .utf8)!)
        #expect(root.name == "svg")
        #expect(root.children.isEmpty)
    }

    #if canImport(Darwin)
    @Test
    func unexpectedElementsThrows() {
        let xml = """
        <svg xmlns="http://www.w3.org/2000/svg">
            </b>
        </svg>
        """

        #expect(throws: (any Error).self) {
            _ = try XML.SAXParser.parse(data: xml.data(using: .utf8)!)
        }
    }
    #endif

    @Test
    func unexpectedNamespaceElementsSkipped() throws {
        let xml = """
        <svg xmlns="http://www.w3.org/2000/svg">
        <a xmlns="http://another.com" />
        <b />
        </svg>
        """
        let root = try XML.SAXParser.parse(data: xml.data(using: .utf8)!)
        #expect(root.name == "svg")
        #expect(root.children.count == 1)
        #expect(root.children[0].name == "b")
    }
}
