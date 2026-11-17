//
//  Parser.FontFaceInvalidTests.swift
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

@testable import SwiftDrawDOM
import Foundation
import Testing

struct ParserFontFaceInvalidTests {

    static let invalidFaces = [
        "@font-face { font-family: 'NoSource'; }",
        "@font-face { src: local('Helvetica'); }",
        "@font-face { font-family: 'Unusable'; src: bogus(x); }",
        "@font-face { this is not a descriptor }",
        "@font-face { font-family 'Garbled' src local('Helvetica') }",
        "@font-face junk { font-family: 'Prelude'; src: local('Helvetica'); }",
    ]

    private static func sheet(around invalidFace: String) -> String {
        """
        .a { fill: red; }
        @font-face { font-family: 'First'; src: local('Helvetica'); }
        \(invalidFace)
        .b { fill: blue; }
        @font-face { font-family: 'Last'; src: local('Helvetica-Bold'); }
        rect { stroke: green; }
        """
    }

    @Test(arguments: invalidFaces)
    func invalidFaceIsSkipped(face: String) throws {
        let sheet = try XMLParser(options: .skipInvalidElements).parseStyleSheetElement(Self.sheet(around: face))

        #expect(sheet.fonts.map(\.family) == ["First", "Last"])
        #expect(sheet.attributes[.class("a")]?.fill == .color(.keyword(.red)))
        #expect(sheet.attributes[.class("b")]?.fill == .color(.keyword(.blue)))
        #expect(sheet.attributes[.element("rect")]?.stroke == .color(.keyword(.green)))
    }

    @Test(arguments: invalidFaces)
    func invalidFaceKeepsDocumentStyles(face: String) throws {
        let svg = try DOM.SVG.parse(
            data: Data(
                """
                <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">
                  <style>\(Self.sheet(around: face))</style>
                  <rect class="a" width="10" height="10" />
                </svg>
                """.utf8
            )
        )

        let sheet = try #require(svg.styles.first)
        #expect(sheet.fonts.map(\.family) == ["First", "Last"])
        #expect(sheet.attributes.keys.count == 3)
    }

    @Test(arguments: invalidFaces)
    func invalidFaceThrowsWithoutSkipInvalidElements(face: String) {
        #expect(throws: XMLParser.InvalidFontFace.self) {
            try XMLParser().parseStyleSheetElement(Self.sheet(around: face))
        }
    }

    @Test
    func unclosedFaceRunsToEnd() throws {
        let sheet = try XMLParser(options: .skipInvalidElements).parseStyleSheetElement(
            ".a { fill: red; } @font-face { font-family: 'Open'; src: local('Helvetica');"
        )
        #expect(sheet.fonts.map(\.family) == ["Open"])
        #expect(sheet.attributes.keys.count == 1)
    }

    @Test
    func invalidFaceIsReported() {
        let error = XMLParser.InvalidFontFace(error: XMLParser.Error.missingAttribute(name: "src"))
        #expect(
            XMLParser.makeParsingErrorMessage(for: error, filename: "a.svg")
                == #"[parsing error] a.svg  error: invalid @font-face: missingAttribute(name: "src")"#
        )
    }
}
