//
//  LayerTree.DropShadowTests.swift
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
@testable import SwiftDraw
import Foundation
import Testing

// Filter Effects 1 §9.12: feDropShadow resolves into the primitives that define it
struct LayerTreeDropShadowTests {

    typealias Primitive = LayerTree.FilterLayer.Primitive

    @Test
    func expandsIntoPrimitives() throws {
        let filter = try makeFilterLayer(
            #"""
            <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
                <filter id="f" filterUnits="userSpaceOnUse" x="0" y="0" width="100" height="100">
                    <feDropShadow dx="3" dy="-1" stdDeviation="2 1" flood-color="red" flood-opacity="0.5" />
                </filter>
                <rect x="10" y="10" width="50" height="50" filter="url(#f)" />
            </svg>
            """#
        )

        let region = LayerTree.Rect(x: 0, y: 0, width: 100, height: 100)
        #expect(filter.region == region)
        #expect(
            filter.primitives == [
                Primitive(
                    effect: .gaussianBlur(stdDeviation: 2, stdDeviationY: 1),
                    inputs: [.sourceGraphic],
                    subregion: region,
                    colorInterpolation: .linearRGB
                ),
                Primitive(
                    effect: .offset(dx: 3, dy: -1),
                    inputs: [.primitive(0)],
                    subregion: region,
                    colorInterpolation: .linearRGB
                ),
                Primitive(
                    effect: .flood(.rgba(r: 1, g: 0, b: 0, a: 0.5, space: .srgb)),
                    inputs: [],
                    subregion: region,
                    colorInterpolation: .linearRGB
                ),
                Primitive(
                    effect: .composite(.in),
                    inputs: [.primitive(2), .primitive(1)],
                    subregion: region,
                    colorInterpolation: .linearRGB
                ),
                Primitive(
                    effect: .merge,
                    inputs: [.primitive(3), .sourceGraphic],
                    subregion: region,
                    colorInterpolation: .linearRGB
                ),
            ]
        )
        #expect(!filter.isBlurChain)
    }

    @Test
    func boundingBoxPrimitiveUnits() throws {
        let filter = try makeFilterLayer(
            #"""
            <svg width="200" height="200" xmlns="http://www.w3.org/2000/svg">
                <filter id="f" primitiveUnits="objectBoundingBox" color-interpolation-filters="sRGB">
                    <feDropShadow dx="0.1" dy="0.5" stdDeviation="0.05 0.25" />
                </filter>
                <rect x="0" y="100" width="200" height="40" filter="url(#f)" />
            </svg>
            """#
        )

        #expect(
            filter.effects.prefix(2) == [
                .gaussianBlur(stdDeviation: 10, stdDeviationY: 10),
                .offset(dx: 20, dy: 20),
            ]
        )
        #expect(filter.primitives.allSatisfy { $0.colorInterpolation == .sRGB })
    }

    // the shadow's subregion clips the merged result; the steps before it cover the filter region
    @Test
    func subregionClipsResult() throws {
        let filter = try makeFilterLayer(
            #"""
            <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
                <filter id="f" filterUnits="userSpaceOnUse" x="0" y="0" width="100" height="100">
                    <feDropShadow x="20" width="30" />
                </filter>
                <rect x="10" y="10" width="50" height="50" filter="url(#f)" />
            </svg>
            """#
        )

        let region = LayerTree.Rect(x: 0, y: 0, width: 100, height: 100)
        #expect(
            filter.primitives.map(\.subregion) == [
                region, region, region, region,
                LayerTree.Rect(x: 20, y: 0, width: 30, height: 100),
            ]
        )
    }

    @Test
    func namedInputAndResult() throws {
        let filter = try makeFilterLayer(
            #"""
            <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
                <filter id="f">
                    <feOffset dx="1" result="moved" />
                    <feDropShadow in="moved" result="shadow" />
                    <feColorMatrix in="shadow" type="saturate" values="0" />
                </filter>
                <rect x="10" y="10" width="50" height="50" filter="url(#f)" />
            </svg>
            """#
        )

        #expect(filter.primitives.count == 7)
        // the shadow reads the offset at 0, the colour matrix reads the shadow's merge at 5
        #expect(filter.primitives[1].inputs == [.primitive(0)])
        #expect(filter.primitives[5].effect == .merge)
        #expect(filter.primitives[5].inputs == [.primitive(4), .primitive(0)])
        #expect(filter.primitives[6].inputs == [.primitive(5)])
    }

    @Test
    func sourceAlphaInput() throws {
        let filter = try makeFilterLayer(
            #"""
            <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
                <filter id="f"><feDropShadow in="SourceAlpha" /></filter>
                <rect x="10" y="10" width="50" height="50" filter="url(#f)" />
            </svg>
            """#
        )

        #expect(filter.primitives[0].inputs == [.sourceAlpha])
        #expect(filter.primitives[4].inputs == [.primitive(3), .sourceAlpha])
    }

    @Test
    func isSupported() throws {
        let commands = try makeCommands(
            #"""
            <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
                <filter id="f"><feDropShadow /></filter>
                <rect x="10" y="10" width="50" height="50" filter="url(#f)" />
            </svg>
            """#,
            options: .hideUnsupportedFilters
        )

        #expect(commands.filterLayers.count == 1)
        #expect(LayerTree.Filter.dropShadow(DOM.Filter.DropShadow()).isSupported)
    }

    // each shadow is five passes over the region, counted against the cap
    @Test
    func countsAgainstPrimitiveCap() throws {
        func shadows(_ count: Int) -> String {
            let shadows = String(repeating: #"<feDropShadow />"#, count: count)
            return #"<svg width="100" height="100" xmlns="http://www.w3.org/2000/svg"><filter id="f">"#
                + shadows + #"</filter><rect width="10" height="10" filter="url(#f)" /></svg>"#
        }
        let max = LayerTree.FilterLayer.maxPrimitives / 5
        #expect(try makeCommands(shadows(max)).filterLayers.first?.primitives.count == max * 5)
        #expect(try makeCommands(shadows(max + 1)).filterLayers.isEmpty)
    }

    // a hard shadow of a white square: the square over a half-transparent blue copy 2 pixels away
    @Test
    func evaluatesHardShadow() throws {
        let filter = try makeFilterLayer(
            #"""
            <svg width="8" height="8" xmlns="http://www.w3.org/2000/svg">
                <filter id="f" filterUnits="userSpaceOnUse" x="0" y="0" width="8" height="8" color-interpolation-filters="sRGB">
                    <feDropShadow dx="2" dy="2" stdDeviation="0" flood-color="blue" flood-opacity="0.5" />
                </filter>
                <rect x="1" y="1" width="3" height="3" fill="white" filter="url(#f)" />
            </svg>
            """#
        )

        var pixels = [UInt8](repeating: 0, count: 8 * 8 * 4)
        for y in 1...3 {
            for x in 1...3 {
                pixels.replaceSubrange((y * 8 + x) * 4..<(y * 8 + x) * 4 + 4, with: [255, 255, 255, 255])
            }
        }
        let source = FilterBitmap(width: 8, height: 8, pixels: pixels)
        let result = filter.evaluate(source: source, environment: .init(transform: .identity, blur: { _, _, _ in }))

        #expect(result.pixel(x: 2, y: 2) == [255, 255, 255, 255])
        #expect(result.pixel(x: 5, y: 5) == [0, 0, 128, 128])
        #expect(result.pixel(x: 4, y: 2) == [0, 0, 0, 0])
        #expect(result.pixel(x: 0, y: 0) == [0, 0, 0, 0])
    }
}

private extension LayerTreeDropShadowTests {

    func makeCommands(_ xml: String, options: SVG.Options = .default) throws -> [RendererCommand<LayerTreeTypes>] {
        let svg = try DOM.SVG.parse(xml: xml)
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let generator = LayerTree.CommandGenerator(
            provider: LayerTreeProvider(),
            size: .init(svg.width, svg.height),
            options: options
        )
        let commands = generator.renderCommands(for: layer, colorConverter: .default)
        return LayerTree.CommandOptimizer<LayerTreeTypes>().optimizeCommands(commands)
    }

    func makeFilterLayer(_ xml: String) throws -> LayerTree.FilterLayer {
        try #require(makeCommands(xml).filterLayers.first)
    }
}

private extension Array where Element == RendererCommand<LayerTreeTypes> {

    var filterLayers: [LayerTree.FilterLayer] {
        compactMap {
            if case .pushFilterLayer(let filter) = $0 { return filter }
            return nil
        }
    }
}
