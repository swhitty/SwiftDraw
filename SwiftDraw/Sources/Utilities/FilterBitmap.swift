//
//  FilterBitmap.swift
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

import Foundation
import SwiftDrawDOM

// A premultiplied RGBA image, 8 bits per channel, rows top to bottom without padding: the offscreen of a
// filter layer, on which the filter primitives are evaluated (SD12). Platform independent.
//
// Values are stored in the encoding of the drawing (sRGB). Primitives in linearRGB (Filter Effects 1 §10)
// decode to linear light, compute, and encode again per pixel, so storage never quantizes linear values.
// Blur and offset only move pixels and work on the stored values.
struct FilterBitmap: Equatable {
    var width: Int
    var height: Int
    var pixels: [UInt8]

    // transparent black
    init(width: Int, height: Int) {
        self.width = max(0, width)
        self.height = max(0, height)
        self.pixels = [UInt8](repeating: 0, count: self.width * self.height * 4)
    }

    init(width: Int, height: Int, pixels: [UInt8]) {
        precondition(pixels.count == width * height * 4)
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    // r, g, b, a
    func pixel(x: Int, y: Int) -> [UInt8] {
        let i = (y * width + x) * 4
        return Array(pixels[i..<i + 4])
    }
}

// MARK: - Filter evaluation

extension LayerTree.FilterLayer {

    struct Environment {
        // user space to the pixel space of the bitmaps: x right, y down, pixel centres at +0.5
        var transform: LayerTree.Transform.Matrix
        // blurs a bitmap in place by standard deviations in pixels along x and y
        var blur: (inout FilterBitmap, Float, Float) -> Void
        // straight (non-premultiplied) RGBA of a colour in the encoding of the bitmaps
        var color: (LayerTree.Color) -> SIMD4<Float> = FilterBitmap.components(of:)
    }

    // The result of the last primitive, given SourceGraphic: the layer contents drawn over the filter region.
    func evaluate(source: FilterBitmap, environment: Environment) -> FilterBitmap {
        let width = source.width
        let height = source.height
        let lastUse = lastUses

        var results = [FilterBitmap?](repeating: nil, count: primitives.count)
        var sourceAlpha: FilterBitmap?

        for (index, primitive) in primitives.enumerated() {
            func input(_ n: Int) -> FilterBitmap {
                guard n < primitive.inputs.count else { return FilterBitmap(width: width, height: height) }
                switch primitive.inputs[n] {
                case .sourceGraphic:
                    return source
                case .sourceAlpha:
                    if sourceAlpha == nil {
                        sourceAlpha = FilterBitmap.sourceAlpha(of: source)
                    }
                    return sourceAlpha!
                case .transparent:
                    return FilterBitmap(width: width, height: height)
                case .primitive(let other):
                    // the last reader takes the bitmap: it can then be changed in place without a copy
                    if lastUse[other] == index && primitive.inputs.count == 1 {
                        defer { results[other] = nil }
                        return results[other] ?? FilterBitmap(width: width, height: height)
                    }
                    return results[other] ?? FilterBitmap(width: width, height: height)
                }
            }

            var result: FilterBitmap
            let isLinear = primitive.colorInterpolation == .linearRGB
            if primitive.subregion.width <= 0 || primitive.subregion.height <= 0 {
                // Filter Effects 1 §9.4: a disabled primitive is transparent black
                result = FilterBitmap(width: width, height: height)
            } else {
                switch primitive.effect {
                case let .gaussianBlur(stdDeviation: x, stdDeviationY: y):
                    result = input(0)
                    let deviation = environment.transform.deviation(x, y)
                    environment.blur(&result, deviation.x, deviation.y)
                case let .offset(dx: dx, dy: dy):
                    let vector = environment.transform.vector(dx, dy)
                    result = FilterBitmap.offset(input(0), dx: vector.x, dy: vector.y)
                case .flood(let color):
                    result = FilterBitmap.flood(width: width, height: height, color: environment.color(color))
                case .composite(let op):
                    result = FilterBitmap.composite(input(0), input(1), op: op, linear: isLinear)
                case .merge:
                    result = FilterBitmap.merge(primitive.inputs.indices.map(input), width: width, height: height, linear: isLinear)
                case .blend(let mode):
                    result = FilterBitmap.blend(input(0), input(1), mode: mode, linear: isLinear)
                case .colorMatrix(let matrix):
                    result = FilterBitmap.colorMatrix(input(0), matrix: matrix, linear: isLinear)
                }
                result.clip(to: primitive.subregion, transform: environment.transform)
            }
            results[index] = result

            for case .primitive(let other) in primitive.inputs where lastUse[other] == index {
                results[other] = nil
            }
            if lastUse.sourceAlpha == index {
                sourceAlpha = nil
            }
        }

        return results.last.flatMap { $0 } ?? FilterBitmap(width: width, height: height)
    }

    // An upper bound of the bitmaps alive at once while evaluating, SourceGraphic included,
    // so renderers can keep the total within their pixel budget.
    var peakBitmapCount: Int {
        let lastUse = lastUses
        var peak = 1
        for (index, primitive) in primitives.enumerated() {
            // results still needed, SourceGraphic, SourceAlpha, transparent inputs and the result itself
            var alive = (0..<index).filter { lastUse[$0] >= index }.count + 2
            if lastUse.sourceAlpha >= index && primitives.prefix(index + 1).contains(where: { $0.inputs.contains(.sourceAlpha) }) {
                alive += 1
            }
            alive += primitive.inputs.filter { $0 == .transparent }.count
            peak = max(peak, alive)
        }
        return peak
    }

    // the index of the last primitive reading each result (-1 when unread), and SourceAlpha
    private var lastUses: LastUses {
        var uses = LastUses(primitives: [Int](repeating: -1, count: primitives.count))
        for (index, primitive) in primitives.enumerated() {
            for input in primitive.inputs {
                switch input {
                case .primitive(let other):
                    uses.primitives[other] = index
                case .sourceAlpha:
                    uses.sourceAlpha = index
                case .sourceGraphic, .transparent:
                    break
                }
            }
        }
        return uses
    }

    private struct LastUses {
        var primitives: [Int]
        var sourceAlpha = -1

        subscript(index: Int) -> Int {
            primitives[index]
        }
    }
}

private extension LayerTree.Transform.Matrix {

    // stdDeviation along the pixel axes; exact for scale and 90° rotations, an approximation otherwise
    func deviation(_ x: Float, _ y: Float) -> (x: Float, y: Float) {
        let dx = (a * x).hypot(c * y)
        let dy = (b * x).hypot(d * y)
        return (dx.isFinite ? dx : 0, dy.isFinite ? dy : 0)
    }

    func vector(_ x: Float, _ y: Float) -> (x: Float, y: Float) {
        let vx = a * x + c * y
        let vy = b * x + d * y
        return (vx.isFinite ? vx : 0, vy.isFinite ? vy : 0)
    }

    func invertedMatrix() -> Self? {
        let determinant = a * d - b * c
        guard determinant != 0, determinant.isFinite else { return nil }
        return Self(a: d / determinant, b: -b / determinant,
                    c: -c / determinant, d: a / determinant,
                    tx: (c * ty - d * tx) / determinant,
                    ty: (b * tx - a * ty) / determinant)
    }
}

private extension Float {
    func hypot(_ other: Float) -> Float {
        (self * self + other * other).squareRoot()
    }
}

// MARK: - Primitives

extension FilterBitmap {

    // Filter Effects 1 §9.2: the alpha of SourceGraphic with black colour channels
    static func sourceAlpha(of source: FilterBitmap) -> FilterBitmap {
        var result = FilterBitmap(width: source.width, height: source.height)
        source.pixels.withUnsafeBufferPointer { src in
            result.pixels.withUnsafeMutableBufferPointer { dst in
                var i = 3
                while i < src.count {
                    dst[i] = src[i]
                    i += 4
                }
            }
        }
        return result
    }

    // Filter Effects 1 §9.13: the whole bitmap, later clipped to the subregion.
    // color-interpolation-filters does not apply to feFlood (Filter Effects 1 §10).
    static func flood(width: Int, height: Int, color: SIMD4<Float>) -> FilterBitmap {
        var result = FilterBitmap(width: width, height: height)
        var premultiplied = color
        premultiplied.x *= color.w
        premultiplied.y *= color.w
        premultiplied.z *= color.w
        var pixel: [UInt8] = [0, 0, 0, 0]
        pixel.withUnsafeMutableBufferPointer { store(premultiplied, $0.baseAddress!, 0, linear: false) }
        guard pixel != [0, 0, 0, 0] else { return result }
        result.pixels.withUnsafeMutableBufferPointer { dst in
            var i = 0
            while i < dst.count {
                dst[i] = pixel[0]
                dst[i + 1] = pixel[1]
                dst[i + 2] = pixel[2]
                dst[i + 3] = pixel[3]
                i += 4
            }
        }
        return result
    }

    // Filter Effects 1 §9.18: shifted by a vector in pixels; uncovered pixels are transparent black and
    // fractional offsets are interpolated bilinearly.
    static func offset(_ source: FilterBitmap, dx: Float, dy: Float) -> FilterBitmap {
        let width = source.width
        let height = source.height
        // offsets beyond the bitmap leave nothing
        guard abs(dx) < Float(width), abs(dy) < Float(height) else {
            return FilterBitmap(width: width, height: height)
        }

        let ix = Int(dx.rounded(.down))
        let iy = Int(dy.rounded(.down))
        var fx = dx - Float(ix)
        var fy = dy - Float(iy)
        // within a thousandth of a pixel the offset is whole: copy exactly
        if fx < 0.001 { fx = 0 }
        if fy < 0.001 { fy = 0 }
        var sx = ix
        var sy = iy
        if fx > 0.999 { fx = 0; sx += 1 }
        if fy > 0.999 { fy = 0; sy += 1 }

        var result = FilterBitmap(width: width, height: height)
        source.pixels.withUnsafeBufferPointer { src in
            result.pixels.withUnsafeMutableBufferPointer { dst in
                // a destination pixel (x, y) reads the source at (x - sx - 1, y - sy - 1) ... (x - sx, y - sy)
                // weighted fx, fy towards the first
                func sample(_ x: Int, _ y: Int) -> SIMD4<Float> {
                    guard x >= 0, y >= 0, x < width, y < height else { return .zero }
                    let i = (y * width + x) * 4
                    return SIMD4(Float(src[i]), Float(src[i + 1]), Float(src[i + 2]), Float(src[i + 3]))
                }
                for y in 0..<height {
                    let y1 = y - sy
                    let y0 = y1 - 1
                    if fy == 0 && (y1 < 0 || y1 >= height) { continue }
                    for x in 0..<width {
                        let x1 = x - sx
                        let o = (y * width + x) * 4
                        if fx == 0 && fy == 0 {
                            guard x1 >= 0, x1 < width else { continue }
                            let i = (y1 * width + x1) * 4
                            dst[o] = src[i]
                            dst[o + 1] = src[i + 1]
                            dst[o + 2] = src[i + 2]
                            dst[o + 3] = src[i + 3]
                            continue
                        }
                        let x0 = x1 - 1
                        var value = sample(x1, y1) * ((1 - fx) * (1 - fy))
                        if fx > 0 { value += sample(x0, y1) * (fx * (1 - fy)) }
                        if fy > 0 { value += sample(x1, y0) * ((1 - fx) * fy) }
                        if fx > 0 && fy > 0 { value += sample(x0, y0) * (fx * fy) }
                        let rounded = (value + 0.5).clamped(lowerBound: .zero, upperBound: SIMD4(repeating: 255))
                        dst[o] = UInt8(rounded.x)
                        dst[o + 1] = UInt8(rounded.y)
                        dst[o + 2] = UInt8(rounded.z)
                        dst[o + 3] = UInt8(rounded.w)
                    }
                }
            }
        }
        return result
    }

    // Filter Effects 1 §9.8: `a` (in) is the source and `b` (in2) the destination of the Porter-Duff operator
    // (Compositing and Blending 1 §9.1); arithmetic is clamped to 0...1 with colour never above alpha.
    static func composite(_ a: FilterBitmap, _ b: FilterBitmap, op: DOM.Filter.CompositeOperator, linear: Bool) -> FilterBitmap {
        switch op {
        case .over:
            return combine(a, b, linear: linear) { s, d in s + d * (1 - s.w) }
        case .in:
            return combine(a, b, linear: linear) { s, d in s * d.w }
        case .out:
            return combine(a, b, linear: linear) { s, d in s * (1 - d.w) }
        case .atop:
            return combine(a, b, linear: linear) { s, d in s * d.w + d * (1 - s.w) }
        case .xor:
            return combine(a, b, linear: linear) { s, d in s * (1 - d.w) + d * (1 - s.w) }
        case .lighter:
            return combine(a, b, linear: linear) { s, d in s + d }
        case let .arithmetic(k1: k1, k2: k2, k3: k3, k4: k4):
            let k1 = Float(k1), k2 = Float(k2), k3 = Float(k3), k4 = Float(k4)
            return combine(a, b, linear: linear) { i1, i2 in
                k1 * i1 * i2 + k2 * i1 + k3 * i2 + SIMD4(repeating: k4)
            }
        }
    }

    // Filter Effects 1 §9.16: the inputs composited with `over`, the first at the bottom
    static func merge(_ inputs: [FilterBitmap], width: Int, height: Int, linear: Bool) -> FilterBitmap {
        guard var result = inputs.first else { return FilterBitmap(width: width, height: height) }
        for input in inputs.dropFirst() {
            result = combine(input, result, linear: linear) { s, d in s + d * (1 - s.w) }
        }
        return result
    }

    // Filter Effects 1 §9.5, Compositing and Blending 1 §5.8 and §10: `a` (in) is the source Cs,
    // `b` (in2) the backdrop Cb, blended then composited with source-over.
    static func blend(_ a: FilterBitmap, _ b: FilterBitmap, mode: DOM.Filter.BlendMode, linear: Bool) -> FilterBitmap {
        combine(a, b, linear: linear) { s, d in
            let alphaS = s.w
            let alphaB = d.w
            var result = s * (1 - alphaB) + d * (1 - alphaS)
            guard alphaS > 0, alphaB > 0 else { return result }
            let cs = SIMD3(s.x, s.y, s.z) / alphaS
            let cb = SIMD3(d.x, d.y, d.z) / alphaB
            let mixed = blendColor(cb, cs, mode: mode) * (alphaS * alphaB)
            result.x += mixed.x
            result.y += mixed.y
            result.z += mixed.z
            result.w += alphaS * alphaB
            return result
        }
    }

    // Filter Effects 1 §9.6: on non-premultiplied values, clamped to 0...1
    static func colorMatrix(_ source: FilterBitmap, matrix: [Float], linear: Bool) -> FilterBitmap {
        guard matrix.count == 20 else { return source }
        let m = matrix
        return map(source, linear: linear) { p in
            var c = p
            if c.w > 0 {
                c.x /= c.w
                c.y /= c.w
                c.z /= c.w
            }
            var out = SIMD4<Float>(
                m[0] * c.x + m[1] * c.y + m[2] * c.z + m[3] * c.w + m[4],
                m[5] * c.x + m[6] * c.y + m[7] * c.z + m[8] * c.w + m[9],
                m[10] * c.x + m[11] * c.y + m[12] * c.z + m[13] * c.w + m[14],
                m[15] * c.x + m[16] * c.y + m[17] * c.z + m[18] * c.w + m[19]
            )
            out.replace(with: 0, where: out .!= out)
            out.clamp(lowerBound: .zero, upperBound: SIMD4(repeating: 1))
            out.x *= out.w
            out.y *= out.w
            out.z *= out.w
            return out
        }
    }

    // Filter Effects 1 §9.4: pixels whose centre falls outside the subregion become transparent black
    mutating func clip(to rect: LayerTree.Rect, transform: LayerTree.Transform.Matrix) {
        let corners = [
            LayerTree.Point(rect.minX, rect.minY),
            LayerTree.Point(rect.maxX, rect.minY),
            LayerTree.Point(rect.maxX, rect.maxY),
            LayerTree.Point(rect.minX, rect.maxY)
        ].map(transform.transform(point:))
        let isAxisAligned = (transform.b == 0 && transform.c == 0) || (transform.a == 0 && transform.d == 0)

        if isAxisAligned {
            let xs = corners.map(\.x)
            let ys = corners.map(\.y)
            // whole columns and rows with their centre inside
            let minX = Swift.max(0, Swift.min(width, Int((xs.min()! - 0.5).rounded(.up).clamped(-1, Float(width)))))
            let maxX = Swift.max(minX, Swift.min(width, Int((xs.max()! - 0.5).rounded(.up).clamped(-1, Float(width)))))
            let minY = Swift.max(0, Swift.min(height, Int((ys.min()! - 0.5).rounded(.up).clamped(-1, Float(height)))))
            let maxY = Swift.max(minY, Swift.min(height, Int((ys.max()! - 0.5).rounded(.up).clamped(-1, Float(height)))))
            guard minX > 0 || minY > 0 || maxX < width || maxY < height else { return }
            let w = width
            pixels.withUnsafeMutableBufferPointer { dst in
                for y in 0..<height {
                    let row = y * w * 4
                    if y < minY || y >= maxY {
                        for i in row..<(row + w * 4) { dst[i] = 0 }
                        continue
                    }
                    for i in row..<(row + minX * 4) { dst[i] = 0 }
                    for i in (row + maxX * 4)..<(row + w * 4) { dst[i] = 0 }
                }
            }
            return
        }

        // rotated or skewed: test each pixel centre in user space
        guard let inverse = transform.invertedMatrix() else {
            pixels = [UInt8](repeating: 0, count: pixels.count)
            return
        }
        let w = width
        let h = height
        pixels.withUnsafeMutableBufferPointer { dst in
            for y in 0..<h {
                for x in 0..<w {
                    let p = inverse.transform(point: LayerTree.Point(Float(x) + 0.5, Float(y) + 0.5))
                    guard p.x < rect.minX || p.x >= rect.maxX || p.y < rect.minY || p.y >= rect.maxY else { continue }
                    let i = (y * w + x) * 4
                    dst[i] = 0
                    dst[i + 1] = 0
                    dst[i + 2] = 0
                    dst[i + 3] = 0
                }
            }
        }
    }

    // straight RGBA of a colour, sRGB and Display P3 components alike (renderers convert between spaces)
    static func components(of color: LayerTree.Color) -> SIMD4<Float> {
        switch color {
        case .none:
            return .zero
        case let .rgba(r: r, g: g, b: b, a: a, space: _):
            return SIMD4(r, g, b, a)
        case let .gray(white: white, a: a):
            return SIMD4(white, white, white, a)
        }
    }
}

// MARK: - Pixel access

private extension FilterBitmap {

    static func combine(_ a: FilterBitmap, _ b: FilterBitmap, linear: Bool,
                        _ op: (SIMD4<Float>, SIMD4<Float>) -> SIMD4<Float>) -> FilterBitmap {
        precondition(a.pixels.count == b.pixels.count)
        var result = FilterBitmap(width: a.width, height: a.height)
        a.pixels.withUnsafeBufferPointer { pa in
            b.pixels.withUnsafeBufferPointer { pb in
                result.pixels.withUnsafeMutableBufferPointer { dst in
                    var i = 0
                    while i < dst.count {
                        let value = op(load(pa.baseAddress!, i, linear: linear), load(pb.baseAddress!, i, linear: linear))
                        store(value, dst.baseAddress!, i, linear: linear)
                        i += 4
                    }
                }
            }
        }
        return result
    }

    static func map(_ source: FilterBitmap, linear: Bool, _ op: (SIMD4<Float>) -> SIMD4<Float>) -> FilterBitmap {
        var result = FilterBitmap(width: source.width, height: source.height)
        source.pixels.withUnsafeBufferPointer { src in
            result.pixels.withUnsafeMutableBufferPointer { dst in
                var i = 0
                while i < dst.count {
                    store(op(load(src.baseAddress!, i, linear: linear)), dst.baseAddress!, i, linear: linear)
                    i += 4
                }
            }
        }
        return result
    }

    // premultiplied, 0...1, in linear light when linear
    @inline(__always)
    static func load(_ p: UnsafePointer<UInt8>, _ i: Int, linear: Bool) -> SIMD4<Float> {
        let a = p[i + 3]
        guard linear, a > 0 else {
            return SIMD4(Float(p[i]), Float(p[i + 1]), Float(p[i + 2]), Float(a)) / 255
        }
        let alpha = Float(a) / 255
        return SIMD4(decode(p[i], a) * alpha, decode(p[i + 1], a) * alpha, decode(p[i + 2], a) * alpha, alpha)
    }

    // clamped to 0...1 with colour never above alpha (premultiplied), then rounded
    @inline(__always)
    static func store(_ value: SIMD4<Float>, _ p: UnsafeMutablePointer<UInt8>, _ i: Int, linear: Bool) {
        var v = value
        v.replace(with: 0, where: v .!= v)
        v.clamp(lowerBound: .zero, upperBound: SIMD4(repeating: 1))
        v.x = Swift.min(v.x, v.w)
        v.y = Swift.min(v.y, v.w)
        v.z = Swift.min(v.z, v.w)
        if linear && v.w > 0 {
            v.x = encode(v.x / v.w) * v.w
            v.y = encode(v.y / v.w) * v.w
            v.z = encode(v.z / v.w) * v.w
        }
        let rounded = v * 255 + 0.5
        p[i] = UInt8(rounded.x)
        p[i + 1] = UInt8(rounded.y)
        p[i + 2] = UInt8(rounded.z)
        p[i + 3] = UInt8(rounded.w)
    }

    // a premultiplied channel to its straight value in linear light
    @inline(__always)
    static func decode(_ c: UInt8, _ a: UInt8) -> Float {
        let straight = Swift.min(255, (Int(c) * 255 + Int(a) / 2) / Int(a))
        return linearTable[straight]
    }

    // linear light 0...1 to the sRGB encoding 0...1
    @inline(__always)
    static func encode(_ linear: Float) -> Float {
        let index = Int(linear * Float(encodingTable.count - 1) + 0.5)
        return encodingTable[Swift.max(0, Swift.min(encodingTable.count - 1, index))]
    }

    // sRGB transfer function (IEC 61966-2-1)
    static let linearTable: [Float] = (0...255).map { value in
        let c = Float(value) / 255
        return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    static let encodingTable: [Float] = (0..<8192).map { index in
        let l = Float(index) / 8191
        return l <= 0.0031308 ? l * 12.92 : 1.055 * pow(l, 1 / 2.4) - 0.055
    }
}

private extension Float {
    func clamped(_ lower: Float, _ upper: Float) -> Float {
        guard !isNaN else { return lower }
        return Swift.max(lower, Swift.min(upper, self))
    }
}

// MARK: - Blend modes

private extension FilterBitmap {

    // Compositing and Blending 1 §10: B(Cb, Cs) on straight colours
    static func blendColor(_ cb: SIMD3<Float>, _ cs: SIMD3<Float>, mode: DOM.Filter.BlendMode) -> SIMD3<Float> {
        switch mode {
        case .normal:
            return cs
        case .multiply:
            return cb * cs
        case .screen:
            return cb + cs - cb * cs
        case .overlay:
            return separable(cb, cs) { b, s in hardLight(s, b) }
        case .darken:
            return pointwiseMin(cb, cs)
        case .lighten:
            return pointwiseMax(cb, cs)
        case .colorDodge:
            return separable(cb, cs) { b, s in
                if b == 0 { return 0 }
                if s >= 1 { return 1 }
                return Swift.min(1, b / (1 - s))
            }
        case .colorBurn:
            return separable(cb, cs) { b, s in
                if b >= 1 { return 1 }
                if s <= 0 { return 0 }
                return 1 - Swift.min(1, (1 - b) / s)
            }
        case .hardLight:
            return separable(cb, cs, hardLight)
        case .softLight:
            return separable(cb, cs) { b, s in
                if s <= 0.5 {
                    return b - (1 - 2 * s) * b * (1 - b)
                }
                let d = b <= 0.25 ? ((16 * b - 12) * b + 4) * b : b.squareRoot()
                return b + (2 * s - 1) * (d - b)
            }
        case .difference:
            return separable(cb, cs) { b, s in abs(b - s) }
        case .exclusion:
            return cb + cs - 2 * cb * cs
        case .hue:
            return setLum(setSat(cs, sat(cb)), lum(cb))
        case .saturation:
            return setLum(setSat(cb, sat(cs)), lum(cb))
        case .color:
            return setLum(cs, lum(cb))
        case .luminosity:
            return setLum(cb, lum(cs))
        }
    }

    static func separable(_ cb: SIMD3<Float>, _ cs: SIMD3<Float>, _ f: (Float, Float) -> Float) -> SIMD3<Float> {
        SIMD3(f(cb.x, cs.x), f(cb.y, cs.y), f(cb.z, cs.z))
    }

    static func hardLight(_ b: Float, _ s: Float) -> Float {
        if s <= 0.5 {
            return b * 2 * s
        }
        let t = 2 * s - 1
        return b + t - b * t
    }

    static func lum(_ c: SIMD3<Float>) -> Float {
        0.3 * c.x + 0.59 * c.y + 0.11 * c.z
    }

    static func clipColor(_ c: SIMD3<Float>) -> SIMD3<Float> {
        let l = lum(c)
        let n = c.min()
        let x = c.max()
        var c = c
        if n < 0 {
            c = SIMD3(repeating: l) + (c - SIMD3(repeating: l)) * l / (l - n)
        }
        if x > 1 {
            c = SIMD3(repeating: l) + (c - SIMD3(repeating: l)) * (1 - l) / (x - l)
        }
        return c
    }

    static func setLum(_ c: SIMD3<Float>, _ l: Float) -> SIMD3<Float> {
        clipColor(c + SIMD3(repeating: l - lum(c)))
    }

    static func sat(_ c: SIMD3<Float>) -> Float {
        c.max() - c.min()
    }

    static func setSat(_ c: SIMD3<Float>, _ s: Float) -> SIMD3<Float> {
        let maximum = c.max()
        let minimum = c.min()
        guard maximum > minimum else { return .zero }
        return (c - SIMD3(repeating: minimum)) * s / (maximum - minimum)
    }
}
