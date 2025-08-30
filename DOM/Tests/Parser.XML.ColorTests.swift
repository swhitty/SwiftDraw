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
import Testing

struct ParserColorTests {

    @Test
    func colorNone() throws {
        #expect(try XMLParser().parseColor("none") == .none)
        #expect(try XMLParser().parseColor(" none") == .none)
        #expect(try XMLParser().parseColor("\t none \t") == .none)
    }

    @Test
    func colorTransparent() throws {
        #expect(try XMLParser().parseColor("transparent") == .none)
        #expect(try XMLParser().parseColor(" transparent") == .none)
        #expect(try XMLParser().parseColor("\t transparent \t") == .none)
    }

    @Test
    func colorCurrent() throws {
        #expect(try XMLParser().parseColor("currentColor") == .currentColor)
        #expect(try XMLParser().parseColor(" currentColor") == .currentColor)
        #expect(try XMLParser().parseColor("\t currentColor \t") == .currentColor)
    }

    @Test
    func colorKeyword() throws {
        #expect(try XMLParser().parseColor("aliceblue") == .keyword(.aliceblue))
        #expect(try XMLParser().parseColor("wheat") == .keyword(.wheat))
        #expect(try XMLParser().parseColor("cornflowerblue") == .keyword(.cornflowerblue))
        #expect(try XMLParser().parseColor(" magenta") == .keyword(.magenta))
        #expect(try XMLParser().parseColor("black ") == .keyword(.black))
        #expect(try XMLParser().parseColor("\t red  \t") == .keyword(.red))
    }

    @Test
    func colorRGBi() throws {
        // integer 0-255
        #expect(try XMLParser().parseColor("rgb(0,1,2)") == .rgbi(0, 1, 2, 1.0))
        #expect(try XMLParser().parseColor(" rgb( 0 , 1 , 2) ") == .rgbi(0, 1, 2, 1.0))
        #expect(try XMLParser().parseColor("rgb(255,100,78)") == .rgbi(255, 100, 78, 1.0))

        #expect(try XMLParser().parseColor("rgb(0,1,2,255)") == .rgbi(0, 1, 2, 1.0))
        #expect(try XMLParser().parseColor("rgb(0,1,2,25%)") == .rgbi(0, 1, 2, 0.25))
        #expect(try XMLParser().parseColor(" rgb( 0 , 1 , 2, 0.5) ") == .rgbi(0, 1, 2, 0.5))
        #expect(try XMLParser().parseColor("rgb(255,100, 78, 0)") == .rgbi(255, 100, 78, 0))
    }

    @Test
    func colorRGBf() throws {
        // percentage 0-100%
        #expect(try XMLParser().parseColor("rgb(0,1%,99%)") == .rgbf(0.0, 0.01, 0.99, 1.0))
        #expect(try XMLParser().parseColor("rgb( 0%, 52% , 100%) ") == .rgbf(0.0, 0.52, 1.0, 1.0))
        #expect(try XMLParser().parseColor("rgb(75%,25%,7%)") == .rgbf(0.75, 0.25, 0.07, 1.0))
    }

    @Test
    func colorRGBA() throws {
        // integer 0-255
        #expect(try XMLParser().parseColor("rgba(0,1,2,0.5)") == .rgbi(0, 1, 2, 0.5))
        #expect(try XMLParser().parseColor(" rgba( 0 , 1 , 2, 0.6) ") == .rgbi(0, 1, 2, 0.6))
        #expect(try XMLParser().parseColor("rgba(255,100,78,0.7)") == .rgbi(255, 100, 78, 0.7))
        // percentage 0-100%
        #expect(try XMLParser().parseColor("rgba(0,1%,99%,0.5)") == .rgbf(0.0, 0.01, 0.99, 0.5))
        #expect(try XMLParser().parseColor("rgba( 0%, 52% , 100%, 0.6) ") == .rgbf(0.0, 0.52, 1.0, 0.6))
        #expect(try XMLParser().parseColor("rgba(75%,25%,7%,0.7)") == .rgbf(0.75, 0.25, 0.07, 0.7))
    }

    @Test
    func colorHex() throws {
        #expect(try XMLParser().parseColor("#a06") == .hex(170, 0, 102))
        #expect(try XMLParser().parseColor("#123456") == .hex(18, 52, 86))
        #expect(try XMLParser().parseColor("#FF11DD") == .hex(255, 17, 221))
        #expect(throws: (any Error).self) {
            try XMLParser().parseColor("#invalid")
        }
    }

    @Test
    func colorP3() throws {
        // percentage 0-100%
        #expect(try XMLParser().parseColor("color(display-p3 0 0.5 0.9)") == .p3(0, 0.5, 0.9))
        #expect(try XMLParser().parseColor("color(display-p3 0.1, 0.2, 0)") == .p3(0.1, 0.2, 0))
        #expect(try XMLParser().parseColor("color(display-p3 1,0.3,0.5)") == .p3(1, 0.3, 0.5))
    }
}

private extension DOMXMLParser {
    func parseColor(_ value: String) throws -> DOM.Color {
        return try parseFill(value).getColor()
    }
}
