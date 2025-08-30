//
//  ValueParserTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 6/3/17.
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

@Suite("Value Parser Tests")
struct ValueParserTests {

    var parser = XMLParser.ValueParser()

    @Test
    func float() throws {
        #expect(try parser.parseFloat("10") == 10)
        #expect(try parser.parseFloat("10.0") == 10.0)

        #expect(throws: (any Error).self) { _ = try parser.parseFloat("") }
        // #expect(throws: (any Error).self) { _ = try parser.parseFloat("10a") }
    }

    @Test
    func floats() throws {
        #expect(try parser.parseFloats("10 20 30.5") == [10, 20, 30.5])
        #expect(try parser.parseFloats("10.0") == [10.0])
        #expect(try parser.parseFloats("5 10 1 5") == [5, 10, 1, 5])
        #expect(try parser.parseFloats(" 1, 2.5, 3.5 ") == [1, 2.5, 3.5])
        #expect(try parser.parseFloats(" ") == [])
        #expect(try parser.parseFloats("") == [])

        // #expect(throws: (any Error).self) { _ = try parser.parseFloats("") }
        // #expect(throws: (any Error).self) { _ = try parser.parseFloat("10a") }
    }

    @Test
    func percentage() throws {
        #expect(try parser.parsePercentage("0") == 0)
        #expect(try parser.parsePercentage("1") == 1)
        #expect(try parser.parsePercentage("0.45") == 0.45)
        #expect(try parser.parsePercentage("0.0%") == 0)
        #expect(try parser.parsePercentage("100%") == 1)
        #expect(try parser.parsePercentage("55%") == 0.55)
        #expect(try parser.parsePercentage("10.25%") == 0.1025)

        #expect(throws: (any Error).self) { _ = try parser.parsePercentage("100") }
        #expect(throws: (any Error).self) { _ = try parser.parsePercentage("asd") }
        #expect(throws: (any Error).self) { _ = try parser.parsePercentage(" ") }
        // #expect(throws: (any Error).self) { _ = try parser.parseFloat("10a") }
    }

    @Test
    func coordinate() throws {
        #expect(try parser.parseCoordinate("0") == 0)
        #expect(try parser.parseCoordinate("0.0") == 0)
        #expect(try parser.parseCoordinate("100") == 100)
        #expect(try parser.parseCoordinate("25.0") == 25.0)
        #expect(try parser.parseCoordinate("-25.0") == -25.0)

        #expect(throws: (any Error).self) { _ = try parser.parseCoordinate("asd") }
        #expect(throws: (any Error).self) { _ = try parser.parseCoordinate(" ") }
    }

    @Test
    func length() throws {
        #expect(try parser.parseLength("0") == 0)
        #expect(try parser.parseLength("100") == 100)
        #expect(try parser.parseLength("25") == 25)
        #expect(try parser.parseLength("1.3") == 1) // should error?

        #expect(throws: (any Error).self) { _ = try parser.parseLength("asd") }
        #expect(throws: (any Error).self) { _ = try parser.parseLength(" ") }
        #expect(throws: (any Error).self) { _ = try parser.parseLength("-25") }
    }

    @Test
    func bools() throws {
        #expect(try parser.parseBool("false") == false)
        #expect(try parser.parseBool("FALSE") == false)
        #expect(try parser.parseBool("true") == true)
        #expect(try parser.parseBool("TRUE") == true)
        #expect(try parser.parseBool("1") == true)
        #expect(try parser.parseBool("0") == false)

        #expect(throws: (any Error).self) { _ = try parser.parseBool("asd") }
        #expect(throws: (any Error).self) { _ = try parser.parseBool("yes") }
    }

    @Test
    func fill() throws {
        #expect(try parser.parseFill("none") == .color(.none))
        #expect(try parser.parseFill("black") == .color(.keyword(.black)))
        #expect(try parser.parseFill("red") == .color(.keyword(.red)))

        #expect(try parser.parseFill("rgb(10,20,30)") == .color(.rgbi(10, 20, 30, 1.0)))
        #expect(try parser.parseFill("rgb(10%,20%,100%)") == .color(.rgbf(0.1, 0.2, 1.0, 1.0)))
        #expect(try parser.parseFill("rgba(10, 20, 30, 0.5)") == .color(.rgbi(10, 20, 30, 0.5)))
        #expect(try parser.parseFill("rgba(10%,20%,100%,0.6)") == .color(.rgbf(0.1, 0.2, 1.0, 0.6)))
        #expect(try parser.parseFill("#AAFF00") == .color(.hex(170, 255, 0)))

        #expect(try parser.parseFill("url(#test)") == .url(URL(string: "#test")!))

        #expect(throws: (any Error).self) { _ = try parser.parseFill("Ns ") }
        #expect(throws: (any Error).self) { _ = try parser.parseFill("d") }
        #expect(throws: (any Error).self) { _ = try parser.parseFill("url()") }
        // #expect(throws: (any Error).self) { _ = try parser.parseFill("url(asdf") }
    }

    @Test
    func url() throws {
        #if canImport(Darwin)
        #expect(try parser.parseUrl("#testing🐟").fragmentID == "testing🐟")
        #else
        #expect(try parser.parseUrl("#testing").fragmentID == "testing")
        #endif
        #expect(try parser.parseUrl("http://www.google.com").host == "www.google.com")
    }

    @Test
    func urlSelector() throws {
        #expect(try parser.parseUrlSelector("url(#testingId)").fragmentID == "testingId")
        #expect(try parser.parseUrlSelector("url(http://www.google.com)").host == "www.google.com")

        #expect(throws: (any Error).self) { _ = try parser.parseUrlSelector("url(#testingId) other") }
    }

    @Test
    func points() throws {
        #expect(try parser.parsePoints("0 1 2 3") == [DOM.Point(0, 1), DOM.Point(2, 3)])
        #expect(try parser.parsePoints("0,1 2,3") == [DOM.Point(0, 1), DOM.Point(2, 3)])
        #expect(try parser.parsePoints("0 1.5 1e4 2.4") == [DOM.Point(0, 1.5), DOM.Point(1e4, 2.4)])
        //  #expect(try parser.parsePoints("0 1 2 3 5.0 6.5") == [0, 1 ,2])
    }

    @Test
    func raw() throws {
        #expect(try parser.parseRaw("evenodd") as DOM.FillRule == .evenodd)
        #expect(try parser.parseRaw("round") as DOM.LineCap == .round)
        #expect(try parser.parseRaw("miter") as DOM.LineJoin == .miter)

        #expect(throws: (any Error).self) {
            let _: DOM.LineJoin = try parser.parseRaw("sd")
        }
    }
}
