//
//  DOM.ElementTests.swift
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

struct DOMElementTests {

    @Test
    func line() {
        let element = DOM.createLine()
        var another = DOM.createLine()

        #expect(element == another)

        another.x1 = 1
        #expect(element != another)

        another = DOM.createLine()
        another.attributes.fill = .color(.keyword(.black))
        #expect(element != another)

        another.attributes.fill = nil
        #expect(element == another)
    }

    @Test
    func circle() {
        let element = DOM.createCircle()
        var another = DOM.createCircle()

        #expect(element == another)

        another.cx = 1
        #expect(element != another)

        another = DOM.createCircle()
        another.attributes.fill = .color(.keyword(.black))
        #expect(element != another)

        another.attributes.fill = nil
        #expect(element == another)
    }

    @Test
    func ellipse() {
        let element = DOM.createEllipse()
        var another = DOM.createEllipse()

        #expect(element == another)

        another.cx = 1
        #expect(element != another)

        another = DOM.createEllipse()
        another.attributes.fill = .color(.keyword(.black))
        #expect(element != another)

        another.attributes.fill = nil
        #expect(element == another)
    }

    @Test
    func rect() {
        let element = DOM.createRect()
        var another = DOM.createRect()

        #expect(element == another)

        another.x = 1
        #expect(element != another)

        another = DOM.createRect()
        another.attributes.fill = .color(.keyword(.black))
        #expect(element != another)

        another.attributes.fill = nil
        #expect(element == another)
    }

    @Test
    func polygon() {
        let element = DOM.createPolygon()
        var another = DOM.createPolygon()

        #expect(element == another)

        another.points.append(DOM.Point(6, 7))
        #expect(element != another)

        another = DOM.createPolygon()
        another.attributes.fill = .color(.keyword(.black))
        #expect(element != another)

        another.attributes.fill = nil
        #expect(element == another)
    }

    @Test
    func polyline() {
        let element = DOM.createPolyline()
        var another = DOM.createPolyline()

        #expect(element == another)

        another.points.append(DOM.Point(6, 7))
        #expect(element != another)

        another = DOM.createPolyline()
        another.attributes.fill = .color(.keyword(.black))
        #expect(element != another)

        another.attributes.fill = nil
        #expect(element == another)
    }

    @Test
    func text() {
        let element = DOM.createText()
        var another = DOM.createText()

        #expect(element == another)

        another.value = "Simon"
        #expect(element != another)

        another = DOM.createText()
        another.attributes.fill = .color(.keyword(.black))
        #expect(element != another)

        another.attributes.fill = nil
        #expect(element == another)
    }

    @Test
    func group() {
        let group = DOM.createGroup()
        var another = DOM.createGroup()

        #expect(group == another)

        another.childElements.append(DOM.createCircle())
        #expect(group != another)

        another = DOM.createGroup()
        another.attributes.fill = .color(.keyword(.black))
        #expect(group != another)

        another.attributes.fill = nil
        #expect(group == another)
    }
}
