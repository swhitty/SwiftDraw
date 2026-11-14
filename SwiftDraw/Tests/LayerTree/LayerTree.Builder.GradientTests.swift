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
import XCTest
@testable import SwiftDraw

final class LayerTreeBuilderGradientTests: XCTestCase {

    func testRadialGradient_InheritsStops_FromLinearGradient() throws {
        let svg = try DOM.SVG.parse(xml: #"""
        <svg width="10" height="10" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
            <defs>
                <linearGradient id="a"><stop offset="0" stop-color="red"/><stop offset="1" stop-color="blue"/></linearGradient>
                <radialGradient id="b" xlink:href="#a" cx="5" cy="5" r="5" gradientUnits="userSpaceOnUse"/>
            </defs>
        </svg>
        """#)
        let builder = LayerTree.Builder(svg: svg)

        let gradient = try XCTUnwrap(builder.makeGradient(for: svg.defs.radialGradients[0]))
        XCTAssertEqual(gradient.gradient.stops, builder.makeGradientStops(for: svg.defs.linearGradients[0]))
        XCTAssertEqual(gradient.endCenter, LayerTree.Point(5, 5))
        XCTAssertEqual(gradient.endRadius, 5)
    }

    func testLinearGradient_InheritsUnitsGeometryAndTransform() throws {
        let svg = try DOM.SVG.parse(xml: #"""
        <svg width="10" height="10" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
            <defs>
                <linearGradient id="a" x1="1" y1="2" x2="3" y2="4" gradientUnits="userSpaceOnUse" gradientTransform="translate(5 6)">
                    <stop offset="0" stop-color="red"/><stop offset="1" stop-color="blue"/>
                </linearGradient>
                <linearGradient id="b" xlink:href="#a"/>
            </defs>
        </svg>
        """#)
        let builder = LayerTree.Builder(svg: svg)

        let gradient = try XCTUnwrap(builder.makeGradient(for: svg.defs.linearGradients[1]))
        XCTAssertEqual(gradient.units, .userSpaceOnUse)
        XCTAssertEqual(gradient.start, LayerTree.Point(1, 2))
        XCTAssertEqual(gradient.end, LayerTree.Point(3, 4))
        XCTAssertEqual(gradient.transform, [.translate(tx: 5, ty: 6)])
    }

    func testGradient_OwnAttributes_OverrideReferenced() throws {
        let svg = try DOM.SVG.parse(xml: #"""
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
        """#)
        let builder = LayerTree.Builder(svg: svg)

        let gradient = try XCTUnwrap(builder.makeGradient(for: svg.defs.linearGradients[1]))
        XCTAssertEqual(gradient.units, .objectBoundingBox)
        XCTAssertEqual(gradient.start.x, 0.5)
        XCTAssertEqual(gradient.gradient.stops, builder.makeGradientStops(for: svg.defs.linearGradients[1]))
    }

    func testRadialGradient_DoesNotInheritGeometry_FromLinearGradient() throws {
        let svg = try DOM.SVG.parse(xml: #"""
        <svg width="10" height="10" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
            <defs>
                <linearGradient id="a" x1="7" gradientUnits="userSpaceOnUse">
                    <stop offset="0" stop-color="red"/><stop offset="1" stop-color="blue"/>
                </linearGradient>
                <radialGradient id="b" xlink:href="#a"/>
            </defs>
        </svg>
        """#)
        let builder = LayerTree.Builder(svg: svg)

        let gradient = try XCTUnwrap(builder.makeGradient(for: svg.defs.radialGradients[0]))
        XCTAssertEqual(gradient.units, .userSpaceOnUse)
        XCTAssertEqual(gradient.endCenter, LayerTree.Point(0.5, 0.5))
        XCTAssertEqual(gradient.endRadius, 0.5)
    }

    func testGradient_FollowsReferenceChain() throws {
        let svg = try DOM.SVG.parse(xml: #"""
        <svg width="10" height="10" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
            <defs>
                <linearGradient id="a" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="red"/><stop offset="1" stop-color="blue"/></linearGradient>
                <linearGradient id="b" xlink:href="#a"/>
                <radialGradient id="c" xlink:href="#b"/>
            </defs>
        </svg>
        """#)
        let builder = LayerTree.Builder(svg: svg)

        let gradient = try XCTUnwrap(builder.makeGradient(for: svg.defs.radialGradients[0]))
        XCTAssertEqual(gradient.gradient.stops, builder.makeGradientStops(for: svg.defs.linearGradients[0]))
        XCTAssertEqual(gradient.units, .userSpaceOnUse)
    }

    func testGradient_ReferenceCycle_ReturnsNil() throws {
        let svg = try DOM.SVG.parse(xml: #"""
        <svg width="10" height="10" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
            <defs>
                <linearGradient id="a" xlink:href="#b"/>
                <radialGradient id="b" xlink:href="#a"/>
            </defs>
        </svg>
        """#)
        let builder = LayerTree.Builder(svg: svg)

        XCTAssertNil(builder.makeGradient(for: svg.defs.linearGradients[0]))
        XCTAssertNil(builder.makeGradient(for: svg.defs.radialGradients[0]))
    }

    func testLinearGradient_DoesNotInheritGeometry_ThroughDifferentKind() throws {
        let svg = try DOM.SVG.parse(xml: #"""
        <svg width="10" height="10" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
            <defs>
                <linearGradient id="a" x1="7" gradientUnits="userSpaceOnUse">
                    <stop offset="0" stop-color="red"/><stop offset="1" stop-color="blue"/>
                </linearGradient>
                <radialGradient id="b" xlink:href="#a"/>
                <linearGradient id="c" xlink:href="#b"/>
            </defs>
        </svg>
        """#)
        let builder = LayerTree.Builder(svg: svg)

        let gradient = try XCTUnwrap(builder.makeGradient(for: svg.defs.linearGradients[1]))
        XCTAssertEqual(gradient.start.x, 0)
        XCTAssertEqual(gradient.units, .userSpaceOnUse)
    }
}
