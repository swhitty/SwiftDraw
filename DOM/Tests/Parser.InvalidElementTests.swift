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

    private func parse(_ body: String, options: XMLParser.Options = [.skipInvalidElements]) throws -> DOM.SVG {
        try DOM.SVG.parse(xml: #"<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">\#(body)</svg>"#,
                          options: options)
    }

    @Test
    func invalidElementKeepsSiblings() throws {
        for element in bad {
            let svg = try parse(#"<rect id="a" width="1" height="1"/>\#(element)<rect id="b" width="1" height="1"/>"#)
            #expect(svg.childElements.compactMap(\.id) == ["a", "b"], "\(element)")
        }
    }

    @Test
    func invalidElementDropsItsSubtreeOnly() throws {
        let svg = try parse(#"<g id="g"><path/><rect id="r" width="1" height="1"/></g><rect id="after" width="1" height="1"/>"#)
        #expect(svg.childElements.count == 2)
        let group = try #require(svg.childElements.first as? DOM.Group)
        #expect(group.childElements.compactMap(\.id) == ["r"])
    }

    @Test
    func invalidElementInsideDefsMaskAndClipKeepsDocument() throws {
        let svg = try parse(#"""
        <defs><clipPath id="c"><path/><rect width="1" height="1"/></clipPath></defs>
        <rect id="ok" width="1" height="1"/>
        """#)
        #expect(svg.childElements.compactMap(\.id) == ["ok"])
        #expect(svg.defs.clipPaths.first?.childElements.count == 1)
    }

    @Test
    func strictModeStillThrows() {
        #expect(throws: (any Error).self) {
            try parse(#"<path/>"#, options: [])
        }
    }
}
