//
//  FilterBitmapTests.swift
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

// SD12: filter primitives on premultiplied RGBA pixels, platform independent
final class FilterBitmapTests: XCTestCase {

    let red: [UInt8] = [255, 0, 0, 255]
    let blue: [UInt8] = [0, 0, 255, 255]
    let halfBlue: [UInt8] = [0, 0, 128, 128]
    let white: [UInt8] = [255, 255, 255, 255]
    let clear: [UInt8] = [0, 0, 0, 0]

    func testSourceAlphaKeepsOnlyAlpha() {
        let source = FilterBitmap.make([[red, halfBlue, [10, 20, 30, 40]]])
        XCTAssertEqual(FilterBitmap.sourceAlpha(of: source).row(0), [[0, 0, 0, 255], [0, 0, 0, 128], [0, 0, 0, 40]])
    }

    func testFloodIsPremultiplied() {
        let flood = FilterBitmap.flood(width: 2, height: 1, color: SIMD4(1, 0.5, 0, 0.5))
        XCTAssertEqual(flood.row(0), [[128, 64, 0, 128], [128, 64, 0, 128]])
        XCTAssertEqual(FilterBitmap.flood(width: 1, height: 1, color: SIMD4(1, 1, 1, 0)).row(0), [clear])
    }

    func testWholeOffset() {
        let source = FilterBitmap.make([[red, blue, clear],
                                        [clear, clear, clear]])
        let shifted = FilterBitmap.offset(source, dx: 1, dy: 1)
        XCTAssertEqual(shifted.row(0), [clear, clear, clear])
        XCTAssertEqual(shifted.row(1), [clear, red, blue])

        let back = FilterBitmap.offset(source, dx: -1, dy: 0)
        XCTAssertEqual(back.row(0), [blue, clear, clear])
    }

    func testFractionalOffsetInterpolates() {
        let source = FilterBitmap.make([[white, clear, clear]])
        let shifted = FilterBitmap.offset(source, dx: 0.5, dy: 0)
        XCTAssertEqual(shifted.row(0), [[128, 128, 128, 128], [128, 128, 128, 128], clear])
        // within a thousandth of a pixel the offset is whole
        XCTAssertEqual(FilterBitmap.offset(source, dx: 0.9999, dy: 0).row(0), [clear, white, clear])

        // inside a solid area the colour is exact, both axes interpolate at its edges
        let solid = FilterBitmap.make([[white, white, white],
                                       [white, white, white],
                                       [clear, clear, clear]])
        let diagonal = FilterBitmap.offset(solid, dx: 0.5, dy: 0.5)
        XCTAssertEqual(diagonal.row(0), [[64, 64, 64, 64], [128, 128, 128, 128], [128, 128, 128, 128]])
        XCTAssertEqual(diagonal.row(1), [[128, 128, 128, 128], white, white])
        XCTAssertEqual(diagonal.row(2), [[64, 64, 64, 64], [128, 128, 128, 128], [128, 128, 128, 128]])
    }

    func testOffsetBeyondBitmapIsTransparent() {
        let source = FilterBitmap.make([[white, white]])
        XCTAssertEqual(FilterBitmap.offset(source, dx: 2, dy: 0).row(0), [clear, clear])
        XCTAssertEqual(FilterBitmap.offset(source, dx: .nan, dy: 0).row(0), [clear, clear])
    }

    // Porter-Duff with `in` as source over `in2` as destination
    func testCompositeOperators() {
        let a = FilterBitmap.make([[red]])
        let b = FilterBitmap.make([[halfBlue]])
        func composite(_ op: DOM.Filter.CompositeOperator) -> [UInt8] {
            FilterBitmap.composite(a, b, op: op, linear: false).pixel(x: 0, y: 0)
        }
        XCTAssertEqual(composite(.over), red)
        XCTAssertEqual(composite(.in), [128, 0, 0, 128])
        XCTAssertEqual(composite(.out), [127, 0, 0, 127])
        XCTAssertEqual(composite(.atop), [128, 0, 0, 128])
        XCTAssertEqual(composite(.xor), [127, 0, 0, 127])
        XCTAssertEqual(composite(.lighter), [255, 0, 128, 255])
        // Figma's inner shadow: in2 - in, clamped
        XCTAssertEqual(composite(.arithmetic(k1: 0, k2: -1, k3: 1, k4: 0)), clear)
        XCTAssertEqual(FilterBitmap.composite(b, a, op: .arithmetic(k1: 0, k2: -1, k3: 1, k4: 0), linear: false).pixel(x: 0, y: 0),
                       [127, 0, 0, 127])
        // k4 alone fills transparent pixels; colour never exceeds alpha
        XCTAssertEqual(FilterBitmap.composite(FilterBitmap.make([[clear]]), FilterBitmap.make([[clear]]),
                                              op: .arithmetic(k1: 0, k2: 0, k3: 0, k4: 0.5), linear: false).pixel(x: 0, y: 0),
                       [128, 128, 128, 128])
        XCTAssertEqual(FilterBitmap.composite(a, b, op: .arithmetic(k1: 0, k2: 1, k3: 0, k4: -0.5), linear: false).pixel(x: 0, y: 0),
                       [128, 0, 0, 128])
        // huge coefficients cannot produce NaN pixels
        XCTAssertEqual(FilterBitmap.composite(a, a, op: .arithmetic(k1: 3e38, k2: 3e38, k3: -3e38, k4: 0), linear: false).pixel(x: 0, y: 0).count, 4)
    }

    // Filter Effects 1 §9.16: the first node at the bottom
    func testMergeOrder() {
        let merged = FilterBitmap.merge([FilterBitmap.make([[red]]), FilterBitmap.make([[halfBlue]])], width: 1, height: 1, linear: false)
        XCTAssertEqual(merged.pixel(x: 0, y: 0), [127, 0, 128, 255])
        let reversed = FilterBitmap.merge([FilterBitmap.make([[halfBlue]]), FilterBitmap.make([[red]])], width: 1, height: 1, linear: false)
        XCTAssertEqual(reversed.pixel(x: 0, y: 0), red)
        XCTAssertEqual(FilterBitmap.merge([], width: 1, height: 1, linear: false).pixel(x: 0, y: 0), clear)
    }

    // Compositing and Blending 1: `in` is the source, `in2` the backdrop
    func testBlendModes() {
        let source = FilterBitmap.make([[red]])
        let backdrop = FilterBitmap.make([[[0, 0, 255, 255]]])
        func blend(_ mode: DOM.Filter.BlendMode, _ s: FilterBitmap? = nil, _ b: FilterBitmap? = nil) -> [UInt8] {
            FilterBitmap.blend(s ?? source, b ?? backdrop, mode: mode, linear: false).pixel(x: 0, y: 0)
        }
        XCTAssertEqual(blend(.normal), red)
        XCTAssertEqual(blend(.multiply), [0, 0, 0, 255])
        XCTAssertEqual(blend(.screen), [255, 0, 255, 255])
        XCTAssertEqual(blend(.darken), [0, 0, 0, 255])
        XCTAssertEqual(blend(.lighten), [255, 0, 255, 255])
        XCTAssertEqual(blend(.difference), [255, 0, 255, 255])
        XCTAssertEqual(blend(.exclusion), [255, 0, 255, 255])
        // luminosity of white keeps the backdrop's hue at full lightness
        XCTAssertEqual(blend(.luminosity, FilterBitmap.make([[white]])), white)
        // colour of red on a white backdrop keeps white's luminosity
        XCTAssertEqual(blend(.color, nil, FilterBitmap.make([[white]])), white)

        let black = FilterBitmap.make([[[0, 0, 0, 255]]])
        let whiteBitmap = FilterBitmap.make([[white]])
        let grey = FilterBitmap.make([[[128, 128, 128, 255]]])
        // overlay is hard-light with the layers swapped
        XCTAssertEqual(blend(.overlay, black, whiteBitmap), white)
        XCTAssertEqual(blend(.hardLight, black, whiteBitmap), [0, 0, 0, 255])
        XCTAssertEqual(blend(.softLight, black, whiteBitmap), white)
        XCTAssertEqual(blend(.softLight, whiteBitmap, black), [0, 0, 0, 255])
        XCTAssertEqual(blend(.colorDodge, whiteBitmap, grey), white)
        XCTAssertEqual(blend(.colorDodge, grey, black), [0, 0, 0, 255])
        XCTAssertEqual(blend(.colorBurn, black, grey), [0, 0, 0, 255])
        XCTAssertEqual(blend(.colorBurn, grey, whiteBitmap), white)
        // a hue on a grey backdrop has no saturation left: the grey
        XCTAssertEqual(blend(.hue, source, grey), [128, 128, 128, 255])
        // no saturation from a grey source: the luminosity of blue
        XCTAssertEqual(blend(.saturation, grey, backdrop), [28, 28, 28, 255])

        // over a transparent backdrop every mode is the source
        for mode in [DOM.Filter.BlendMode.multiply, .screen, .difference, .hue] {
            XCTAssertEqual(blend(mode, FilterBitmap.make([[halfBlue]]), FilterBitmap.make([[clear]])), halfBlue)
        }
        // and a transparent source leaves the backdrop
        XCTAssertEqual(blend(.multiply, FilterBitmap.make([[clear]]), FilterBitmap.make([[halfBlue]])), halfBlue)
    }

    func testColorMatrix() {
        let source = FilterBitmap.make([[red, [0, 0, 0, 3], clear]])
        // Figma's hard alpha: any coverage becomes opaque black
        let hardAlpha: [Float] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 127, 0]
        XCTAssertEqual(FilterBitmap.colorMatrix(source, matrix: hardAlpha, linear: false).row(0),
                       [[0, 0, 0, 255], [0, 0, 0, 255], clear])

        // a grey of red: 0.2126 in sRGB values, 0.2126 of linear light in linearRGB
        let grey = DOM.Filter.ColorMatrix.saturate(0).values
        XCTAssertEqual(FilterBitmap.colorMatrix(FilterBitmap.make([[red]]), matrix: grey, linear: false).pixel(x: 0, y: 0), [54, 54, 54, 255])
        XCTAssertEqual(FilterBitmap.colorMatrix(FilterBitmap.make([[red]]), matrix: grey, linear: true).pixel(x: 0, y: 0), [127, 127, 127, 255])

        // the matrix works on straight colour: a half transparent red stays red
        let identity = DOM.Filter.ColorMatrix.identity
        XCTAssertEqual(FilterBitmap.colorMatrix(FilterBitmap.make([[[128, 0, 0, 128]]]), matrix: identity, linear: true).pixel(x: 0, y: 0),
                       [128, 0, 0, 128])
        // an alpha offset gives transparent pixels black coverage
        let opaque: [Float] = [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1]
        XCTAssertEqual(FilterBitmap.colorMatrix(FilterBitmap.make([[clear]]), matrix: opaque, linear: false).pixel(x: 0, y: 0),
                       [0, 0, 0, 255])
        // a wrong matrix size is a pass through
        XCTAssertEqual(FilterBitmap.colorMatrix(source, matrix: [1, 2], linear: false), source)
    }

    // Filter Effects 1 §10: linearRGB composites in linear light; storage stays sRGB encoded
    func testLinearRGBCompositing() {
        let halfWhite = FilterBitmap.make([[[128, 128, 128, 128]]])
        let black = FilterBitmap.make([[[0, 0, 0, 255]]])
        XCTAssertEqual(FilterBitmap.composite(halfWhite, black, op: .over, linear: false).pixel(x: 0, y: 0), [128, 128, 128, 255])
        XCTAssertEqual(FilterBitmap.composite(halfWhite, black, op: .over, linear: true).pixel(x: 0, y: 0), [188, 188, 188, 255])

        // dark colours survive a linearRGB pass unchanged
        let dark = FilterBitmap.make([[[3, 5, 1, 255], [2, 1, 0, 128]]])
        XCTAssertEqual(FilterBitmap.composite(dark, FilterBitmap(width: 2, height: 1), op: .over, linear: true), dark)
        XCTAssertEqual(FilterBitmap.colorMatrix(dark, matrix: DOM.Filter.ColorMatrix.identity, linear: true), dark)
    }

    func testClipToAxisAlignedSubregion() {
        var bitmap = FilterBitmap.flood(width: 4, height: 3, color: SIMD4(1, 1, 1, 1))
        // user space at 2x: the subregion 0.5...1.5 × 0.5...1 covers pixels 1...2 × 1
        let transform = LayerTree.Transform.Matrix(a: 2, b: 0, c: 0, d: 2, tx: 0, ty: 0)
        bitmap.clip(to: LayerTree.Rect(x: 0.5, y: 0.5, width: 1, height: 0.5), transform: transform)
        XCTAssertEqual(bitmap.row(0), [clear, clear, clear, clear])
        XCTAssertEqual(bitmap.row(1), [clear, white, white, clear])
        XCTAssertEqual(bitmap.row(2), [clear, clear, clear, clear])

        // a subregion covering the bitmap changes nothing
        var whole = FilterBitmap.flood(width: 2, height: 2, color: SIMD4(1, 1, 1, 1))
        whole.clip(to: LayerTree.Rect(x: -5, y: -5, width: 20, height: 20), transform: .identity)
        XCTAssertEqual(whole, FilterBitmap.flood(width: 2, height: 2, color: SIMD4(1, 1, 1, 1)))
    }

    func testClipToRotatedSubregion() {
        var bitmap = FilterBitmap.flood(width: 5, height: 5, color: SIMD4(1, 1, 1, 1))
        // 45° about the bitmap centre: a diamond
        // Float overloads of cos and sin are missing on Android and Windows
        let cosine = Float(cos(Double.pi / 4))
        let sine = Float(sin(Double.pi / 4))
        let rotate = LayerTree.Transform.Matrix(a: cosine, b: sine, c: -sine, d: cosine, tx: 0, ty: 0)
        let transform = rotate.concatenated(LayerTree.Transform.Matrix(a: 1, b: 0, c: 0, d: 1, tx: 2.5, ty: 2.5))
        bitmap.clip(to: LayerTree.Rect(x: -1.5, y: -1.5, width: 3, height: 3), transform: transform)
        XCTAssertEqual(bitmap.pixel(x: 2, y: 2), white)
        XCTAssertEqual(bitmap.pixel(x: 2, y: 0), white)
        XCTAssertEqual(bitmap.pixel(x: 0, y: 0), clear)
        XCTAssertEqual(bitmap.pixel(x: 4, y: 4), clear)
    }

    // Figma's drop shadow on a 3x3 white square, dy=4, no blur
    func testEvaluateFigmaDropShadow() {
        let source = makeSquare(size: 8, from: 2, to: 4)
        let region = LayerTree.Rect(x: 0, y: 0, width: 8, height: 8)
        let filter = LayerTree.FilterLayer(region: region, primitives: [
            primitive(.flood(.rgba(r: 0, g: 0, b: 0, a: 0, space: .srgb)), [], region),
            primitive(.colorMatrix([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 127, 0]), [.sourceAlpha], region),
            primitive(.offset(dx: 0, dy: 4), [.primitive(1)], region),
            primitive(.gaussianBlur(stdDeviation: 0, stdDeviationY: 0), [.primitive(2)], region),
            primitive(.composite(.out), [.primitive(3), .primitive(1)], region),
            primitive(.colorMatrix([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.25, 0]), [.primitive(4)], region),
            primitive(.blend(.normal), [.primitive(5), .primitive(0)], region),
            primitive(.blend(.normal), [.sourceGraphic, .primitive(6)], region)
        ])

        let result = filter.evaluate(source: source, environment: .init(transform: .identity, blur: { _, _, _ in }))
        XCTAssertEqual(result.pixel(x: 3, y: 3), white)
        XCTAssertEqual(result.pixel(x: 3, y: 5), clear)
        XCTAssertEqual(result.pixel(x: 3, y: 6), [0, 0, 0, 64])
        XCTAssertEqual(result.pixel(x: 2, y: 7), [0, 0, 0, 64])
        XCTAssertEqual(result.pixel(x: 0, y: 0), clear)
    }

    // Inkscape's drop shadow: a half black flood `in` SourceGraphic, offset, SourceGraphic over it
    func testEvaluateInkscapeDropShadow() {
        let source = makeSquare(size: 8, from: 1, to: 3, color: red)
        let region = LayerTree.Rect(x: 0, y: 0, width: 8, height: 8)
        let filter = LayerTree.FilterLayer(region: region, primitives: [
            primitive(.flood(.rgba(r: 0, g: 0, b: 0, a: 0.5, space: .srgb)), [], region),
            primitive(.composite(.in), [.primitive(0), .sourceGraphic], region),
            primitive(.gaussianBlur(stdDeviation: 1, stdDeviationY: 1), [.primitive(1)], region),
            primitive(.offset(dx: 2, dy: 2), [.primitive(2)], region),
            primitive(.composite(.over), [.sourceGraphic, .primitive(3)], region)
        ])

        var deviations = [(Float, Float)]()
        let environment = LayerTree.FilterLayer.Environment(
            transform: LayerTree.Transform.Matrix(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0),
            blur: { _, x, y in deviations.append((x, y)) }
        )
        let result = filter.evaluate(source: source, environment: environment)
        XCTAssertEqual(result.pixel(x: 2, y: 2), red)
        XCTAssertEqual(result.pixel(x: 5, y: 5), [0, 0, 0, 128])
        XCTAssertEqual(result.pixel(x: 4, y: 2), clear)
        XCTAssertEqual(deviations.map(\.0), [1])
    }

    // user space at 2x, flipped vertically: offsets and deviations follow into pixels
    func testEvaluateMapsUserSpaceToPixels() {
        let source = makeSquare(size: 8, from: 3, to: 3)
        let region = LayerTree.Rect(x: -100, y: -100, width: 200, height: 200)
        let filter = LayerTree.FilterLayer(region: region, primitives: [
            primitive(.gaussianBlur(stdDeviation: 3, stdDeviationY: 1), [.sourceGraphic], region),
            primitive(.offset(dx: 1, dy: 1), [.primitive(0)], region)
        ])
        var deviations = [(Float, Float)]()
        let environment = LayerTree.FilterLayer.Environment(
            transform: LayerTree.Transform.Matrix(a: 2, b: 0, c: 0, d: -2, tx: 0, ty: 8),
            blur: { _, x, y in deviations.append((x, y)) }
        )

        let result = filter.evaluate(source: source, environment: environment)
        XCTAssertEqual(deviations.map(\.0), [6])
        XCTAssertEqual(deviations.map(\.1), [2])
        XCTAssertEqual(result.pixel(x: 5, y: 1), white)
        XCTAssertEqual(result.pixel(x: 3, y: 3), clear)
    }

    func testEvaluateDisabledPrimitiveIsTransparent() {
        let source = makeSquare(size: 4, from: 0, to: 3)
        let region = LayerTree.Rect(x: 0, y: 0, width: 4, height: 4)
        let filter = LayerTree.FilterLayer(region: region, primitives: [
            primitive(.offset(dx: 0, dy: 0), [.sourceGraphic], .zero),
            primitive(.merge, [.primitive(0), .transparent], region)
        ])
        let result = filter.evaluate(source: source, environment: .init(transform: .identity, blur: { _, _, _ in }))
        XCTAssertEqual(result, FilterBitmap(width: 4, height: 4))
    }

    // a result read by later primitives is kept, and the blur may change its input in place
    func testEvaluateKeepsSharedResults() {
        let source = makeSquare(size: 4, from: 1, to: 2)
        let region = LayerTree.Rect(x: 0, y: 0, width: 4, height: 4)
        let filter = LayerTree.FilterLayer(region: region, primitives: [
            primitive(.offset(dx: 1, dy: 0), [.sourceGraphic], region),
            primitive(.gaussianBlur(stdDeviation: 1, stdDeviationY: 1), [.primitive(0)], region),
            primitive(.merge, [.primitive(1), .primitive(0), .sourceGraphic], region)
        ])
        // a "blur" that clears its bitmap
        let environment = LayerTree.FilterLayer.Environment(transform: .identity, blur: { bitmap, _, _ in
            bitmap = FilterBitmap(width: bitmap.width, height: bitmap.height)
        })
        let result = filter.evaluate(source: source, environment: environment)
        XCTAssertEqual(result.pixel(x: 1, y: 1), white)
        XCTAssertEqual(result.pixel(x: 3, y: 1), white)
        XCTAssertEqual(result.pixel(x: 0, y: 1), clear)
    }

    func testFloodColorFromEnvironment() {
        let region = LayerTree.Rect(x: 0, y: 0, width: 2, height: 2)
        let filter = LayerTree.FilterLayer(region: region, primitives: [
            primitive(.flood(.rgba(r: 1, g: 0, b: 0, a: 1, space: .p3)), [], LayerTree.Rect(x: 0, y: 0, width: 1, height: 2))
        ])
        let environment = LayerTree.FilterLayer.Environment(transform: .identity, blur: { _, _, _ in },
                                                            color: { _ in SIMD4(0, 1, 0, 1) })
        let result = filter.evaluate(source: FilterBitmap(width: 2, height: 2), environment: environment)
        XCTAssertEqual(result.row(0), [[0, 255, 0, 255], clear])
    }
}

private extension FilterBitmapTests {

    func primitive(_ effect: LayerTree.FilterLayer.Effect,
                   _ inputs: [LayerTree.FilterLayer.Input],
                   _ subregion: LayerTree.Rect) -> LayerTree.FilterLayer.Primitive {
        LayerTree.FilterLayer.Primitive(effect: effect, inputs: inputs, subregion: subregion, colorInterpolation: .sRGB)
    }

    func makeSquare(size: Int, from: Int, to: Int, color: [UInt8]? = nil) -> FilterBitmap {
        var rows = [[[UInt8]]]()
        for y in 0..<size {
            rows.append((0..<size).map { x in
                (from...to).contains(x) && (from...to).contains(y) ? (color ?? white) : clear
            })
        }
        return FilterBitmap.make(rows)
    }
}

private extension FilterBitmap {

    static func make(_ rows: [[[UInt8]]]) -> FilterBitmap {
        FilterBitmap(width: rows[0].count, height: rows.count, pixels: rows.flatMap { $0.flatMap { $0 } })
    }

    func row(_ y: Int) -> [[UInt8]] {
        (0..<width).map { pixel(x: $0, y: y) }
    }
}
