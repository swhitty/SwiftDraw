//
//  Parser.ImageTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 28/1/17.
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
import Foundation

@Suite("Parser SVG Image Tests")
struct ParserSVGImageTests {

    @Test
    func shapes() throws {
        let svg = try DOM.SVG.parse(fileNamed: "shapes.svg", in: .test)

        #expect(svg.width == 500)
        #expect(svg.height == 700)
        #expect(svg.viewBox?.width == 500)
        #expect(svg.viewBox?.height == 700)
        #expect(svg.defs.clipPaths.count == 2)
        #expect(svg.defs.linearGradients.count == 1)
        #expect(svg.defs.radialGradients.count == 1)
        #expect(svg.defs.elements["star"] != nil)
        #expect(svg.defs.elements.count == 2)

        var c = svg.childElements.enumerated().makeIterator()

        #expect(c.next()!.element is DOM.Ellipse)
        #expect(c.next()!.element is DOM.Group)
        #expect(c.next()!.element is DOM.Circle)
        #expect(c.next()!.element is DOM.Group)
        #expect(c.next()!.element is DOM.Line)
        #expect(c.next()!.element is DOM.Path)
        #expect(c.next()!.element is DOM.Path)
        #expect(c.next()!.element is DOM.Path)
        #expect(c.next()!.element is DOM.Path)
        #expect(c.next()!.element is DOM.Polyline)
        #expect(c.next()!.element is DOM.Polyline)
        #expect(c.next()!.element is DOM.Polygon)
        #expect(c.next()!.element is DOM.Group)
        #expect(c.next()!.element is DOM.Circle)
        #expect(c.next()!.element is DOM.Switch)
        #expect(c.next()!.element is DOM.Rect)
        #expect(c.next()!.element is DOM.Text)
        #expect(c.next()!.element is DOM.Text)
        #expect(c.next()!.element is DOM.Line)
        #expect(c.next()!.element is DOM.Use)
        #expect(c.next()!.element is DOM.Use)
        #expect(c.next()!.element is DOM.Rect)
        #expect(c.next() == nil)
    }

    @Test
    func starry() throws {
        let svg = try DOM.SVG.parse(fileNamed: "starry.svg", in: .test)
        guard let g = svg.childElements.first as? DOM.Group,
              let g1 = g.childElements.first as? DOM.Group else {
            Issue.record("missing group")
            return
        }

        #expect(svg.width == 500)
        #expect(svg.height == 500)

        #expect(g1.childElements.count == 9323)

        var counter = [String: Int]()

        for e in g1.childElements {
            let key = String(describing: type(of: e))
            counter[key] = (counter[key] ?? 0) + 1
        }

        #expect(counter["Path"] == 9314)
        #expect(counter["Polygon"] == 9)
    }

    @Test
    func quad() throws {
        let svg = try DOM.SVG.parse(fileNamed: "quad.svg", in: .test)
        #expect(svg.width == 1000)
        #expect(svg.height == 500)
    }

    @Test
    func curves() throws {
        let svg = try DOM.SVG.parse(fileNamed: "curves.svg", in: .test)
        #expect(svg.width == 550)
        #expect(svg.height == 350)
    }

    @Test
    func nested() throws {
        let svg = try DOM.SVG.parse(fileNamed: "nested-svg.svg", in: .test)
        #expect(svg.width == 360)
        #expect(svg.height == 450)
    }
}
