//
//  Parser.XML.TextTests
//  SwiftDraw
//
//  Created by Simon Whitty on 31/12/16.
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


import Testing
@testable import SwiftDrawDOM

@Suite("Parser XML Text Tests")
struct ParserXMLTextTests {

    @Test
    func textNodeParses() throws {
        let el = XML.Element(name: "text", attributes: [:])
        el.innerText = "Simon"
        el.attributes["x"] = "1"
        el.attributes["y"] = "2"
        el.attributes["font-family"] = "Futura"
        el.attributes["font-size"] = "12.5"
        el.attributes["text-anchor"] = "end"

        let parsed = try XMLParser().parseGraphicsElement(el) as? DOM.Text
        let text = try #require(parsed)

        #expect(text.x == 1)
        #expect(text.y == 2)
        #expect(text.value == "Simon")
        #expect(text.attributes.fontFamily == "Futura")
        #expect(text.attributes.fontSize == 12.5)
        #expect(text.attributes.textAnchor == .end)
    }

    @Test
    func emptyTextNodeReturnsNil() throws {
        let el = XML.Element(name: "text", attributes: [:])
        let first = try XMLParser().parseText(["x": "1", "y": "1"], element: el)
        #expect(first == nil)

        el.innerText = "    "
        let second = try XMLParser().parseText(["x": "1", "y": "1"], element: el)
        #expect(second == nil)
    }
}
