//
//  LayerTree.GradientUserSpaceTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 16/11/26.
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


@testable import SwiftDraw
@testable import SwiftDrawDOM
import Testing

/// SVG 1.1 §13.2: under userSpaceOnUse, missing gradient geometry and percentages resolve
/// against the viewport: its width for x, height for y and normalised diagonal for radii.
struct LayerTreeGradientUserSpaceTests {

    static let stops = #"<stop offset="0" stop-color="red"/><stop offset="1" stop-color="blue"/>"#

    // √(300² + 100²) / √2
    static let diagonal = LayerTree.Float(50_000).squareRoot()

    @Test
    func linearDefaultsSpanTheViewportWidth() throws {
        let gradient = try makeLinear(#"<linearGradient id="g" gradientUnits="userSpaceOnUse">\#(Self.stops)</linearGradient>"#)
        #expect(gradient.start == LayerTree.Point(0, 0))
        #expect(gradient.end == LayerTree.Point(300, 0))
    }

    @Test
    func linearPercentagesResolveAgainstTheViewport() throws {
        let gradient = try makeLinear(#"""
        <linearGradient id="g" gradientUnits="userSpaceOnUse" x1="10%" y1="50%" x2="90%" y2="25">\#(Self.stops)</linearGradient>
        """#)
        #expect(gradient.start == LayerTree.Point(30, 50))
        #expect(gradient.end == LayerTree.Point(270, 25))
    }

    @Test
    func linearPercentagesStayFractionsInObjectBoundingBox() throws {
        let gradient = try makeLinear(#"<linearGradient id="g" x1="10%" x2="90%">\#(Self.stops)</linearGradient>"#)
        #expect(gradient.units == .objectBoundingBox)
        #expect(gradient.start == LayerTree.Point(0.1, 0))
        #expect(gradient.end == LayerTree.Point(0.9, 0))
    }

    @Test
    func radialDefaultsAreCentredInTheViewport() throws {
        let gradient = try makeRadial(#"<radialGradient id="g" gradientUnits="userSpaceOnUse">\#(Self.stops)</radialGradient>"#)
        #expect(gradient.endCenter == LayerTree.Point(150, 50))
        #expect(gradient.center == LayerTree.Point(150, 50))
        #expect(gradient.endRadius == 0.5 * Self.diagonal)
        #expect(gradient.radius == 0)
    }

    @Test
    func radialPercentagesResolveAgainstTheViewport() throws {
        let gradient = try makeRadial(#"""
        <radialGradient id="g" gradientUnits="userSpaceOnUse" cx="20%" cy="40%" r="10%" fx="10%" fy="20" fr="5%">\#(Self.stops)</radialGradient>
        """#)
        #expect(gradient.endCenter == LayerTree.Point(60, 40))
        #expect(gradient.center == LayerTree.Point(30, 20))
        #expect(gradient.endRadius == 0.1 * Self.diagonal)
        #expect(gradient.radius == 0.05 * Self.diagonal)
    }

    @Test
    func percentagesResolveAgainstTheViewBox() throws {
        let gradient = try makeLinear(#"<linearGradient id="g" gradientUnits="userSpaceOnUse" x1="50%">\#(Self.stops)</linearGradient>"#,
                                      root: #"width="300" height="100" viewBox="0 0 30 10""#)
        #expect(gradient.start == LayerTree.Point(15, 0))
        #expect(gradient.end == LayerTree.Point(30, 0))
    }

    @Test
    func linearUnitsInheritedThroughHref() throws {
        let gradient = try makeLinear(#"""
        <linearGradient id="a" gradientUnits="userSpaceOnUse">\#(Self.stops)</linearGradient>
        <linearGradient id="g" href="#a" x1="10%"/>
        """#)
        #expect(gradient.units == .userSpaceOnUse)
        #expect(gradient.start == LayerTree.Point(30, 0))
        #expect(gradient.end == LayerTree.Point(300, 0))
    }

    @Test
    func linearPercentagesInheritedThroughHref() throws {
        let gradient = try makeLinear(#"""
        <linearGradient id="a" x1="10%" y2="100%">\#(Self.stops)</linearGradient>
        <linearGradient id="g" href="#a" gradientUnits="userSpaceOnUse" x2="100"/>
        """#)
        #expect(gradient.start == LayerTree.Point(30, 0))
        #expect(gradient.end == LayerTree.Point(100, 100))
    }

    @Test
    func radialGeometryInheritedThroughHref() throws {
        let gradient = try makeRadial(#"""
        <radialGradient id="a" cx="10%" r="50%">\#(Self.stops)</radialGradient>
        <radialGradient id="b" href="#a" gradientUnits="userSpaceOnUse"/>
        <radialGradient id="g" href="#b" cy="10"/>
        """#)
        #expect(gradient.units == .userSpaceOnUse)
        #expect(gradient.endCenter == LayerTree.Point(30, 10))
        #expect(gradient.center == LayerTree.Point(30, 10))
        #expect(gradient.endRadius == 0.5 * Self.diagonal)
    }

    // A nested <svg> sets the viewport for the paint servers defined in it, as in WebKit:
    // the referenced element's viewport applies, also to values it inherits through href.

    @Test(arguments: [
        (#"width="100" height="50""#, LayerTree.Point(100, 50)),
        (#"width="25%" height="50%""#, LayerTree.Point(75, 50)),
        (#"width="100" height="50" viewBox="0 0 40 20""#, LayerTree.Point(40, 20)),
    ])
    func linearDefinedInNestedSVGUsesItsViewport(nested: String, end: LayerTree.Point) throws {
        let gradient = try makeLinear(body: #"""
        <svg \#(nested)><defs>
            <linearGradient id="g" gradientUnits="userSpaceOnUse" x2="100%" y2="100%">\#(Self.stops)</linearGradient>
        </defs></svg>
        """#)
        #expect(gradient.start == LayerTree.Point(0, 0))
        #expect(gradient.end == end)
    }

    @Test
    func radialDefaultsInNestedSVGUseItsViewport() throws {
        let gradient = try makeRadial(body: #"""
        <svg width="100" height="100" viewBox="0 0 40 20"><defs>
            <radialGradient id="g" gradientUnits="userSpaceOnUse">\#(Self.stops)</radialGradient>
        </defs></svg>
        """#)
        #expect(gradient.endCenter == LayerTree.Point(20, 10))
        #expect(gradient.endRadius == 0.5 * LayerTree.Float(1000).squareRoot())
    }

    @Test
    func percentageInheritedFromNestedSVGUsesReferencedViewport() throws {
        let gradient = try makeLinear(body: #"""
        <svg width="100" height="100"><defs>
            <linearGradient id="a" gradientUnits="userSpaceOnUse" x2="50%">\#(Self.stops)</linearGradient>
        </defs></svg>
        <defs><linearGradient id="g" href="#a"/></defs>
        """#)
        #expect(gradient.end == LayerTree.Point(150, 0))
    }

    @Test
    func nestedGradientInheritingFromRootUsesItsOwnViewport() throws {
        let gradient = try makeLinear(body: #"""
        <defs><linearGradient id="a" gradientUnits="userSpaceOnUse" x1="10%">\#(Self.stops)</linearGradient></defs>
        <svg width="100" height="100"><defs><linearGradient id="g" href="#a"/></defs></svg>
        """#)
        #expect(gradient.start == LayerTree.Point(10, 0))
        #expect(gradient.end == LayerTree.Point(100, 0))
    }

    @Test
    func patternDefinedInNestedSVGUsesItsViewport() throws {
        let svg = try DOM.SVG.parse(xml: #"""
        <svg width="300" height="100" xmlns="http://www.w3.org/2000/svg">
            <svg width="100" height="50"><defs>
                <pattern id="a" patternUnits="userSpaceOnUse" width="20%" height="20%"><rect width="5" height="5"/></pattern>
            </defs></svg>
            <defs><pattern id="g" href="#a" x="10%"/></defs>
        </svg>
        """#)
        let builder = LayerTree.Builder(svg: svg)
        let nested = try #require(svg.defs.patterns.first { $0.id == "a" })
        let root = try #require(svg.defs.patterns.first { $0.id == "g" })
        #expect(builder.makePattern(for: nested).frame == LayerTree.Rect(x: 0, y: 0, width: 20, height: 10))
        #expect(builder.makePattern(for: root).frame == LayerTree.Rect(x: 30, y: 0, width: 60, height: 20))
    }

    func makeLinear(body: String) throws -> LayerTree.LinearGradient {
        let svg = try DOM.SVG.parse(xml: #"""
        <svg width="300" height="100" xmlns="http://www.w3.org/2000/svg">\#(body)</svg>
        """#)
        let element = try #require(svg.defs.linearGradients.first { $0.id == "g" })
        return try #require(LayerTree.Builder(svg: svg).makeGradient(for: element))
    }

    func makeRadial(body: String) throws -> LayerTree.RadialGradient {
        let svg = try DOM.SVG.parse(xml: #"""
        <svg width="300" height="100" xmlns="http://www.w3.org/2000/svg">\#(body)</svg>
        """#)
        let element = try #require(svg.defs.radialGradients.first { $0.id == "g" })
        return try #require(LayerTree.Builder(svg: svg).makeGradient(for: element))
    }

    func makeBuilder(_ defs: String, root: String) throws -> (LayerTree.Builder, DOM.SVG) {
        let svg = try DOM.SVG.parse(xml: #"""
        <svg \#(root) xmlns="http://www.w3.org/2000/svg">
            <defs>\#(defs)</defs>
        </svg>
        """#)
        return (LayerTree.Builder(svg: svg), svg)
    }

    func makeLinear(_ defs: String, root: String = #"width="300" height="100""#) throws -> LayerTree.LinearGradient {
        let (builder, svg) = try makeBuilder(defs, root: root)
        let element = try #require(svg.defs.linearGradients.first { $0.id == "g" })
        return try #require(builder.makeGradient(for: element))
    }

    func makeRadial(_ defs: String) throws -> LayerTree.RadialGradient {
        let (builder, svg) = try makeBuilder(defs, root: #"width="300" height="100""#)
        let element = try #require(svg.defs.radialGradients.first { $0.id == "g" })
        return try #require(builder.makeGradient(for: element))
    }
}
