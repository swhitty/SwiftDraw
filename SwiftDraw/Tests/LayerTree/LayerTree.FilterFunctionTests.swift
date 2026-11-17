//
//  LayerTree.FilterFunctionTests.swift
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


@testable import SwiftDrawDOM
@testable import SwiftDraw
import Foundation
import Testing

// Filter Effects 1 §12: filter functions resolve into the primitives they are equivalent to, in sRGB
struct LayerTreeFilterFunctionTests {

    typealias Primitive = LayerTree.FilterLayer.Primitive

    // blur and drop-shadow take a region of bbox -50% / 200%, the other functions the default -10% / 120%
    static let blurRegion = LayerTree.Rect(x: -30, y: -30, width: 200, height: 200)
    static let region = LayerTree.Rect(x: 10, y: 10, width: 120, height: 120)

    @Test(arguments: [
        ("blur(4)", 4),
        ("blur()", 0),
        ("blur(1mm)", 96 / 25.4),
        ("blur(0.5em)", 5),
        ("blur(1ex)", 5)
    ] as [(String, Float)])
    func blur(function: String, stdDeviation: Float) throws {
        let filter = try #require(makeFilterLayers(rect: function).first)
        #expect(filter.region == Self.blurRegion)
        #expect(filter.primitives == [
            Primitive(effect: .gaussianBlur(stdDeviation: stdDeviation, stdDeviationY: stdDeviation),
                      inputs: [.sourceGraphic], subregion: Self.blurRegion, colorInterpolation: .sRGB)
        ])
    }

    @Test(arguments: [
        ("hue-rotate(90deg)", DOM.Filter.ColorMatrix.hueRotate(90).values),
        ("saturate(2)", DOM.Filter.ColorMatrix.saturate(2).values),
        ("grayscale()", DOM.Filter.ColorMatrix.saturate(0).values),
        ("grayscale(25%)", DOM.Filter.ColorMatrix.saturate(0.75).values),
        // amounts over 1 are clamped
        ("grayscale(2)", DOM.Filter.ColorMatrix.saturate(0).values),
        ("sepia()", [0.393, 0.769, 0.189, 0, 0,
                     0.349, 0.686, 0.168, 0, 0,
                     0.272, 0.534, 0.131, 0, 0,
                     0, 0, 0, 1, 0]),
        ("sepia(0)", DOM.Filter.ColorMatrix.identity)
    ] as [(String, [Float])])
    func colorMatrix(function: String, matrix: [Float]) throws {
        let filter = try #require(makeFilterLayers(rect: function).first)
        #expect(filter.region.isClose(to: Self.region))
        #expect(filter.primitives.count == 1)
        let primitive = try #require(filter.primitives.first)
        #expect(primitive.inputs == [.sourceGraphic])
        #expect(primitive.colorInterpolation == .sRGB)
        guard case .colorMatrix(let values) = primitive.effect else {
            Issue.record("expected a color matrix")
            return
        }
        #expect(values.count == 20)
        for (value, expected) in zip(values, matrix) {
            #expect(abs(value - expected) < 0.0001)
        }
    }

    // Filter Effects 1 §12.2: the functions defined by feComponentTransfer
    @Test(arguments: [
        ("invert()", colors(.table([1, 0]))),
        ("invert(25%)", colors(.table([0.25, 0.75]))),
        // amounts over 1 are clamped
        ("invert(2)", colors(.table([1, 0]))),
        ("opacity(0.5)", DOM.Filter.ComponentTransfer(a: .table([0, 0.5]))),
        ("opacity(2)", DOM.Filter.ComponentTransfer(a: .table([0, 1]))),
        ("brightness(2)", colors(.linear(slope: 2, intercept: 0))),
        ("brightness()", colors(.linear(slope: 1, intercept: 0))),
        ("contrast(2)", colors(.linear(slope: 2, intercept: -0.5))),
        ("contrast()", colors(.linear(slope: 1, intercept: 0)))
    ] as [(String, DOM.Filter.ComponentTransfer)])
    func componentTransfer(function: String, transfer: DOM.Filter.ComponentTransfer) throws {
        let filter = try #require(makeFilterLayers(rect: function).first)
        #expect(filter.region.isClose(to: Self.region))
        #expect(filter.primitives == [
            Primitive(effect: .componentTransfer(transfer), inputs: [.sourceGraphic],
                      subregion: filter.region, colorInterpolation: .sRGB)
        ])
    }

    static func colors(_ function: DOM.Filter.TransferFunction) -> DOM.Filter.ComponentTransfer {
        DOM.Filter.ComponentTransfer(r: function, g: function, b: function)
    }

    @Test(arguments: [
        // no color takes `color`, as does currentColor
        ("drop-shadow(10 20)", "blue", LayerTree.Color.rgba(r: 0, g: 0, b: 1, a: 1, space: .srgb), 10, 20, 0),
        ("drop-shadow(currentColor 10 20 3)", "blue", .rgba(r: 0, g: 0, b: 1, a: 1, space: .srgb), 10, 20, 3),
        ("drop-shadow(10 20)", nil, .rgba(r: 0, g: 0, b: 0, a: 1, space: .srgb), 10, 20, 0),
        ("drop-shadow(red 1em 2em 0.5em)", nil, .rgba(r: 1, g: 0, b: 0, a: 1, space: .srgb), 10, 20, 5),
        ("drop-shadow(-1 -2 1 rgba(255, 0, 0, 0.5))", "blue", .rgba(r: 1, g: 0, b: 0, a: 0.5, space: .srgb), -1, -2, 1)
    ] as [(String, String?, LayerTree.Color, Float, Float, Float)])
    func dropShadow(function: String, color: String?, flood: LayerTree.Color, dx: Float, dy: Float, stdDeviation: Float) throws {
        let attribute = color.map { #"color="\#($0)" "# } ?? ""
        let filter = try #require(makeFilterLayers(rect: function, attributes: attribute).first)
        let region = Self.blurRegion
        #expect(filter.region == region)
        #expect(filter.primitives == [
            Primitive(effect: .gaussianBlur(stdDeviation: stdDeviation, stdDeviationY: stdDeviation), inputs: [.sourceGraphic],
                      subregion: region, colorInterpolation: .sRGB),
            Primitive(effect: .offset(dx: dx, dy: dy), inputs: [.primitive(0)],
                      subregion: region, colorInterpolation: .sRGB),
            Primitive(effect: .flood(flood), inputs: [],
                      subregion: region, colorInterpolation: .sRGB),
            Primitive(effect: .composite(.in), inputs: [.primitive(2), .primitive(1)],
                      subregion: region, colorInterpolation: .sRGB),
            Primitive(effect: .merge, inputs: [.primitive(3), .sourceGraphic],
                      subregion: region, colorInterpolation: .sRGB)
        ])
    }

    // each entry is a filter layer of its own, the first innermost: pushed last
    @Test
    func listAppliesInOrder() throws {
        let filters = try makeFilterLayers(rect: "url(#f) grayscale() blur(2)", defs: #"""
            <filter id="f" filterUnits="userSpaceOnUse" x="0" y="0" width="50" height="60">
                <feOffset dx="1" dy="2" />
            </filter>
        """#)
        #expect(filters.count == 3)
        #expect(filters[0].region == Self.blurRegion)
        #expect(filters[1].region.isClose(to: Self.region))
        #expect(filters[2].region == LayerTree.Rect(x: 0, y: 0, width: 50, height: 60))
        #expect(filters.map { $0.effects.first } == [
            .gaussianBlur(stdDeviation: 2, stdDeviationY: 2),
            .colorMatrix(DOM.Filter.ColorMatrix.saturate(0).values),
            .offset(dx: 1, dy: 2)
        ])
    }

    @Test
    func singleURLIsOneLayer() throws {
        let commands = try makeCommands(rect: "url(#f)", defs: #"<filter id="f"><feOffset dx="1" /></filter>"#)
        #expect(commands.filterLayers.count == 1)
        #expect(commands.fills == 1)
    }

    // resvg: a url() to a missing filter is skipped, unless nothing else is left
    @Test
    func missingURLInListIsSkipped() throws {
        let commands = try makeCommands(rect: "url(#missing) opacity(0.5)")
        #expect(commands.filterLayers.map { $0.effects.first } == [
            .componentTransfer(DOM.Filter.ComponentTransfer(a: .table([0, 0.5])))
        ])
        #expect(commands.fills == 1)
    }

    @Test(arguments: ["url(#missing)", "url(#missing) url(#other)"])
    func missingURLsAreNotRendered(filter: String) throws {
        let commands = try makeCommands(rect: filter)
        #expect(commands.filterLayers.isEmpty)
        #expect(commands.fills == 0)
    }

    // an invalid value is ignored: the element is drawn unfiltered
    @Test(arguments: ["blur(-5)", "drop-shadow(blue 4 5 6 7)", "grayscale() hue-rotate(random)", "url(#missing) blur(50%)"])
    func invalidValueIsIgnored(filter: String) throws {
        let commands = try makeCommands(rect: filter)
        #expect(commands.filterLayers.isEmpty)
        #expect(commands.fills == 1)
    }

    // `none` overrides a lower rule; a stylesheet rule overrides the attribute
    @Test
    func noneOverridesStylesheet() throws {
        let commands = try makeCommands(rect: "invert()", defs: "<style>rect { filter: blur(2) }</style>",
                                        attributes: #"style="filter: none" "#)
        #expect(commands.filterLayers.isEmpty)
        #expect(commands.fills == 1)

        let styled = try makeCommands(rect: "none", defs: "<style>rect { filter: invert() }</style>")
        #expect(styled.filterLayers.count == 1)
    }

    @Test
    func groupWithFilterList() throws {
        let commands = try makeCommands(#"""
        <svg width="200" height="200" xmlns="http://www.w3.org/2000/svg">
            <g filter="sepia() blur(1)" opacity="0.5" transform="translate(5, 5)">
                <rect x="20" y="20" width="100" height="100" />
                <rect x="20" y="20" width="100" height="100" />
            </g>
        </svg>
        """#)
        #expect(commands.filterLayers.count == 2)
        #expect(commands.fills == 2)
    }
}

private extension LayerTreeFilterFunctionTests {

    func makeCommands(_ xml: String) throws -> [RendererCommand<LayerTreeTypes>] {
        let svg = try DOM.SVG.parse(xml: xml)
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(),
                                                   size: .init(svg.width, svg.height),
                                                   options: .default)
        return generator.renderCommands(for: layer, colorConverter: .default)
    }

    // a 100×100 rect at 20, 20 with font-size 10
    func makeCommands(rect filter: String, defs: String = "", attributes: String = "") throws -> [RendererCommand<LayerTreeTypes>] {
        try makeCommands(#"""
        <svg width="200" height="200" xmlns="http://www.w3.org/2000/svg">
            \#(defs)
            <rect x="20" y="20" width="100" height="100" font-size="10" \#(attributes)filter="\#(filter)" />
        </svg>
        """#)
    }

    func makeFilterLayers(rect filter: String, defs: String = "", attributes: String = "") throws -> [LayerTree.FilterLayer] {
        try makeCommands(rect: filter, defs: defs, attributes: attributes).filterLayers
    }
}

private extension LayerTree.Rect {
    func isClose(to other: LayerTree.Rect) -> Bool {
        abs(x - other.x) < 0.001 && abs(y - other.y) < 0.001 &&
            abs(width - other.width) < 0.001 && abs(height - other.height) < 0.001
    }
}

private extension Array where Element == RendererCommand<LayerTreeTypes> {

    var filterLayers: [LayerTree.FilterLayer] {
        compactMap {
            if case .pushFilterLayer(let filter) = $0 { return filter }
            return nil
        }
    }

    var fills: Int {
        filter {
            if case .fill = $0 { return true }
            return false
        }.count
    }
}
