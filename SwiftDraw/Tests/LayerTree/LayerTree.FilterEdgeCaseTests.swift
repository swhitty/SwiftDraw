//
//  LayerTree.FilterEdgeCaseTests.swift
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

// Filter edge cases from the resvg test suite (filters/filter, filters/enable-background, feGaussianBlur,
// feColorMatrix, flood-color), checked against resvg's reference renders
struct LayerTreeFilterEdgeCaseTests {

    typealias Primitive = LayerTree.FilterLayer.Primitive

    // filters/filter/no-children: a filter without primitives paints transparent black
    @Test(arguments: [
        #"<filter id="f"/>"#,
        #"<filter id="f"><desc>no primitives</desc></filter>"#,
    ])
    func filterWithoutPrimitivesHidesTheElement(filter: String) throws {
        let layer = try makeFilterLayer(
            #"""
            <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
                \#(filter)
                <rect x="10" y="10" width="80" height="80" fill="green" filter="url(#f)" />
            </svg>
            """#
        )

        #expect(layer.effects == [.flood(.rgba(r: 0, g: 0, b: 0, a: 0, space: .srgb))])
    }

    // disableFilters still draws the element as if it had no filter
    @Test
    func filterWithoutPrimitivesIsDisabledLikeAnyFilter() throws {
        let commands = try makeCommands(
            #"""
            <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
                <filter id="f"/>
                <rect x="10" y="10" width="80" height="80" fill="green" filter="url(#f)" />
            </svg>
            """#,
            options: .disableFilters
        )

        #expect(commands.filterLayers.isEmpty)
        #expect(
            commands.contains {
                if case .fill = $0 { return true }; return false
            }
        )
    }

    // Figma's no-op prelude on its own is still a filter: it draws the source, it does not hide it
    @Test
    func figmaPreludeAloneIsKept() throws {
        let layer = try makeFilterLayer(
            #"""
            <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
                <filter id="f">
                    <feFlood flood-opacity="0" result="BackgroundImageFix"/>
                    <feBlend mode="normal" in="SourceGraphic" in2="BackgroundImageFix" result="shape"/>
                </filter>
                <rect x="10" y="10" width="80" height="80" fill="green" filter="url(#f)" />
            </svg>
            """#
        )

        #expect(layer.effects == [.flood(.rgba(r: 0, g: 0, b: 0, a: 0, space: .srgb)), .blend(.normal)])
        #expect(layer.primitives[1].inputs == [.sourceGraphic, .primitive(0)])
    }

    // filters/filter/everything-via-xlink-href, complex-order-and-xlink-href: SVG 1.1 §15.5, as resvg
    @Test
    func hrefInheritsPrimitivesAndUnsetAttributes() throws {
        let layer = try makeFilterLayer(
            #"""
            <svg width="200" height="200" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
                <filter id="f0" height="1.0"><feGaussianBlur stdDeviation="2" /></filter>
                <filter id="f1" x="0.1" xlink:href="#f0" />
                <filter id="f2" y="0.2" href="#f1" />
                <rect x="20" y="20" width="160" height="160" filter="url(#f2)" />
            </svg>
            """#
        )

        #expect(layer.effects == [.gaussianBlur(stdDeviation: 2, stdDeviationY: 2)])
        #expect(layer.region == LayerTree.Rect(x: 36, y: 52, width: 192, height: 160))
    }

    @Test
    func ownPrimitivesWinOverHref() throws {
        let layer = try makeFilterLayer(
            #"""
            <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
                <filter id="f0"><feGaussianBlur stdDeviation="2" /></filter>
                <filter id="f1" href="#f0"><feOffset dx="3" /></filter>
                <rect x="10" y="10" width="80" height="80" filter="url(#f1)" />
            </svg>
            """#
        )

        #expect(layer.effects == [.offset(dx: 3, dy: 0)])
    }

    // a cycle ends the chain: no primitives, so the element is hidden
    @Test
    func hrefCycleTerminates() throws {
        let layer = try makeFilterLayer(
            #"""
            <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
                <filter id="a" href="#b" />
                <filter id="b" href="#a" />
                <rect x="10" y="10" width="80" height="80" filter="url(#a)" />
            </svg>
            """#
        )

        #expect(layer.effects == [.flood(.rgba(r: 0, g: 0, b: 0, a: 0, space: .srgb))])
    }

    // filters/filter/in=FillPaint…, in=BackgroundImage, in=BackgroundAlpha, enable-background/*:
    // resvg and WebKit both read the deprecated inputs as SourceGraphic
    @Test(arguments: ["FillPaint", "StrokePaint", "BackgroundImage", "BackgroundAlpha"])
    func deprecatedInputsAreSourceGraphic(input: String) throws {
        let layer = try makeFilterLayer(
            #"""
            <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
                <filter id="f" filterUnits="userSpaceOnUse" x="0" y="0" width="100" height="100">
                    <feOffset in="\#(input)" dx="50" />
                </filter>
                <rect x="10" y="10" width="20" height="20" fill="green" filter="url(#f)" />
            </svg>
            """#
        )

        #expect(layer.primitives.map(\.inputs) == [[.sourceGraphic]])
    }

    // feGaussianBlur/stdDeviation-with-multiple-values: more than two values disable the blur
    @Test(arguments: [
        ("5", LayerTree.FilterLayer.Effect.gaussianBlur(stdDeviation: 5, stdDeviationY: 5)),
        ("5 10", .gaussianBlur(stdDeviation: 5, stdDeviationY: 10)),
        ("5 10 15", .gaussianBlur(stdDeviation: 0, stdDeviationY: 0)),
        ("5 10 15 20", .gaussianBlur(stdDeviation: 0, stdDeviationY: 0)),
    ])
    func stdDeviationValues(value: String, effect: LayerTree.FilterLayer.Effect) throws {
        let layer = try makeFilterLayer(
            #"""
            <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
                <filter id="f"><feGaussianBlur stdDeviation="\#(value)" /></filter>
                <rect x="10" y="10" width="80" height="80" filter="url(#f)" />
            </svg>
            """#
        )

        #expect(layer.effects == [effect])
    }

    // feColorMatrix/invalid-type: an unknown type is the initial `matrix`, as in resvg and WebKit
    @Test
    func unknownColorMatrixTypeAppliesValues() throws {
        let values: [Float] = [-1, 0, 0, 0, 1, 0, -1, 0, 0, 1, 0, 0, -1, 0, 1, -0.21, -0.72, -0.07, 2, 0]
        let layer = try makeFilterLayer(
            #"""
            <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
                <filter id="f">
                    <feColorMatrix type="qwe" values="\#(values.map { "\($0)" }.joined(separator: " "))" />
                    <feColorMatrix type="qwe" values="1 2 3" />
                </filter>
                <rect x="10" y="10" width="80" height="80" filter="url(#f)" />
            </svg>
            """#
        )

        #expect(layer.effects == [.colorMatrix(values), .colorMatrix(DOM.Filter.ColorMatrix.identity)])
    }

    // flood-color/inheritance-3: flood-color is not inherited, but `inherit` takes the <filter>'s value
    @Test(arguments: [
        (
            #"flood-color="green""#, #"flood-color="inherit""#,
            LayerTree.Color.rgba(r: 0, g: Float(128) / 255, b: 0, a: 1, space: .srgb)
        ),
        (#"flood-color="green""#, "", .rgba(r: 0, g: 0, b: 0, a: 1, space: .srgb)),
        ("", #"flood-color="inherit""#, .rgba(r: 0, g: 0, b: 0, a: 1, space: .srgb)),
        (#"flood-opacity="0.5""#, #"flood-opacity="inherit""#, .rgba(r: 0, g: 0, b: 0, a: 0.5, space: .srgb)),
    ])
    func floodInherit(filter: String, flood: String, color: LayerTree.Color) throws {
        let layer = try makeFilterLayer(
            #"""
            <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
                <filter id="f" \#(filter)><feFlood \#(flood) /></filter>
                <rect x="10" y="10" width="80" height="80" fill="red" filter="url(#f)" />
            </svg>
            """#
        )

        #expect(layer.effects == [.flood(color)])
    }
}

// feGaussianBlur/complex-transform: a blur along the user space axes under rotation or skew
struct FilterShearedBlurTests {

    // scale, flips, 90° rotations and isotropic blurs under rotation stay along the pixel axes
    @Test(arguments: [
        (LayerTree.Transform.Matrix(a: 2, b: 0, c: 0, d: -3, tx: 0, ty: 0), Float(4), Float(1)),
        (LayerTree.Transform.Matrix(a: 0, b: 1, c: -1, d: 0, tx: 0, ty: 0), 4, 1),
        (LayerTree.Transform.Matrix(a: 0.7071, b: 0.7071, c: -0.7071, d: 0.7071, tx: 0, ty: 0), 3, 3),
        (LayerTree.Transform.Matrix(a: 0.7071, b: 0.7071, c: -0.7071, d: 0.7071, tx: 0, ty: 0), 0, 0),
    ])
    func axisAlignedBlurIsNotSheared(matrix: LayerTree.Transform.Matrix, x: Float, y: Float) {
        #expect(matrix.blurShear(x, y) == nil)
    }

    // the split keeps the covariance M·diag(x², y²)·Mᵀ
    @Test(arguments: [
        (LayerTree.Transform.Matrix(a: 0.7071, b: 0.7071, c: -0.7071, d: 0.7071, tx: 0, ty: 0), Float(12), Float(0)),
        (LayerTree.Transform.Matrix(a: 0.7071, b: 0.7071, c: -0.7071, d: 0.7071, tx: 0, ty: 0), 0, 12),
        (LayerTree.Transform.Matrix(a: 2, b: 0.5, c: 0.3, d: -1, tx: 0, ty: 0), 3, 7),
        (LayerTree.Transform.Matrix(a: 1, b: 0, c: 1, d: 1, tx: 0, ty: 0), 4, 4),
    ])
    func shearKeepsCovariance(matrix m: LayerTree.Transform.Matrix, x: Float, y: Float) throws {
        let shear = try #require(m.blurShear(x, y))
        #expect(abs(shear.slope) <= 1)

        var p = m.a * m.a * x * x + m.c * m.c * y * y
        var r = m.b * m.b * x * x + m.d * m.d * y * y
        let q = m.a * m.b * x * x + m.c * m.d * y * y
        if shear.isTransposed { swap(&p, &r) }
        let along = shear.along * shear.along
        #expect(abs(shear.across * shear.across + along * shear.slope * shear.slope - p) < 0.01)
        #expect(abs(along * shear.slope - q) < 0.01)
        #expect(abs(along - r) < 0.01)
    }

    // whole pixel shears are undone exactly
    @Test(arguments: [Float(1), -1, 2, -0.5])
    func shearingRoundTrips(slope: Float) {
        let bitmap = makeBitmap(width: 5, height: 4) { x, y in UInt8(x * 40 + y * 10 + 5) }
        let sheared = bitmap.shearingRows(by: slope)
        #expect(sheared.width > bitmap.width)
        let restored = sheared.unshearingRows(by: slope, width: bitmap.width)
        if slope.rounded() == slope {
            #expect(restored == bitmap)
        } else {
            #expect(restored.pixel(x: 0, y: 0) == bitmap.pixel(x: 0, y: 0))
        }
    }

    @Test
    func transposeRoundTrips() {
        let bitmap = makeBitmap(width: 5, height: 3) { x, y in UInt8(x * 40 + y * 10 + 5) }
        let transposed = bitmap.transposed()
        #expect(transposed.width == 3)
        #expect(transposed.height == 5)
        #expect(transposed.pixel(x: 2, y: 4) == bitmap.pixel(x: 4, y: 2))
        #expect(transposed.transposed() == bitmap)
    }

    // a blur of 12 along user x under rotate(45): the pixel along the rotated x axis is blurred, the one
    // the same distance along the rotated y axis is not
    @Test
    func rotatedBlurFollowsUserSpace() {
        let size = 41
        let centre = 20
        let source = makeBitmap(width: size, height: size) { x, y in
            abs(x - centre) <= 2 && abs(y - centre) <= 2 ? 255 : 0
        }
        let region = LayerTree.Rect(x: -100, y: -100, width: 200, height: 200)
        let filter = LayerTree.FilterLayer(
            region: region,
            primitives: [
                Primitive(
                    effect: .gaussianBlur(stdDeviation: 4, stdDeviationY: 0),
                    inputs: [.sourceGraphic],
                    subregion: region,
                    colorInterpolation: .sRGB
                )
            ]
        )
        let c = Float(0.5).squareRoot()
        let environment = LayerTree.FilterLayer.Environment(
            transform: LayerTree.Transform.Matrix(
                a: c,
                b: c,
                c: -c,
                d: c,
                tx: Float(centre) + 0.5,
                ty: Float(centre) + 0.5
            ),
            blur: Self.boxBlur
        )

        let result = filter.evaluate(source: source, environment: environment)
        // user (6, 0) and (0, 6) from the centre
        let along = result.pixel(x: centre + 4, y: centre + 4)[3]
        let across = result.pixel(x: centre - 4, y: centre + 4)[3]
        #expect(along > 10)
        #expect(across < 3)
        #expect(result.width == size)
        #expect(result.height == size)
    }

    typealias Primitive = LayerTree.FilterLayer.Primitive

    // a single box pass of 2⌈σ⌉+1 along each axis: enough to see the direction of the blur
    static func boxBlur(_ bitmap: inout FilterBitmap, _ x: Float, _ y: Float) {
        func pass(_ bitmap: FilterBitmap, radius: Int, horizontal: Bool) -> FilterBitmap {
            guard radius > 0 else { return bitmap }
            var result = FilterBitmap(width: bitmap.width, height: bitmap.height)
            for py in 0..<bitmap.height {
                for px in 0..<bitmap.width {
                    for channel in 0..<4 {
                        var sum = 0
                        for k in -radius...radius {
                            let sx = horizontal ? px + k : px
                            let sy = horizontal ? py : py + k
                            guard sx >= 0, sx < bitmap.width, sy >= 0, sy < bitmap.height else { continue }
                            sum += Int(bitmap.pixels[(sy * bitmap.width + sx) * 4 + channel])
                        }
                        result.pixels[(py * bitmap.width + px) * 4 + channel] = UInt8(sum / (2 * radius + 1))
                    }
                }
            }
            return result
        }
        bitmap = pass(bitmap, radius: Int(x.rounded(.up)), horizontal: true)
        bitmap = pass(bitmap, radius: Int(y.rounded(.up)), horizontal: false)
    }

    func makeBitmap(width: Int, height: Int, _ value: (Int, Int) -> UInt8) -> FilterBitmap {
        var pixels = [UInt8]()
        for y in 0..<height {
            for x in 0..<width {
                let v = value(x, y)
                pixels.append(contentsOf: [v, v, v, v])
            }
        }
        return FilterBitmap(width: width, height: height, pixels: pixels)
    }
}

private extension LayerTreeFilterEdgeCaseTests {

    func makeCommands(_ xml: String, options: SVG.Options = .default) throws -> [RendererCommand<LayerTreeTypes>] {
        let svg = try DOM.SVG.parse(xml: xml)
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let generator = LayerTree.CommandGenerator(
            provider: LayerTreeProvider(),
            size: .init(svg.width, svg.height),
            options: options
        )
        return generator.renderCommands(for: layer, colorConverter: .default)
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
