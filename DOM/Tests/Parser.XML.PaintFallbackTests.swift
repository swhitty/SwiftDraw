//
//  Parser.XML.ColorTests.swift
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

@testable import SwiftDrawDOM
import Foundation
import Testing

/// SVG 1.1 §11.2: `<funciri> [ none | currentColor | <color> ]`.
struct ParserPaintFallbackTests {

    @Test
    func urlAloneStillParses() throws {
        #expect(try XMLParser().parseFill("url(#g)") == .url(URL(string: "#g")!))
    }

    @Test
    func urlWithColorFallback() throws {
        #expect(try XMLParser().parseFill("url(#g) #000000") == .urlWithFallback(URL(string: "#g")!, .hex(0, 0, 0)))
        #expect(try XMLParser().parseFill("url(#g)  red") == .urlWithFallback(URL(string: "#g")!, .keyword(.red)))
        #expect(try XMLParser().parseFill("url(#g) currentColor") == .urlWithFallback(URL(string: "#g")!, .currentColor))
    }

    @Test
    func urlWithNoneFallback() throws {
        #expect(try XMLParser().parseFill("url(#g) none") == .urlWithFallback(URL(string: "#g")!, .none))
    }

    @Test
    func unreadableFallbackKeepsTheServer() throws {
        #expect(try XMLParser().parseFill("url(#g) nonsense") == .url(URL(string: "#g")!))
        #expect(try XMLParser().parseFill("url(#g) url(#h)") == .url(URL(string: "#g")!))
    }

    @Test
    func fallbackInStyleAttribute() throws {
        let svg = try DOM.SVG.parse(xml: #"<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><rect width="1" height="1" style="fill:url(#g) #ff0000" /></svg>"#)
        let element = try #require(svg.childElements.first)
        #expect(DOM.presentationAttributes(for: element, styles: svg.styles).fill == .urlWithFallback(URL(string: "#g")!, .hex(255, 0, 0)))
    }
}
