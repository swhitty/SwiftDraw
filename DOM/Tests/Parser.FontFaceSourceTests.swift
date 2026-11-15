//
//  Parser.FontFaceSourceTests.swift
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

struct ParserFontFaceSourceTests {

    private func sources(_ src: String) throws -> [DOM.FontFace.Source] {
        try XMLParser().parseFontFace(["font-family": "A", "src": src]).src
    }

    @Test
    func splitsAtTopLevelCommasOnly() {
        #expect(XMLParser.splitFontSources(#"local("A, B"), url(data:font/woff2;base64,AA==) format('woff2'), local(C)"#) == [
            #"local("A, B")"#, "url(data:font/woff2;base64,AA==) format('woff2')", "local(C)"
        ])
        #expect(XMLParser.splitFontSources(" , ,") == [])
    }

    @Test(arguments: ["local('Helvetica Bold')", #"local("Helvetica Bold")"#, "local(Helvetica Bold)", "  local( 'Helvetica Bold' )  "])
    func parsesLocal(src: String) throws {
        #expect(try sources(src) == [.local("Helvetica Bold")])
    }

    @Test
    func parsesLocalThenURL() throws {
        let url = try #require(DOM.URL(string: "a.woff2"))
        #expect(try sources("local('A-Bold'), url(a.woff2) format('woff2')") == [.local("A-Bold"), .url(url: url, format: "woff2")])
    }

    @Test
    func keepsDataURLWithCommas() throws {
        let parsed = try sources("local(X), url(data:font/truetype;base64,ZXZlcnkgZ3JhaW4=) format('truetype')")
        #expect(parsed.count == 2)
        guard case let .url(url, format)? = parsed.last else {
            Issue.record("expected a url source")
            return
        }
        #expect(url.isDataURL)
        #expect(format == "truetype")
    }

    @Test
    func skipsUnreadableEntries() throws {
        #expect(try sources("bogus(x), local(), local(B)") == [.local("B")])
    }

    @Test
    func noUsableSourceIsInvalid() {
        #expect(throws: (any Error).self) { try sources("bogus(x), local()") }
    }

    @Test
    func stylesheetWithLocalParses() throws {
        let svg = try DOM.SVG.parse(xml: #"""
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><style>
          @font-face { font-family: 'A'; src: local('Helvetica-Bold'), url(a.woff2) format('woff2'); }
          .x { fill: red }
        </style><rect class="x" width="1" height="1"/></svg>
        """#)
        #expect(svg.styles.flatMap(\.fonts).map(\.src.count) == [2])
        #expect(svg.childElements.first.map { DOM.presentationAttributes(for: $0, styles: svg.styles).fill } == .color(.keyword(.red)))
    }
}
