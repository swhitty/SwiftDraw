//
//  LayerTree.FilterTests.swift
//  SwiftDraw
//
//  Created by Misoservices on 8/10/26.
//  Copyright 2026 Misoservices. Altered version of SwiftDraw by Simon Whitty.
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
import XCTest

final class LayerTreeFilterTests: XCTestCase {

    func testBlurGeneratesFilterLayerWithDefaultRegion() throws {
        let commands = try makeCommands(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="blur"><feGaussianBlur stdDeviation="5" /></filter>
            <rect x="25" y="25" width="40" height="40" filter="url(#blur)" />
        </svg>
        """#)

        let filter = try XCTUnwrap(commands.filterLayers.first)
        XCTAssertEqual(commands.filterLayers.count, 1)
        XCTAssertEqual(filter.region, LayerTree.Rect(x: 21, y: 21, width: 48, height: 48))
        XCTAssertEqual(filter.effects, [.gaussianBlur(stdDeviation: 5, stdDeviationY: 5)])
        XCTAssertEqual(commands.names, ["pushFilterLayer", "setFillColor", "fillPath", "popFilterLayer"])
    }

    func testBlurTwoValuesAndUserSpaceRegion() throws {
        let commands = try makeCommands(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="blur" filterUnits="userSpaceOnUse" x="0" y="10" width="90" height="80">
                <feGaussianBlur stdDeviation="4 2" />
            </filter>
            <rect x="25" y="25" width="50" height="50" filter="url(#blur)" />
        </svg>
        """#)

        let filter = try XCTUnwrap(commands.filterLayers.first)
        XCTAssertEqual(filter.region, LayerTree.Rect(x: 0, y: 10, width: 90, height: 80))
        XCTAssertEqual(filter.effects, [.gaussianBlur(stdDeviation: 4, stdDeviationY: 2)])
    }

    func testPrimitiveUnitsObjectBoundingBoxScalesDeviation() throws {
        let commands = try makeCommands(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="blur" primitiveUnits="objectBoundingBox" x="0" y="0" width="1" height="1">
                <feGaussianBlur stdDeviation="0.1" />
            </filter>
            <rect x="0" y="0" width="50" height="20" filter="url(#blur)" />
        </svg>
        """#)

        let filter = try XCTUnwrap(commands.filterLayers.first)
        XCTAssertEqual(filter.region, LayerTree.Rect(x: 0, y: 0, width: 50, height: 20))
        XCTAssertEqual(filter.effects, [.gaussianBlur(stdDeviation: 5, stdDeviationY: 2)])
    }

    func testNegativeDeviationDisablesBlur() throws {
        let commands = try makeCommands(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="blur"><feGaussianBlur stdDeviation="-3" /></filter>
            <rect x="0" y="0" width="50" height="50" filter="url(#blur)" />
        </svg>
        """#)

        XCTAssertEqual(commands.filterLayers.first?.effects, [.gaussianBlur(stdDeviation: 0, stdDeviationY: 0)])
    }

    func testFilterRegionIncludesChildTransforms() throws {
        let commands = try makeCommands(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="blur" x="0" y="0" width="1" height="1"><feGaussianBlur stdDeviation="1" /></filter>
            <g filter="url(#blur)">
                <rect x="0" y="0" width="10" height="10" />
                <rect x="0" y="0" width="10" height="10" transform="translate(30, 40)" />
            </g>
        </svg>
        """#)

        XCTAssertEqual(commands.filterLayers.first?.region, LayerTree.Rect(x: 0, y: 0, width: 40, height: 50))
    }

    func testFilterIsNotInheritedByChildren() throws {
        let commands = try makeCommands(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="blur"><feGaussianBlur stdDeviation="2" /></filter>
            <g filter="url(#blur)">
                <rect x="0" y="0" width="10" height="10" />
                <rect x="20" y="0" width="10" height="10" />
            </g>
        </svg>
        """#)

        XCTAssertEqual(commands.filterLayers.count, 1)
    }

    func testEmptyFilterRegionDrawsNothing() throws {
        let commands = try makeCommands(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="blur"><feGaussianBlur stdDeviation="2" /></filter>
            <line x1="0" y1="10" x2="100" y2="10" stroke="black" filter="url(#blur)" />
        </svg>
        """#)

        XCTAssertEqual(commands.names, [])
    }

    func testUnsupportedPrimitiveDrawsUnfiltered() throws {
        let commands = try makeCommands(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="shadow">
                <feGaussianBlur in="SourceAlpha" stdDeviation="2" />
                <feOffset dx="2" dy="2" />
            </filter>
            <rect x="0" y="0" width="10" height="10" filter="url(#shadow)" />
        </svg>
        """#)

        XCTAssertEqual(commands.names, ["setFillColor", "fillPath"])
    }

    func testUnsupportedPrimitiveIsHiddenWithOption() throws {
        let commands = try makeCommands(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="offset"><feOffset dx="2" dy="2" /></filter>
            <rect x="0" y="0" width="10" height="10" filter="url(#offset)" />
            <rect x="20" y="0" width="10" height="10" />
        </svg>
        """#, options: .hideUnsupportedFilters)

        XCTAssertEqual(commands.names, ["setFillColor", "fillPath"])
    }

    func testFilterIsAppliedBeforeOpacityClipAndMask() throws {
        let commands = try makeCommands(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="blur"><feGaussianBlur stdDeviation="2" /></filter>
            <clipPath id="clip"><rect x="0" y="0" width="50" height="100" /></clipPath>
            <mask id="mask"><rect x="0" y="0" width="100" height="100" fill="white" /></mask>
            <rect x="10" y="10" width="80" height="80" opacity="0.5" clip-path="url(#clip)" mask="url(#mask)" filter="url(#blur)" />
        </svg>
        """#)

        XCTAssertEqual(commands.names, [
            "pushState", "setAlpha", "pushTransparencyLayer", "setClip", "pushTransparencyLayer",
            "pushFilterLayer", "setFillColor", "fillPath", "popFilterLayer",
            "setBlendMode", "pushTransparencyLayer", "setBlendMode", "setFillColor", "fillPath",
            "popTransparencyLayer", "popTransparencyLayer",
            "popTransparencyLayer", "popState"
        ])
    }

    func testNestedFilterLayers() throws {
        let commands = try makeCommands(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="blur"><feGaussianBlur stdDeviation="2" /></filter>
            <g filter="url(#blur)">
                <rect x="10" y="10" width="20" height="20" filter="url(#blur)" />
                <rect x="50" y="50" width="20" height="20" />
            </g>
        </svg>
        """#)

        XCTAssertEqual(commands.names, [
            "pushFilterLayer", "pushFilterLayer", "setFillColor", "fillPath", "popFilterLayer",
            "setFillColor", "fillPath", "popFilterLayer"
        ])
    }

    // text has no measured bounds: drawn unfiltered, neither warned about nor hidden as unsupported
    func testTextWithObjectBoundingBoxBlurIsDrawnUnfiltered() throws {
        let svg = try DOM.SVG.parse(xml: #"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="blur"><feGaussianBlur stdDeviation="2" /></filter>
            <text x="10" y="50" filter="url(#blur)">Hi</text>
        </svg>
        """#)
        let root = LayerTree.Builder(svg: svg).makeLayer()
        let layer = try XCTUnwrap(root.allLayers.first { !$0.filters.isEmpty })
        let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(), size: .init(100, 100), options: .hideUnsupportedFilters)

        XCTAssertFalse(layer.hasUnsupportedFilters)
        XCTAssertNil(generator.makeFilterLayer(for: layer))
    }

    // a group mixing shapes and text has unknown bounds: draw it unfiltered rather than clip the text away
    func testGroupWithTextIsDrawnUnfiltered() throws {
        let commands = try makeCommands(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="blur"><feGaussianBlur stdDeviation="2" /></filter>
            <g filter="url(#blur)">
                <rect x="10" y="10" width="10" height="10" />
                <text x="10" y="80">Hello</text>
            </g>
        </svg>
        """#, options: .hideUnsupportedFilters)

        XCTAssertTrue(commands.filterLayers.isEmpty)
        XCTAssertEqual(commands.names.prefix(2), ["setFillColor", "fillPath"])
    }

    func testGroupWithTextKeepsUserSpaceFilter() throws {
        let commands = try makeCommands(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="blur" filterUnits="userSpaceOnUse" x="0" y="0" width="100" height="100">
                <feGaussianBlur stdDeviation="2" />
            </filter>
            <g filter="url(#blur)">
                <rect x="10" y="10" width="10" height="10" />
                <text x="10" y="80">Hello</text>
            </g>
        </svg>
        """#)

        XCTAssertEqual(commands.filterLayers.first?.region, LayerTree.Rect(x: 0, y: 0, width: 100, height: 100))
    }

    func testHugeDeviationStaysFinite() throws {
        let commands = try makeCommands(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="blur" primitiveUnits="objectBoundingBox"><feGaussianBlur stdDeviation="1e38" /></filter>
            <rect x="0" y="0" width="50" height="50" filter="url(#blur)" />
        </svg>
        """#)

        let effect = try XCTUnwrap(commands.filterLayers.first?.effects.first)
        guard case let .gaussianBlur(x, y) = effect else { return XCTFail() }
        XCTAssertTrue(x.isFinite)
        XCTAssertTrue(y?.isFinite == true)
    }

    // renderers isolate a filter layer, but the optimizer does not elide state after it
    func testOptimizerResetsStateAroundFilterLayer() {
        let filter = LayerTree.FilterLayer(region: .init(x: 0, y: 0, width: 10, height: 10),
                                           effects: [.gaussianBlur(stdDeviation: 1, stdDeviationY: 1)])
        let commands: [RendererCommand<LayerTreeTypes>] = [
            .setFill(color: .black),
            .pushFilterLayer(filter),
            .setFill(color: .black),
            .popFilterLayer,
            .setFill(color: .black)
        ]

        let optimized = LayerTree.CommandOptimizer<LayerTreeTypes>().optimizeCommands(commands)
        XCTAssertEqual(optimized.names, ["setFillColor", "pushFilterLayer", "setFillColor", "popFilterLayer", "setFillColor"])
    }
}

private extension LayerTreeFilterTests {

    func makeCommands(_ xml: String, options: SVG.Options = .default) throws -> [RendererCommand<LayerTreeTypes>] {
        let svg = try DOM.SVG.parse(xml: xml)
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(),
                                                   size: .init(100, 100),
                                                   options: options)
        let commands = generator.renderCommands(for: layer, colorConverter: .default)
        return LayerTree.CommandOptimizer<LayerTreeTypes>().optimizeCommands(commands)
    }
}

private extension Array where Element == RendererCommand<LayerTreeTypes> {

    var filterLayers: [LayerTree.FilterLayer] {
        compactMap {
            if case .pushFilterLayer(let filter) = $0 { return filter }
            return nil
        }
    }

    var names: [String] {
        let renderer = MockRenderer()
        renderer.perform(self)
        return renderer.operations
    }
}

private extension LayerTree.Layer {

    var allLayers: [LayerTree.Layer] {
        [self] + contents.flatMap { contents -> [LayerTree.Layer] in
            if case .layer(let layer) = contents { return layer.allLayers }
            return []
        }
    }
}
