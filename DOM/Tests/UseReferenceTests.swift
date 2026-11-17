//
//  UseReferenceTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 17/11/26.
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

import Testing
@testable import SwiftDrawDOM

/// The element a `<use>` references: the first in the document with the id, wherever it is
/// (as `getElementById` in Chrome, and resvg).
struct UseReferenceTests {

    private func parse(_ body: String) throws -> DOM.SVG {
        try DOM.SVG.parse(
            xml: """
                <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">\(body)</svg>
                """
        )
    }

    @Test(
        arguments: [
            // nested inside a group in <defs>
            #"<defs><g fill="red"><rect id="r" width="10" height="10"/></g></defs>"#,
            // inside an element that is not SVG
            #"<random><rect id="r" width="10" height="10"/></random>"#,
            #"<random><g><random><rect id="r" width="10" height="10"/></random></g></random>"#,
            // inside an element that is never rendered
            #"<clipPath id="c"><g><rect id="r" width="10" height="10"/></g></clipPath>"#,
            #"<linearGradient id="l"><rect id="r" width="10" height="10"/></linearGradient>"#,
            #"<mask id="m"><g><rect id="r" width="10" height="10"/></g></mask>"#,
            // the referencing <use> comes first
            ##"<use href="#r"/><g><g><rect id="r" width="10" height="10"/></g></g>"##,
        ] as [String]
    )
    func findsElementAnywhere(body: String) throws {
        let svg = try parse(body)
        #expect(svg.firstGraphicsElement(with: "r") is DOM.Rect)
    }

    @Test(
        arguments: [
            #"<defs><rect id="r" width="1" height="1"/><rect id="r" width="2" height="2"/></defs>"#,
            #"<rect id="r" width="1" height="1"/><defs><rect id="r" width="2" height="2"/></defs>"#,
            #"<defs><rect id="r" width="1" height="1"/></defs><rect id="r" width="2" height="2"/>"#,
            #"<random><rect id="r" width="1" height="1"/></random><rect id="r" width="2" height="2"/>"#,
        ] as [String]
    )
    func firstElementWithIDWins(body: String) throws {
        let svg = try parse(body)
        let rect = try #require(svg.firstGraphicsElement(with: "r") as? DOM.Rect)
        #expect(rect.width == 1)
    }

    @Test(
        arguments: [
            // the first element with the id is not a graphics element
            (#"<linearGradient id="r"/><rect id="r" width="10" height="10"/>"#, "r"),
            // the root <svg> itself
            (#"<rect id="svg1" width="10" height="10"/>"#, "svg1"),
            (#"<rect id="r" width="10" height="10"/>"#, "missing"),
        ] as [(String, String)]
    )
    func referencesNothing(body: String, id: String) throws {
        let svg = try DOM.SVG.parse(
            xml: """
                <svg id="svg1" xmlns="http://www.w3.org/2000/svg" width="100" height="100">\(body)</svg>
                """
        )
        #expect(svg.firstGraphicsElement(with: id) == nil)
    }

    @Test
    func duplicateIDsInDefsKeepTheFirst() throws {
        let svg = try parse(#"<defs><rect id="r" width="1" height="1"/><rect id="r" width="2" height="2"/></defs>"#)
        #expect((svg.defs.elements["r"] as? DOM.Rect)?.width == 1)
    }
}
