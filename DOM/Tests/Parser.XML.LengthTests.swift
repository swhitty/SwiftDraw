//
//  Parser.XML.LengthTests.swift
//  SwiftDraw
//
//  Added by Misoservices for the Backdrop fork of SwiftDraw (altered source version).
//  Copyright 2026 Misoservices
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

// SD13 — SVG 1.1 §7.10: units and percentages on geometry
struct ParserXMLLengthTests {

    private func parse(_ body: String, root: String = #"width="200" height="100""#) throws -> DOM.SVG {
        let xml = #"<svg xmlns="http://www.w3.org/2000/svg" \#(root)>\#(body)</svg>"#
        return try DOM.SVG.parse(data: Data(xml.utf8))
    }

    private func close(_ a: DOM.Coordinate?, _ b: DOM.Coordinate) -> Bool {
        guard let a else { return false }
        return abs(a - b) < 0.0001
    }

    @Test
    func rectPercentagesResolveAgainstTheViewport() throws {
        let svg = try parse(#"<rect x="10%" y="20%" width="50%" height="25%" rx="5%" ry="10%"/>"#)
        let rect = try #require(svg.childElements.first as? DOM.Rect)
        #expect(rect.x == 20)
        #expect(rect.y == 20)
        #expect(rect.width == 100)
        #expect(rect.height == 25)
        #expect(rect.rx == 10)
        #expect(rect.ry == 10)
    }

    @Test
    func percentagesResolveAgainstTheViewBoxNotTheSize() throws {
        let svg = try parse(#"<rect width="50%" height="50%"/>"#,
                            root: #"width="400" height="400" viewBox="0 0 20 10""#)
        let rect = try #require(svg.childElements.first as? DOM.Rect)
        #expect(rect.width == 10)
        #expect(rect.height == 5)
    }

    @Test
    func radiusPercentageUsesTheNormalizedDiagonal() throws {
        // sqrt((200² + 100²) / 2) = 158.1139
        let svg = try parse(#"<circle cx="50%" cy="50%" r="10%"/><ellipse cx="25%" cy="75%" rx="10%" ry="10%"/>"#)
        let circle = try #require(svg.childElements.first as? DOM.Circle)
        #expect(circle.cx == 100)
        #expect(circle.cy == 50)
        #expect(close(circle.r, 15.81139))
        let ellipse = try #require(svg.childElements.last as? DOM.Ellipse)
        #expect(ellipse.cx == 50)
        #expect(ellipse.cy == 75)
        #expect(ellipse.rx == 20)
        #expect(ellipse.ry == 10)
    }

    @Test
    func linePercentages() throws {
        let svg = try parse(#"<line x1="0%" y1="100%" x2="100%" y2="50%"/>"#)
        let line = try #require(svg.childElements.first as? DOM.Line)
        #expect(line.x1 == 0)
        #expect(line.y1 == 100)
        #expect(line.x2 == 200)
        #expect(line.y2 == 50)
    }

    @Test
    func absoluteUnitsUseTheCSSRatios() throws {
        // 1in = 2.54cm = 25.4mm = 72pt = 6pc = 96px (CSS Values 3 §6.2)
        let svg = try parse(#"<rect x="1in" y="2.54cm" width="25.4mm" height="72pt" rx="6pc" ry="96px"/>"#)
        let rect = try #require(svg.childElements.first as? DOM.Rect)
        #expect(close(rect.x, 96))
        #expect(close(rect.y, 96))
        #expect(close(rect.width, 96))
        #expect(close(rect.height, 96))
        #expect(close(rect.rx, 96))
        #expect(close(rect.ry, 96))
    }

    @Test
    func emAndExUseTheElementFontSize() throws {
        let svg = try parse(#"""
            <rect width="2em" height="2ex"/>
            <g font-size="10"><rect width="2em" height="2ex" style="font-size: 20px"/><rect width="1em" height="1em"/></g>
            """#)
        let initial = try #require(svg.childElements.first as? DOM.Rect)
        #expect(initial.width == 32)
        #expect(initial.height == 16)
        let group = try #require(svg.childElements.last as? DOM.Group)
        let own = try #require(group.childElements.first as? DOM.Rect)
        #expect(own.width == 40)
        #expect(own.height == 20)
        let inherited = try #require(group.childElements.last as? DOM.Rect)
        #expect(inherited.width == 10)
    }

    @Test
    func emFollowsAStyleSheetFontSize() throws {
        let svg = try parse(#"<style>.big { font-size: 30px }</style><rect class="big" width="1em" height="1em"/>"#)
        let rect = try #require(svg.childElements.compactMap { $0 as? DOM.Rect }.first)
        #expect(rect.width == 30)
    }

    @Test
    func fontSizeAcceptsAbsoluteUnits() throws {
        let svg = try parse(#"<text font-size="12pt">A</text>"#)
        #expect(svg.childElements.first?.attributes.fontSize == 16)
    }

    @Test
    func useImageAndTextPositions() throws {
        let svg = try parse(#"""
            <use href="#a" x="50%" y="1in"/>
            <image href="data:image/png;base64,AAAA" x="25%" y="50%" width="50%" height="10.5"/>
            <text x="10%" y="1em">A</text>
            """#)
        let use = try #require(svg.childElements[0] as? DOM.Use)
        #expect(use.x == 100)
        #expect(use.y == 96)
        let image = try #require(svg.childElements[1] as? DOM.Image)
        #expect(image.x == 50)
        #expect(image.y == 50)
        #expect(image.width == 100)
        #expect(image.height == 10.5)
        let text = try #require(svg.childElements[2] as? DOM.Text)
        #expect(text.x == 20)
        #expect(text.y == 16)
    }

    @Test
    func rootSizesStayFractional() throws {
        let svg = try parse("", root: #"width="145.11934" height="80.5" viewBox="0 0 145.11934 80.5""#)
        #expect(svg.width == 145.11934)
        #expect(svg.height == 80.5)
    }

    @Test
    func rootWithOnlyWidthTakesTheViewBoxRatio() throws {
        let svg = try parse("", root: #"width="200" viewBox="0 0 100 50""#)
        #expect(svg.width == 200)
        #expect(svg.height == 100)
    }

    @Test
    func rootWithOnlyHeightTakesTheViewBoxRatio() throws {
        let svg = try parse("", root: #"height="25mm" viewBox="0 0 30 10""#)
        #expect(close(svg.height, 25 * 96 / 25.4))
        #expect(close(svg.width, 3 * 25 * 96 / 25.4))
    }

    @Test
    func nestedSVGResolvesAgainstTheEnclosingViewport() throws {
        let svg = try parse(#"""
            <svg x="25%" y="10%" width="50%" height="80" viewBox="0 0 10 10"><rect width="50%" height="100%"/></svg>
            """#)
        let nested = try #require(svg.childElements.first as? DOM.SVG)
        #expect(nested.x == 50)
        #expect(nested.y == 10)
        #expect(nested.width == 100)
        #expect(nested.height == 80)
        // its own contents resolve against its viewBox, and are parsed once
        #expect(nested.childElements.count == 1)
        let rect = try #require(nested.childElements.first as? DOM.Rect)
        #expect(rect.width == 5)
        #expect(rect.height == 10)
    }

    @Test
    func nestedSVGWithoutSizeFillsTheEnclosingViewport() throws {
        let svg = try parse(#"<svg viewBox="0 0 10 10"/><rect width="50%" height="50%"/>"#)
        let nested = try #require(svg.childElements.first as? DOM.SVG)
        #expect(nested.width == 200)
        #expect(nested.height == 100)
        let rect = try #require(svg.childElements.last as? DOM.Rect)
        #expect(rect.width == 100)
        #expect(rect.height == 50)
    }

    @Test
    func invalidNestedSizeFallsBackTo100Percent() throws {
        let svg = try parse(#"<svg width="bogus" height="-"/>"#)
        let nested = try #require(svg.childElements.first as? DOM.SVG)
        #expect(nested.width == 200)
        #expect(nested.height == 100)
    }

    @Test
    func percentageWithoutAViewportKeepsItsNumber() throws {
        // an element parsed on its own (outside any <svg>) has no viewport: previous behaviour
        let rect = try XMLParser().parseRect(XMLParser().parseAttributes(XML.Element(name: "rect", attributes: ["width": "20%", "height": "1"])))
        #expect(rect.width == 20)
    }
}
