//
//  LayerTree.FilterConvolveMatrixTests.swift
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

// Filter Effects 1 §9.9 feConvolveMatrix, with the cases of resvg's filters/feConvolveMatrix tests
struct LayerTreeFilterConvolveMatrixTests {

    typealias Effect = LayerTree.FilterLayer.Effect

    static let ninths = #"kernelMatrix="0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1""#

    static func kernel(_ orderX: Int, _ orderY: Int, _ values: [Float], divisor: Float, bias: Float = 0,
                       target: (Int, Int)? = nil, edgeMode: DOM.Filter.EdgeMode = .duplicate,
                       preserveAlpha: Bool = false) -> Effect {
        .convolveMatrix(LayerTree.FilterLayer.ConvolveMatrix(
            orderX: orderX, orderY: orderY, kernelMatrix: values, divisor: divisor, bias: bias,
            targetX: target?.0 ?? orderX / 2, targetY: target?.1 ?? orderY / 2,
            edgeMode: edgeMode, preserveAlpha: preserveAlpha
        ))
    }

    static let tenths = [Float](repeating: 0.1, count: 9)
    static let sum = tenths.reduce(0, +)

    @Test(arguments: [
        // unset-order: 3 × 3, the divisor is the sum of the kernel
        (ninths, kernel(3, 3, tenths, divisor: sum)),
        (#"divisor="5" "# + ninths, kernel(3, 3, tenths, divisor: 5)),
        (#"bias="0.5" "# + ninths, kernel(3, 3, tenths, divisor: sum, bias: 0.5)),
        (#"targetX="0" "# + ninths, kernel(3, 3, tenths, divisor: sum, target: (0, 1))),
        (#"targetX="2" targetY="0" "# + ninths, kernel(3, 3, tenths, divisor: sum, target: (2, 0))),
        (#"edgeMode="wrap" "# + ninths, kernel(3, 3, tenths, divisor: sum, edgeMode: .wrap)),
        (#"edgeMode="none" "# + ninths, kernel(3, 3, tenths, divisor: sum, edgeMode: .none)),
        (#"edgeMode="mirror" "# + ninths, kernel(3, 3, tenths, divisor: sum)),
        (#"preserveAlpha="true" "# + ninths, kernel(3, 3, tenths, divisor: sum, preserveAlpha: true)),
        (#"preserveAlpha="yes" "# + ninths, kernel(3, 3, tenths, divisor: sum)),
        // order=4, order=4-2: one value is both
        (#"order="4 2" kernelMatrix="1 2 3 4 5 6 7 8""#, kernel(4, 2, [1, 2, 3, 4, 5, 6, 7, 8], divisor: 36)),
        (#"order="2" kernelMatrix="1 2 3 4""#, kernel(2, 2, [1, 2, 3, 4], divisor: 10)),
        // kernelMatrix-with-zero-sum-and-no-divisor: 1, though 0.1 × 8 - 0.8 is not quite zero as Float
        (#"kernelMatrix="0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 -0.8""#, kernel(3, 3, [0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, -0.8], divisor: 1)),
        // errors, transparent black: no-kernelMatrix, empty-kernelMatrix, too few or many values,
        // order=0, negative or fractional order, a target outside the kernel, divisor=0
        (#"order="3 3""#, .flood(.none)),
        (#"order="3 3" kernelMatrix="""#, .flood(.none)),
        (#"kernelMatrix="1 2 3 4 5""#, .flood(.none)),
        (#"kernelMatrix="0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1""#, .flood(.none)),
        (#"order="0" kernelMatrix="0.1""#, .flood(.none)),
        (#"order="4 -2" kernelMatrix="0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1""#, .flood(.none)),
        (#"order="-2" kernelMatrix="0.1 0.1 0.1 0.1""#, .flood(.none)),
        (#"order="1.5" kernelMatrix="0.1""#, .flood(.none)),
        (#"order="3 3 3" "# + ninths, .flood(.none)),
        (#"order="1e30" kernelMatrix="1""#, .flood(.none)),
        (#"targetX="-1" "# + ninths, .flood(.none)),
        (#"targetX="3" "# + ninths, .flood(.none)),
        (#"targetY="1.5" "# + ninths, .flood(.none)),
        (#"divisor="0" "# + ninths, .flood(.none))
    ] as [(String, LayerTree.FilterLayer.Effect)])
    func parsesAttributes(attributes: String, effect: LayerTree.FilterLayer.Effect) throws {
        let layer = try makeFilterLayer(#"<feConvolveMatrix \#(attributes)/>"#)
        #expect(layer.effects == [effect])
    }
}

private extension LayerTreeFilterConvolveMatrixTests {

    func makeFilterLayer(_ primitive: String) throws -> LayerTree.FilterLayer {
        let svg = try DOM.SVG.parse(xml: #"""
        <svg width="200" height="200" xmlns="http://www.w3.org/2000/svg">
            <filter id="f">\#(primitive)</filter>
            <rect x="20" y="20" width="160" height="160" fill="green" filter="url(#f)" />
        </svg>
        """#)
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(), size: .init(200, 200), options: .default)
        let commands = generator.renderCommands(for: layer, colorConverter: .default)
        return try #require(commands.compactMap {
            if case .pushFilterLayer(let filter) = $0 { return filter }
            return nil
        }.first)
    }
}

// the kernel against the spec's formula, written out directly
struct FilterBitmapConvolveMatrixTests {

    typealias Matrix = LayerTree.FilterLayer.ConvolveMatrix

    static func matrix(_ orderX: Int, _ orderY: Int, target: (Int, Int), edgeMode: DOM.Filter.EdgeMode,
                       divisor: Float = 1, bias: Float = 0, preserveAlpha: Bool = false) -> Matrix {
        var state: UInt32 = UInt32(orderX * 31 + orderY)
        let values = (0..<(orderX * orderY)).map { _ -> Float in
            state = state &* 1664525 &+ 1013904223
            return Float(Int(state >> 24) - 100) / 128
        }
        return Matrix(orderX: orderX, orderY: orderY, kernelMatrix: values, divisor: divisor, bias: bias,
                      targetX: target.0, targetY: target.1, edgeMode: edgeMode, preserveAlpha: preserveAlpha)
    }

    @Test(arguments: [
        (matrix(3, 3, target: (1, 1), edgeMode: .duplicate, divisor: 2), false),
        (matrix(3, 3, target: (0, 2), edgeMode: .wrap), true),
        (matrix(4, 2, target: (2, 1), edgeMode: .none, divisor: 3), false),
        (matrix(5, 1, target: (4, 0), edgeMode: .wrap, bias: 0.25), false),
        (matrix(1, 4, target: (0, 0), edgeMode: .duplicate, bias: -0.5), true),
        (matrix(3, 3, target: (1, 1), edgeMode: .none, preserveAlpha: true), false),
        (matrix(2, 3, target: (1, 2), edgeMode: .duplicate, bias: 0.1, preserveAlpha: true), true),
        // larger than the bitmap
        (matrix(20, 1, target: (10, 0), edgeMode: .wrap), false),
        (matrix(1, 15, target: (0, 3), edgeMode: .duplicate, divisor: 4), false)
    ] as [(Matrix, Bool)])
    func matchesTheDefinition(matrix: Matrix, linear: Bool) {
        let source = makeNoise(width: 11, height: 7)
        let result = FilterBitmap.convolve(source, matrix, linear: linear)
        #expect(result == naiveConvolve(source, matrix, linear: linear))
    }

    // the first value of a 1 × 3 kernel weights the pixel below the target: the image moves up a row,
    // or down when the bitmap's rows run up user space
    @Test(arguments: [(false, 1), (true, -1)] as [(Bool, Int)])
    func kernelFacesUserSpace(flipY: Bool, shift: Int) {
        var source = FilterBitmap(width: 1, height: 5)
        source.pixels.replaceSubrange(8..<12, with: [255, 0, 0, 255])
        let matrix = Matrix(orderX: 1, orderY: 3, kernelMatrix: [1, 0, 0], divisor: 1, bias: 0,
                            targetX: 0, targetY: 1, edgeMode: .none, preserveAlpha: false)
        let result = FilterBitmap.convolve(source, matrix, flipY: flipY, linear: false)
        #expect(result.pixel(x: 0, y: 2 - shift) == [255, 0, 0, 255])
        #expect(result.pixel(x: 0, y: 2)[3] == 0)
    }

    // preserveAlpha=true: colour is convolved on straight values, alpha is the input's
    @Test
    func preservesAlpha() {
        let source = FilterBitmap(width: 2, height: 1, pixels: [128, 0, 0, 128, 0, 0, 255, 255])
        let matrix = Matrix(orderX: 2, orderY: 1, kernelMatrix: [1, 1], divisor: 2, bias: 0,
                            targetX: 1, targetY: 0, edgeMode: .none, preserveAlpha: true)
        let result = FilterBitmap.convolve(source, matrix, linear: false)
        // pixel 1 sees itself and pixel 0: straight (1, 0, 0) and (0, 0, 1) average to half red, half blue
        #expect(result.pixel(x: 1, y: 0) == [128, 0, 128, 255])
        // pixel 0 sees only itself (edgeMode none): halved, at its own alpha
        #expect(result.pixel(x: 0, y: 0) == [64, 0, 0, 128])
    }

    // a hostile kernel over a large bitmap is not computed
    @Test
    func workIsBounded() {
        let source = FilterBitmap(width: 2048, height: 2048)
        let count = 64 * 64
        let matrix = Matrix(orderX: 64, orderY: 64, kernelMatrix: [Float](repeating: 1, count: count),
                            divisor: Float(count), bias: 0.5, targetX: 0, targetY: 0, edgeMode: .duplicate,
                            preserveAlpha: false)
        #expect(FilterBitmap.convolve(source, matrix, linear: false) == FilterBitmap(width: 2048, height: 2048))
    }
}

private extension FilterBitmapConvolveMatrixTests {

    // premultiplied pixels, deterministic
    func makeNoise(width: Int, height: Int) -> FilterBitmap {
        var state: UInt32 = 54321
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

    // RESULT(X, Y) = Σ SOURCE(X - targetX + J, Y - targetY + I) · kernelMatrix[orderX - J - 1, orderY - I - 1]
    // / divisor + bias · ALPHA(X, Y)
    func naiveConvolve(_ source: FilterBitmap, _ m: Matrix, linear: Bool) -> FilterBitmap {
        let width = source.width
        let height = source.height
        // premultiplied, or straight with preserveAlpha; nil beyond the bitmap with edgeMode none
        func value(_ x: Int, _ y: Int) -> [Float]? {
            var x = x
            var y = y
            switch m.edgeMode {
            case .none:
                guard x >= 0, x < width, y >= 0, y < height else { return nil }
            case .duplicate:
                x = min(max(x, 0), width - 1)
                y = min(max(y, 0), height - 1)
            case .wrap:
                x = ((x % width) + width) % width
                y = ((y % height) + height) % height
            }
            let p = source.pixel(x: x, y: y)
            let alpha = Float(p[3]) / 255
            var channels = (0..<3).map { channel -> Float in
                guard linear, p[3] > 0 else { return Float(p[channel]) / 255 }
                let straight = Float(min(255, (Int(p[channel]) * 255 + Int(p[3]) / 2) / Int(p[3]))) / 255
                let decoded = straight <= 0.04045 ? straight / 12.92 : Float(pow(Double((straight + 0.055) / 1.055), 2.4))
                return decoded * alpha
            }
            if m.preserveAlpha && alpha > 0 {
                channels = channels.map { $0 / alpha }
            }
            return channels + [alpha]
        }
        var result = FilterBitmap(width: width, height: height)
        for y in 0..<height {
            for x in 0..<width {
                var sum: [Float] = [0, 0, 0, 0]
                for i in 0..<m.orderY {
                    for j in 0..<m.orderX {
                        let k = m.kernelMatrix[(m.orderY - i - 1) * m.orderX + (m.orderX - j - 1)]
                        guard k != 0, let s = value(x - m.targetX + j, y - m.targetY + i) else { continue }
                        for c in 0..<4 { sum[c] += s[c] * k }
                    }
                }
                let pixel: FilterPixel
                if m.preserveAlpha {
                    let alpha = value(x, y)![3]
                    func channel(_ c: Int) -> Float { min(max(sum[c] / m.divisor + m.bias * alpha, 0), 1) * alpha }
                    pixel = FilterPixel(r: channel(0), g: channel(1), b: channel(2), a: alpha)
                } else {
                    let alpha = sum[3] / m.divisor + m.bias
                    func channel(_ c: Int) -> Float { sum[c] / m.divisor + m.bias * alpha }
                    pixel = FilterPixel(r: channel(0), g: channel(1), b: channel(2), a: alpha)
                }
                result.pixels.replaceSubrange(((y * width + x) * 4)..<((y * width + x) * 4 + 4),
                                              with: FilterBitmap.encode(pixel, linear: linear))
            }
        }
        return result
    }
}
