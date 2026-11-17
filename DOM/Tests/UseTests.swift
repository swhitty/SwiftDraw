//
//  UseTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 27/2/17.
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

@Suite("Use Tests")
struct UseTests {

    @Test
    func firstGraphicsElementSearchesPastContainers() throws {
        let svg = DOM.SVG(width: 100, height: 100)

        // Place a group (container) before the target element
        let group = DOM.Group()
        group.childElements = [DOM.Circle(cx: 0, cy: 0, r: 5)]

        let target = DOM.Rect(width: 10, height: 10)
        target.id = "target"

        svg.childElements = [group, target]

        // Should find "target" even though a container (group) comes first
        let found = svg.firstGraphicsElement(with: "target")
        #expect(found?.id == "target")
    }

    @Test
    func use() throws {
        let parsed = try XMLParser().parseUse(["href": "#line1"])
        #expect(parsed.href.fragmentID == "line1")
        #expect(parsed.x == nil)
        #expect(parsed.y == nil)

        let legacyParsed = try XMLParser().parseUse([
            "xlink:href": "#line2",
            "x": "20",
            "y": "30",
        ])
        #expect(legacyParsed.href.fragmentID == "line2")
        #expect(legacyParsed.x == 20)
        #expect(legacyParsed.y == 30)
    }

    @Test
    func usePrefersHrefWhenBothAttributesArePresent() throws {
        let parsed = try XMLParser().parseUse([
            "href": "#modern",
            "xlink:href": "#legacy",
        ])

        #expect(parsed.href.fragmentID == "modern")
    }

    @Test
    func useDoesNotFallbackToXLinkHrefWhenHrefIsInvalid() {
        #expect(throws: XMLParser.Error.self) {
            _ = try XMLParser().parseUse([
                "href": "https://[invalid",
                "xlink:href": "#legacy",
            ])
        }
    }
}
