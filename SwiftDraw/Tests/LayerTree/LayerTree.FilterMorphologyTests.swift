//
//  LayerTree.FilterMorphologyTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 17/11/26.
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

// Filter Effects 1 §9.17 feMorphology, with the cases of resvg's filters/feMorphology tests
struct LayerTreeFilterMorphologyTests {

    typealias Effect = LayerTree.FilterLayer.Effect

    @Test(
        arguments: [
            (#"radius="10""#, Effect.morphology(.erode, radiusX: 10, radiusY: 10)),
            (#"radius="10" operator="dilate""#, .morphology(.dilate, radiusX: 10, radiusY: 10)),
            (#"radius="1 10""#, .morphology(.erode, radiusX: 1, radiusY: 10)),
            (#"radius="1,10" operator="erode""#, .morphology(.erode, radiusX: 1, radiusY: 10)),
            // an unknown operator is erode
            (#"radius="2" operator="open""#, .morphology(.erode, radiusX: 2, radiusY: 2)),
            // radius=10-0: one zero radius is 1, as resvg, Chrome and Safari
            (#"radius="10 0""#, .morphology(.erode, radiusX: 10, radiusY: 1)),
            (#"radius="0 10""#, .morphology(.erode, radiusX: 1, radiusY: 10)),
            // zero-radius, negative-radius, no-radius, empty-radius, radius-with-too-many-values: the input
            (#"radius="0""#, .morphology(.erode, radiusX: 0, radiusY: 0)),
            (#"radius="-5""#, .morphology(.erode, radiusX: 0, radiusY: 0)),
            (#"radius="10 -1""#, .morphology(.erode, radiusX: 0, radiusY: 0)),
            ("", .morphology(.erode, radiusX: 0, radiusY: 0)),
            (#"radius="""#, .morphology(.erode, radiusX: 0, radiusY: 0)),
            (#"radius="10 20 30""#, .morphology(.erode, radiusX: 0, radiusY: 0)),
            (#"radius="10px""#, .morphology(.erode, radiusX: 0, radiusY: 0)),
            // huge-radius stays finite
            (#"radius="1e38 1e38""#, .morphology(.erode, radiusX: 1e38, radiusY: 1e38)),
        ] as [(String, LayerTree.FilterLayer.Effect)]
    )
    func parsesRadius(attributes: String, effect: LayerTree.FilterLayer.Effect) throws {
        let layer = try makeFilterLayer(#"<feMorphology \#(attributes)/>"#)
        #expect(layer.effects == [effect])
    }

    // radius=0.5-with-objectBoundingBox: a fraction of the bounding box
    @Test
    func objectBoundingBoxScalesRadius() throws {
        let layer = try makeFilterLayer(#"<feMorphology radius="0.1 0.25"/>"#, primitiveUnits: "objectBoundingBox")
        let effect = try #require(layer.effects.first)
        guard case let .morphology(.erode, radiusX: x, radiusY: y) = effect else {
            Issue.record("expected erode, got \(effect)")
            return
        }
        #expect(abs(x - 16) < 0.001)
        #expect(abs(y - 40) < 0.001)
    }

    // simple-case: a radius of 10 erodes 10 units from each edge of the rect at 20...180
    @Test(
        arguments: [
            (Float(1), [(29, 0), (30, 255), (169, 255), (170, 0)]),
            // at 1.5x, as resvg renders the test: 15 pixels
            (1.5, [(44, 0), (45, 255), (254, 255), (255, 0)]),
        ] as [(Float, [(Int, UInt8)])]
    )
    func erodesFromEachEdge(scale: Float, alphas: [(Int, UInt8)]) throws {
        let layer = try makeFilterLayer(#"<feMorphology radius="10"/>"#)
        let size = Int(200 * scale)
        var source = FilterBitmap(width: size, height: 1)
        for x in Int(20 * scale)..<Int(180 * scale) {
            source.pixels.replaceSubrange((x * 4)..<(x * 4 + 4), with: [0, 128, 0, 255])
        }
        let environment = LayerTree.FilterLayer.Environment(
            transform: LayerTree.Transform.Matrix(a: scale, b: 0, c: 0, d: scale, tx: 0, ty: -100 * scale + 0.5),
            blur: { _, _, _ in }
        )
        let result = layer.evaluate(source: source, environment: environment)
        for (x, alpha) in alphas {
            #expect(result.pixel(x: x, y: 0)[3] == alpha, "x = \(x)")
        }
    }

    // a radius under a pixel leaves the input
    @Test
    func subpixelRadiusIsTheInput() {
        let transform = LayerTree.Transform.Matrix(a: 1.5, b: 0, c: 0, d: 1.5, tx: 0, ty: 0)
        #expect(transform.pixelRadius(0.5, 0.5) == (0, 0))
        #expect(transform.pixelRadius(10, 10.25) == (15, 15))
        #expect(transform.pixelRadius(1e38, 1e38) == (1_000_000, 1_000_000))
        // rotated a quarter turn: x in user space is y in pixels
        let rotated = LayerTree.Transform.Matrix(a: 0, b: 2, c: -2, d: 0, tx: 0, ty: 0)
        #expect(rotated.pixelRadius(1, 3) == (6, 2))
    }
}

private extension LayerTreeFilterMorphologyTests {

    func makeFilterLayer(_ primitive: String, primitiveUnits: String = "userSpaceOnUse") throws -> LayerTree.FilterLayer
    {
        let svg = try DOM.SVG.parse(
            xml: #"""
                <svg width="200" height="200" xmlns="http://www.w3.org/2000/svg">
                    <filter id="f" primitiveUnits="\#(primitiveUnits)">\#(primitive)</filter>
                    <rect x="20" y="20" width="160" height="160" fill="green" filter="url(#f)" />
                </svg>
                """#
        )
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let generator = LayerTree.CommandGenerator(
            provider: LayerTreeProvider(),
            size: .init(200, 200),
            options: .default
        )
        let commands = generator.renderCommands(for: layer, colorConverter: .default)
        return try #require(
            commands.compactMap {
                if case .pushFilterLayer(let filter) = $0 { return filter }
                return nil
            }.first
        )
    }
}

// the kernel against the definition: the minimum or maximum over the rectangle within the bitmap
struct FilterBitmapMorphologyTests {

    @Test(
        arguments: [
            (DOM.Filter.MorphologyOperator.erode, 1, 1, false),
            (.dilate, 1, 1, false),
            (.erode, 2, 0, false),
            (.dilate, 0, 3, false),
            (.erode, 3, 1, true),
            (.dilate, 1, 4, true),
            // larger than the bitmap: every window is the whole row or column
            (.erode, 20, 2, false),
            (.dilate, 5, 50, true),
        ] as [(DOM.Filter.MorphologyOperator, Int, Int, Bool)]
    )
    func matchesTheDefinition(op: DOM.Filter.MorphologyOperator, rx: Int, ry: Int, linear: Bool) {
        let source = makeNoise(width: 13, height: 9)
        let result = FilterBitmap.morphology(source, op, radiusX: rx, radiusY: ry, linear: linear)
        let expected = naiveMorphology(source, op, rx: rx, ry: ry, linear: linear)
        #expect(result == expected)
    }

    @Test
    func zeroRadiusIsTheInput() {
        let source = makeNoise(width: 5, height: 5)
        #expect(FilterBitmap.morphology(source, .erode, radiusX: 0, radiusY: 0, linear: true) == source)
    }

    // huge-radius: no time or memory beyond the bitmap
    @Test
    func hugeRadiusIsBoundedByTheBitmap() {
        var source = FilterBitmap(width: 300, height: 300)
        source.pixels.withUnsafeMutableBufferPointer { $0.update(repeating: 255) }
        source.pixels[0..<4] = [0, 0, 0, 0]
        let eroded = FilterBitmap.morphology(source, .erode, radiusX: 1_000_000, radiusY: 1_000_000, linear: false)
        #expect(eroded == FilterBitmap(width: 300, height: 300))
        let dilated = FilterBitmap.morphology(source, .dilate, radiusX: Int.max, radiusY: Int.max, linear: false)
        #expect(dilated.pixel(x: 0, y: 0) == [255, 255, 255, 255])
    }

    // source-with-opacity: channels are eroded separately, premultiplied
    @Test
    func channelsAreIndependent() {
        let source = FilterBitmap(width: 2, height: 1, pixels: [191, 191, 0, 191, 0, 0, 191, 191])
        let result = FilterBitmap.morphology(source, .erode, radiusX: 1, radiusY: 0, linear: false)
        #expect(result.pixels == [0, 0, 0, 191, 0, 0, 0, 191])
    }
}

private extension FilterBitmapMorphologyTests {

    // premultiplied pixels, deterministic
    func makeNoise(width: Int, height: Int) -> FilterBitmap {
        var state: UInt32 = 12345
        var pixels = [UInt8]()
        for _ in 0..<(width * height) {
            state = state &* 1664525 &+ 1013904223
            let a = UInt8(truncatingIfNeeded: state >> 24)
            let r = UInt8(UInt32(UInt8(truncatingIfNeeded: state >> 16)) * UInt32(a) / 255)
            let g = UInt8(UInt32(UInt8(truncatingIfNeeded: state >> 8)) * UInt32(a) / 255)
            let b = UInt8(UInt32(UInt8(truncatingIfNeeded: state)) * UInt32(a) / 255)
            pixels += [r, g, b, a]
        }
        return FilterBitmap(width: width, height: height, pixels: pixels)
    }

    // the minimum or maximum of each channel's value in the primitive's space, then encoded as the kernel does
    func naiveMorphology(
        _ source: FilterBitmap,
        _ op: DOM.Filter.MorphologyOperator,
        rx: Int,
        ry: Int,
        linear: Bool
    ) -> FilterBitmap {
        func value(_ x: Int, _ y: Int, _ channel: Int) -> Float {
            let p = source.pixel(x: x, y: y)
            let alpha = Float(p[3]) / 255
            guard channel < 3, linear, p[3] > 0 else { return Float(p[channel]) / 255 }
            let straight = Float(min(255, (Int(p[channel]) * 255 + Int(p[3]) / 2) / Int(p[3]))) / 255
            let decoded = straight <= 0.04045 ? straight / 12.92 : Float(pow(Double((straight + 0.055) / 1.055), 2.4))
            return decoded * alpha
        }
        var values = [[Float]](repeating: [0, 0, 0, 0], count: source.width * source.height)
        for y in 0..<source.height {
            for x in 0..<source.width {
                for channel in 0..<4 {
                    var extreme: Float = op == .erode ? 2 : -1
                    for wy in max(0, y - ry)...min(source.height - 1, y + ry) {
                        for wx in max(0, x - rx)...min(source.width - 1, x + rx) {
                            let v = value(wx, wy, channel)
                            extreme = op == .erode ? min(extreme, v) : max(extreme, v)
                        }
                    }
                    values[y * source.width + x][channel] = extreme
                }
            }
        }
        // encoded by an identity map, which quantizes the same way
        var result = FilterBitmap(width: source.width, height: source.height)
        for (i, v) in values.enumerated() {
            let pixel = FilterBitmap.encode(FilterPixel(r: v[0], g: v[1], b: v[2], a: v[3]), linear: linear)
            result.pixels.replaceSubrange((i * 4)..<(i * 4 + 4), with: pixel)
        }
        return result
    }
}
