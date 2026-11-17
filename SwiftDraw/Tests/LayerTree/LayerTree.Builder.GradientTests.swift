//
//  LayerTree.Builder.GradientTests.swift
//  SwiftDraw
//
//  Created by Alex Fishlock on 8/11/26.
//  Copyright 2026 Alex Fishlock. All rights reserved.
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
@testable import SwiftDraw
import Testing

struct LayerTreeBuilderGradientTests {

    @Test
    func radialGradientInheritsStopsFromLinearGradient() throws {
        let svg = try DOM.SVG.parse(
            xml: #"""
                <svg width="10" height="10" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
                    <defs>
                        <linearGradient id="a"><stop offset="0" stop-color="red"/><stop offset="1" stop-color="blue"/></linearGradient>
                        <radialGradient id="b" xlink:href="#a" cx="5" cy="5" r="5" gradientUnits="userSpaceOnUse"/>
                    </defs>
                </svg>
                """#
        )
        let builder = LayerTree.Builder(svg: svg)

        let gradient = try #require(builder.makeGradient(for: svg.defs.radialGradients[0]))
        #expect(gradient.gradient.stops == builder.makeGradientStops(for: svg.defs.linearGradients[0]))
        #expect(gradient.endCenter == LayerTree.Point(5, 5))
        #expect(gradient.endRadius == 5)
    }

    @Test
    func linearGradientInheritsUnitsGeometryAndTransform() throws {
        let svg = try DOM.SVG.parse(
            xml: #"""
                <svg width="10" height="10" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
                    <defs>
                        <linearGradient id="a" x1="1" y1="2" x2="3" y2="4" gradientUnits="userSpaceOnUse" gradientTransform="translate(5 6)">
                            <stop offset="0" stop-color="red"/><stop offset="1" stop-color="blue"/>
                        </linearGradient>
                        <linearGradient id="b" xlink:href="#a"/>
                    </defs>
                </svg>
                """#
        )
        let builder = LayerTree.Builder(svg: svg)

        let gradient = try #require(builder.makeGradient(for: svg.defs.linearGradients[1]))
        #expect(gradient.units == .userSpaceOnUse)
        #expect(gradient.start == LayerTree.Point(1, 2))
        #expect(gradient.end == LayerTree.Point(3, 4))
        #expect(gradient.transform == [.translate(tx: 5, ty: 6)])
    }

    @Test
    func ownAttributesOverrideReferencedGradient() throws {
        let svg = try DOM.SVG.parse(
            xml: #"""
                <svg width="10" height="10" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
                    <defs>
                        <linearGradient id="a" x1="1" gradientUnits="userSpaceOnUse">
                            <stop offset="0" stop-color="red"/><stop offset="1" stop-color="blue"/>
                        </linearGradient>
                        <linearGradient id="b" xlink:href="#a" x1="0.5" gradientUnits="objectBoundingBox">
                            <stop offset="0" stop-color="green"/><stop offset="1" stop-color="white"/>
                        </linearGradient>
                    </defs>
                </svg>
                """#
        )
        let builder = LayerTree.Builder(svg: svg)

        let gradient = try #require(builder.makeGradient(for: svg.defs.linearGradients[1]))
        #expect(gradient.units == .objectBoundingBox)
        #expect(gradient.start.x == 0.5)
        #expect(gradient.gradient.stops == builder.makeGradientStops(for: svg.defs.linearGradients[1]))
    }

    @Test
    func radialGradientDoesNotInheritGeometryFromLinearGradient() throws {
        let svg = try DOM.SVG.parse(
            xml: #"""
                <svg width="10" height="10" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
                    <defs>
                        <linearGradient id="a" x1="7" gradientUnits="userSpaceOnUse">
                            <stop offset="0" stop-color="red"/><stop offset="1" stop-color="blue"/>
                        </linearGradient>
                        <radialGradient id="b" xlink:href="#a"/>
                    </defs>
                </svg>
                """#
        )
        let builder = LayerTree.Builder(svg: svg)

        let gradient = try #require(builder.makeGradient(for: svg.defs.radialGradients[0]))
        #expect(gradient.units == .userSpaceOnUse)
        // the defaults (50%) of the 10x10 viewport, not the linear gradient's x1
        #expect(gradient.endCenter == LayerTree.Point(5, 5))
        #expect(gradient.endRadius == 5)
    }

    @Test
    func gradientFollowsReferenceChain() throws {
        let svg = try DOM.SVG.parse(
            xml: #"""
                <svg width="10" height="10" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
                    <defs>
                        <linearGradient id="a" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="red"/><stop offset="1" stop-color="blue"/></linearGradient>
                        <linearGradient id="b" xlink:href="#a"/>
                        <radialGradient id="c" xlink:href="#b"/>
                    </defs>
                </svg>
                """#
        )
        let builder = LayerTree.Builder(svg: svg)

        let gradient = try #require(builder.makeGradient(for: svg.defs.radialGradients[0]))
        #expect(gradient.gradient.stops == builder.makeGradientStops(for: svg.defs.linearGradients[0]))
        #expect(gradient.units == .userSpaceOnUse)
    }

    @Test
    func gradientReferenceCycleReturnsNil() throws {
        let svg = try DOM.SVG.parse(
            xml: #"""
                <svg width="10" height="10" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
                    <defs>
                        <linearGradient id="a" xlink:href="#b"/>
                        <radialGradient id="b" xlink:href="#a"/>
                    </defs>
                </svg>
                """#
        )
        let builder = LayerTree.Builder(svg: svg)

        #expect(builder.makeGradient(for: svg.defs.linearGradients[0]) == nil)
        #expect(builder.makeGradient(for: svg.defs.radialGradients[0]) == nil)
    }
}
