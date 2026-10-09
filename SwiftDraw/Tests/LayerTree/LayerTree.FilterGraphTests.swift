//
//  LayerTree.FilterGraphTests.swift
//  SwiftDraw
//
//  Created by Misoservices on 9/10/26.
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

// SD12: filter primitive trees resolved into LayerTree.FilterLayer
final class LayerTreeFilterGraphTests: XCTestCase {

    typealias Primitive = LayerTree.FilterLayer.Primitive

    // Inkscape 1.x Filters ▸ Shadows and Glows ▸ Drop Shadow
    func testInkscapeDropShadow() throws {
        let filter = try makeFilterLayer(#"""
        <svg width="200" height="200" xmlns="http://www.w3.org/2000/svg">
            <filter style="color-interpolation-filters:sRGB" id="filter1" x="-0.1" y="-0.1" width="1.2" height="1.2">
                <feFlood flood-opacity="0.498039" flood-color="rgb(0,0,0)" result="flood" />
                <feComposite in="flood" in2="SourceGraphic" operator="in" result="composite1" />
                <feGaussianBlur in="composite1" stdDeviation="3" result="blur" />
                <feOffset dx="6" dy="6" result="offset" />
                <feComposite in="SourceGraphic" in2="offset" operator="over" result="composite2" />
            </filter>
            <rect x="10" y="10" width="100" height="50" filter="url(#filter1)" />
        </svg>
        """#)

        let region = filter.region
        XCTAssertEqual(region.x, 0, accuracy: 0.001)
        XCTAssertEqual(region.y, 5, accuracy: 0.001)
        XCTAssertEqual(region.width, 120, accuracy: 0.001)
        XCTAssertEqual(region.height, 60, accuracy: 0.001)
        XCTAssertEqual(filter.primitives, [
            Primitive(effect: .flood(.rgba(r: 0, g: 0, b: 0, a: 0.498039, space: .srgb)),
                      inputs: [], subregion: region, colorInterpolation: .sRGB),
            Primitive(effect: .composite(.in), inputs: [.primitive(0), .sourceGraphic],
                      subregion: region, colorInterpolation: .sRGB),
            Primitive(effect: .gaussianBlur(stdDeviation: 3, stdDeviationY: 3), inputs: [.primitive(1)],
                      subregion: region, colorInterpolation: .sRGB),
            Primitive(effect: .offset(dx: 6, dy: 6), inputs: [.primitive(2)],
                      subregion: region, colorInterpolation: .sRGB),
            Primitive(effect: .composite(.over), inputs: [.sourceGraphic, .primitive(3)],
                      subregion: region, colorInterpolation: .sRGB)
        ])
        XCTAssertFalse(filter.isBlurChain)
    }

    // Illustrator's AI_Shadow: no color-interpolation-filters, so linearRGB
    func testIllustratorShadow() throws {
        let filter = try makeFilterLayer(#"""
        <svg width="200" height="200" xmlns="http://www.w3.org/2000/svg">
            <filter id="AI_Shadow_1" filterUnits="objectBoundingBox">
                <feGaussianBlur in="SourceAlpha" stdDeviation="2" result="blur" />
                <feOffset dx="4" dy="4" in="blur" result="offsetBlurredAlpha" />
                <feMerge>
                    <feMergeNode in="offsetBlurredAlpha" />
                    <feMergeNode in="SourceGraphic" />
                </feMerge>
            </filter>
            <rect x="0" y="0" width="100" height="100" filter="url(#AI_Shadow_1)" />
        </svg>
        """#)

        XCTAssertEqual(filter.effects, [
            .gaussianBlur(stdDeviation: 2, stdDeviationY: 2),
            .offset(dx: 4, dy: 4),
            .merge
        ])
        XCTAssertEqual(filter.primitives.map(\.inputs), [[.sourceAlpha], [.primitive(0)], [.primitive(1), .sourceGraphic]])
        XCTAssertEqual(Set(filter.primitives.map(\.colorInterpolation)), [.linearRGB])
    }

    // Figma's drop shadow: a transparent BackgroundImageFix flood, a hard alpha from SourceAlpha, implicit inputs
    func testFigmaDropShadow() throws {
        let filter = try makeFilterLayer(#"""
        <svg width="108" height="108" xmlns="http://www.w3.org/2000/svg">
            <filter id="filter0_d" x="0" y="0" width="108" height="108" filterUnits="userSpaceOnUse" color-interpolation-filters="sRGB">
                <feFlood flood-opacity="0" result="BackgroundImageFix"/>
                <feColorMatrix in="SourceAlpha" type="matrix" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0" result="hardAlpha"/>
                <feOffset dy="4"/>
                <feGaussianBlur stdDeviation="2"/>
                <feComposite in2="hardAlpha" operator="out"/>
                <feColorMatrix type="matrix" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0.25 0"/>
                <feBlend mode="normal" in2="BackgroundImageFix" result="effect1_dropShadow"/>
                <feBlend mode="normal" in="SourceGraphic" in2="effect1_dropShadow" result="shape"/>
            </filter>
            <rect x="4" y="0" width="100" height="100" fill="white" filter="url(#filter0_d)" />
        </svg>
        """#)

        XCTAssertEqual(filter.region, LayerTree.Rect(x: 0, y: 0, width: 108, height: 108))
        XCTAssertEqual(filter.effects, [
            .flood(.rgba(r: 0, g: 0, b: 0, a: 0, space: .srgb)),
            .colorMatrix([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 127, 0]),
            .offset(dx: 0, dy: 4),
            .gaussianBlur(stdDeviation: 2, stdDeviationY: 2),
            .composite(.out),
            .colorMatrix([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.25, 0]),
            .blend(.normal),
            .blend(.normal)
        ])
        XCTAssertEqual(filter.primitives.map(\.inputs), [
            [],
            [.sourceAlpha],
            [.primitive(1)],
            [.primitive(2)],
            [.primitive(3), .primitive(1)],
            [.primitive(4)],
            [.primitive(5), .primitive(0)],
            [.sourceGraphic, .primitive(6)]
        ])
    }

    // Filter Effects 1 §9.2: missing, forward and unknown references take the previous result
    func testInputReferences() {
        func primitive(_ inputs: [DOM.Filter.Input?], result: String? = nil) -> DOM.Filter.Primitive {
            DOM.Filter.Primitive(effect: .merge, inputs: inputs, result: result)
        }
        let inputs = LayerTree.FilterLayer.makeInputs(for: [
            primitive([nil], result: "a"),
            primitive([.result("later")], result: "a"),
            primitive([.result("a"), .result("missing")], result: "later"),
            primitive([.backgroundImage, .backgroundAlpha, .fillPaint, .strokePaint]),
            primitive([.sourceGraphic, .sourceAlpha, .result("later"), nil])
        ])

        XCTAssertEqual(inputs, [
            [.sourceGraphic],
            [.primitive(0)],
            // the closest preceding "a"
            [.primitive(1), .primitive(1)],
            [.transparent, .transparent, .transparent, .transparent],
            [.sourceGraphic, .sourceAlpha, .primitive(2), .primitive(3)]
        ])
    }

    // Filter Effects 1 §9.3: only the tree rooted at the last primitive is evaluated
    func testOnlyThePrimaryTreeIsKept() throws {
        let filter = try makeFilterLayer(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="f">
                <feColorMatrix type="hueRotate" values="45" />
                <feOffset dx="10" dy="10" />
                <feGaussianBlur stdDeviation="3" />
                <feFlood flood-color="green" result="flood" />
                <feComposite operator="in" in="SourceAlpha" in2="flood" />
            </filter>
            <rect x="10" y="10" width="50" height="50" filter="url(#f)" />
        </svg>
        """#)

        XCTAssertEqual(filter.effects, [
            .flood(.rgba(r: 0, g: Float(128) / 255, b: 0, a: 1, space: .srgb)),
            .composite(.in)
        ])
        XCTAssertEqual(filter.primitives.map(\.inputs), [[], [.sourceAlpha, .primitive(0)]])
    }

    // an unsupported primitive outside the primary tree is never drawn, so the filter still applies
    func testUnsupportedPrimitiveOutsidePrimaryTree() throws {
        let commands = try makeCommands(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="f">
                <feTurbulence baseFrequency="0.1" result="noise" />
                <feOffset in="SourceGraphic" dx="2" />
            </filter>
            <rect x="10" y="10" width="50" height="50" filter="url(#f)" />
        </svg>
        """#, options: .hideUnsupportedFilters)

        XCTAssertEqual(commands.filterLayers.first?.effects, [.offset(dx: 2, dy: 0)])
        XCTAssertEqual(commands.names, ["pushFilterLayer", "setFillColor", "fillPath", "popFilterLayer"])
    }

    func testUnsupportedPrimitiveInPrimaryTreeDrawsUnfiltered() throws {
        let commands = try makeCommands(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="f">
                <feOffset dx="2" result="o" />
                <feMorphology in="o" radius="2" />
            </filter>
            <rect x="10" y="10" width="50" height="50" filter="url(#f)" />
        </svg>
        """#)

        XCTAssertEqual(commands.names, ["setFillColor", "fillPath"])
    }

    // Filter Effects 1 §9.4: x, y, width, height in user units, the rest from the default subregion,
    // all within the filter region
    func testSubregionInUserSpace() throws {
        let filter = try makeFilterLayer(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="f" filterUnits="userSpaceOnUse" x="0" y="0" width="100" height="100">
                <feFlood flood-color="red" x="10" width="30" result="a" />
                <feFlood flood-color="red" x="80" y="-20" width="50" height="50%" result="b" />
                <feMerge><feMergeNode in="a" /><feMergeNode in="b" /></feMerge>
            </filter>
            <rect x="10" y="10" width="50" height="50" filter="url(#f)" />
        </svg>
        """#)

        XCTAssertEqual(filter.primitives.map(\.subregion), [
            LayerTree.Rect(x: 10, y: 0, width: 30, height: 100),
            // 50% of the viewport height, clipped to the filter region
            LayerTree.Rect(x: 80, y: 0, width: 20, height: 30),
            LayerTree.Rect(x: 10, y: 0, width: 90, height: 100)
        ])
    }

    func testSubregionInBoundingBoxUnits() throws {
        let filter = try makeFilterLayer(#"""
        <svg width="200" height="200" xmlns="http://www.w3.org/2000/svg">
            <filter id="f" primitiveUnits="objectBoundingBox">
                <feFlood flood-color="green" x="25%" y="25%" width="50%" height="50%" />
                <feOffset dx="0.1" dy="0.5" />
            </filter>
            <rect x="0" y="100" width="200" height="40" filter="url(#f)" />
        </svg>
        """#)

        let flood = LayerTree.Rect(x: 50, y: 110, width: 100, height: 20)
        XCTAssertEqual(filter.primitives.map(\.subregion), [flood, flood])
        XCTAssertEqual(filter.primitives[1].effect, .offset(dx: 20, dy: 20))
    }

    // the default subregion of a primitive reading only results is the union of theirs
    func testSubregionDefaultsToUnionOfInputs() throws {
        let filter = try makeFilterLayer(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="f" filterUnits="userSpaceOnUse" x="0" y="0" width="100" height="100">
                <feFlood x="10" y="10" width="10" height="10" result="a" />
                <feFlood x="50" y="60" width="10" height="10" result="b" />
                <feMerge><feMergeNode in="a" /><feMergeNode in="b" /></feMerge>
                <feMerge><feMergeNode /><feMergeNode in="SourceGraphic" /></feMerge>
            </filter>
            <rect x="10" y="10" width="50" height="50" filter="url(#f)" />
        </svg>
        """#)

        XCTAssertEqual(filter.primitives.map(\.subregion), [
            LayerTree.Rect(x: 10, y: 10, width: 10, height: 10),
            LayerTree.Rect(x: 50, y: 60, width: 10, height: 10),
            LayerTree.Rect(x: 10, y: 10, width: 50, height: 60),
            // SourceGraphic is a standard input: the filter region
            LayerTree.Rect(x: 0, y: 0, width: 100, height: 100)
        ])
    }

    // zero or negative sizes, or no overlap with the filter region, disable the primitive
    func testEmptySubregionDisablesPrimitive() throws {
        let filter = try makeFilterLayer(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="f" filterUnits="userSpaceOnUse" x="0" y="0" width="100" height="100">
                <feFlood width="0" result="a" />
                <feFlood height="-5" result="b" />
                <feFlood x="200" result="c" />
                <feMerge><feMergeNode in="a" /><feMergeNode in="b" /><feMergeNode in="c" /></feMerge>
            </filter>
            <rect x="10" y="10" width="50" height="50" filter="url(#f)" />
        </svg>
        """#)

        XCTAssertEqual(filter.primitives.map(\.subregion), [.zero, .zero, .zero, .zero])
    }

    func testFloodColorAndOpacity() throws {
        let filter = try makeFilterLayer(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="f"><feFlood flood-color="rgba(255, 0, 0, 0.5)" flood-opacity="0.5" /></filter>
            <rect x="10" y="10" width="50" height="50" filter="url(#f)" />
        </svg>
        """#)

        XCTAssertEqual(filter.effects, [.flood(.rgba(r: 1, g: 0, b: 0, a: 0.25, space: .srgb))])
    }

    func testColorMatrixTypesResolveToMatrices() {
        let identity = DOM.Filter.ColorMatrix.identity
        XCTAssertEqual(DOM.Filter.ColorMatrix.saturate(1).values, identity)
        XCTAssertEqual(DOM.Filter.ColorMatrix.matrix([1, 2]).values, identity)
        for (value, expected) in zip(DOM.Filter.ColorMatrix.hueRotate(0).values, identity) {
            XCTAssertEqual(value, expected, accuracy: 0.0001)
        }
        for (value, expected) in zip(DOM.Filter.ColorMatrix.hueRotate(360).values, identity) {
            XCTAssertEqual(value, expected, accuracy: 0.0001)
        }
        // saturate(0) is a grey: each row is the luminance
        XCTAssertEqual(Array(DOM.Filter.ColorMatrix.saturate(0).values[0..<3]), [0.2126, 0.7152, 0.0722])
        XCTAssertEqual(Array(DOM.Filter.ColorMatrix.saturate(0).values[5..<8]), [0.2126, 0.7152, 0.0722])
        XCTAssertEqual(DOM.Filter.ColorMatrix.luminanceToAlpha.values,
                       [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.2126, 0.7152, 0.0722, 0, 0])
    }

    func testFloodGoesThroughColorConverter() throws {
        let svg = try DOM.SVG.parse(xml: #"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="f"><feFlood flood-color="white" /></filter>
            <rect x="10" y="10" width="50" height="50" filter="url(#f)" />
        </svg>
        """#)
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let filtered = try XCTUnwrap(layer.allLayers.first { !$0.filters.isEmpty })
        let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(), size: .init(100, 100), options: .default)
        let filter = try XCTUnwrap(generator.makeFilterLayer(for: filtered, colorConverter: .luminance))

        guard case .flood(.gray(white: 0, a: let alpha)) = try XCTUnwrap(filter.effects.first) else {
            return XCTFail("expected a luminance flood")
        }
        XCTAssertEqual(alpha, 1, accuracy: 0.0001)
    }

    // SD2's blur chains keep their in-place path; anything else is a primitive tree
    func testBlurChain() throws {
        let chain = try makeFilterLayer(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="f">
                <feGaussianBlur stdDeviation="1" result="a" />
                <feGaussianBlur in="a" stdDeviation="2" />
            </filter>
            <rect x="10" y="10" width="50" height="50" filter="url(#f)" />
        </svg>
        """#)
        let alpha = try makeFilterLayer(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="f"><feGaussianBlur in="SourceAlpha" stdDeviation="1" /></filter>
            <rect x="10" y="10" width="50" height="50" filter="url(#f)" />
        </svg>
        """#)
        let subregion = try makeFilterLayer(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="f"><feGaussianBlur stdDeviation="1" x="20" /></filter>
            <rect x="10" y="10" width="50" height="50" filter="url(#f)" />
        </svg>
        """#)

        XCTAssertTrue(chain.isBlurChain)
        XCTAssertFalse(alpha.isBlurChain)
        XCTAssertFalse(subregion.isBlurChain)
    }

    func testPeakBitmapCount() {
        let region = LayerTree.Rect(x: 0, y: 0, width: 10, height: 10)
        func primitive(_ inputs: [LayerTree.FilterLayer.Input]) -> Primitive {
            Primitive(effect: .merge, inputs: inputs, subregion: region, colorInterpolation: .sRGB)
        }
        // source and one result at a time
        XCTAssertEqual(LayerTree.FilterLayer(region: region, effects: [.offset(dx: 1, dy: 1), .offset(dx: 1, dy: 1)]).peakBitmapCount, 3)
        // two results kept for the merge, SourceAlpha alive until its last reader
        let tree = LayerTree.FilterLayer(region: region, primitives: [
            primitive([.sourceAlpha]),
            primitive([.sourceAlpha]),
            primitive([.primitive(0), .primitive(1), .transparent])
        ])
        XCTAssertEqual(tree.peakBitmapCount, 5)
    }

    // every filter of the samples resolves: none is drawn unfiltered or hidden as unsupported
    func testSamplesResolveEveryFilter() throws {
        let samples = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Samples.bundle")
        for (name, count) in [("filter-drop-shadow", 3), ("filter-primitives", 8)] {
            let xml = try String(contentsOf: samples.appendingPathComponent("\(name).svg"), encoding: .utf8)
            let filters = try makeCommands(xml, options: .hideUnsupportedFilters).filterLayers
            XCTAssertEqual(filters.count, count, name)
            XCTAssertFalse(filters.contains { $0.region.width <= 0 || $0.region.height <= 0 }, name)
        }
    }

    // the merge's region-wide result keeps the whole region in the command stream
    func testFilterLayerCommandsForGraph() throws {
        let commands = try makeCommands(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="f">
                <feOffset in="SourceAlpha" dx="2" dy="2" result="o" />
                <feMerge><feMergeNode in="o" /><feMergeNode in="SourceGraphic" /></feMerge>
            </filter>
            <rect x="10" y="10" width="50" height="50" filter="url(#f)" opacity="0.5" />
        </svg>
        """#)

        XCTAssertEqual(commands.names, [
            "pushState", "setAlpha", "pushTransparencyLayer",
            "pushFilterLayer", "setFillColor", "fillPath", "popFilterLayer",
            "popTransparencyLayer", "popState"
        ])
    }
}

private extension LayerTreeFilterGraphTests {

    func makeCommands(_ xml: String, options: SVG.Options = .default) throws -> [RendererCommand<LayerTreeTypes>] {
        let svg = try DOM.SVG.parse(xml: xml)
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(),
                                                   size: .init(svg.width, svg.height),
                                                   options: options)
        let commands = generator.renderCommands(for: layer, colorConverter: .default)
        return LayerTree.CommandOptimizer<LayerTreeTypes>().optimizeCommands(commands)
    }

    // the first filter layer in the command stream
    func makeFilterLayer(_ xml: String) throws -> LayerTree.FilterLayer {
        try XCTUnwrap(makeCommands(xml).filterLayers.first)
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
