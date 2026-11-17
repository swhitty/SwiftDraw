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
        // the pixels an feImage primitive (by index) draws, rasterized through `transform` at the size of the
        // bitmaps; nil draws nothing
        var image: (Int) -> FilterBitmap? = { _ in nil }
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
                    environment.gaussianBlur(&result, stdDeviation: x, stdDeviationY: y)
                case let .offset(dx: dx, dy: dy):
                    let vector = environment.transform.vector(dx, dy)
                    result = FilterBitmap.offset(input(0), dx: vector.x, dy: vector.y)
                case .flood(let color):
                    result = FilterBitmap.flood(width: width, height: height, color: environment.color(color))
                case .composite(let op):
                    result = FilterBitmap.composite(input(0), input(1), op: op, linear: isLinear)
                case .merge:
                    result = FilterBitmap.merge(
                        primitive.inputs.indices.map(input),
                        width: width,
                        height: height,
                        linear: isLinear
                    )
                case .blend(let mode):
                    result = FilterBitmap.blend(input(0), input(1), mode: mode, linear: isLinear)
                case .colorMatrix(let matrix):
                    result = FilterBitmap.colorMatrix(input(0), matrix: matrix, linear: isLinear)
                case .componentTransfer(let transfer):
                    result = FilterBitmap.componentTransfer(input(0), transfer, linear: isLinear)
                case let .morphology(op, radiusX: rx, radiusY: ry):
                    let radius = environment.transform.pixelRadius(rx, ry)
                    result = FilterBitmap.morphology(
                        input(0),
                        op,
                        radiusX: radius.x,
                        radiusY: radius.y,
                        linear: isLinear
                    )
                case .turbulence(let turbulence):
                    result = FilterBitmap.turbulence(
                        width: width,
                        height: height,
                        turbulence,
                        tile: primitive.subregion,
                        transform: environment.transform,
                        linear: isLinear
                    )
                case .convolveMatrix(let matrix):
                    // the kernel stays on the pixel axes, facing user space's x and y (it is not rotated)
                    result = FilterBitmap.convolve(
                        input(0),
                        matrix,
                        flipX: environment.transform.a < 0,
                        flipY: environment.transform.d < 0,
                        linear: isLinear
                    )
                case .image:
                    // drawn in the encoding of the bitmaps, which linearRGB primitives decode as they read it
                    result =
                        environment.image(index).flatMap { $0.width == width && $0.height == height ? $0 : nil }
                        ?? FilterBitmap(width: width, height: height)
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
            if lastUse.sourceAlpha >= index
                && primitives.prefix(index + 1).contains(where: { $0.inputs.contains(.sourceAlpha) })
            {
                alive += 1
            }
            alive += primitive.inputs.filter { $0 == .transparent }.count
            switch primitive.effect {
            case .morphology, .convolveMatrix:
                // its four channels as Float
                alive += 4
            case .image:
                // the context it is rasterized in
                alive += 1
            default:
                break
            }
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

extension LayerTree.FilterLayer.Environment {

    // Filter Effects 1 §9.14: a blur by stdDeviation along the user space axes, in pixels. Its covariance in
    // pixel space is M·diag(x², y²)·Mᵀ. When that is diagonal (scale, 90° rotations or an isotropic blur under
    // rotation) the blur is along the pixel axes. Otherwise it is split into a blur along one pixel axis and
    // one along a sheared direction, which is the same covariance (resvg and WebKit blur in user space).
    func gaussianBlur(_ bitmap: inout FilterBitmap, stdDeviation x: Float, stdDeviationY y: Float) {
        guard let shear = transform.blurShear(x, y) else {
            let deviation = transform.deviation(x, y)
            blur(&bitmap, deviation.x, deviation.y)
            return
        }
        if shear.isTransposed {
            bitmap = bitmap.transposed()
        }
        let width = bitmap.width
        blur(&bitmap, shear.across, 0)
        bitmap = bitmap.shearingRows(by: shear.slope)
        blur(&bitmap, 0, shear.along)
        bitmap = bitmap.unshearingRows(by: shear.slope, width: width)
        if shear.isTransposed {
            bitmap = bitmap.transposed()
        }
    }
}

extension LayerTree.Transform.Matrix {

    // stdDeviation along the pixel axes: the square roots of the diagonal of the pixel space covariance
    func deviation(_ x: Float, _ y: Float) -> (x: Float, y: Float) {
        let dx = (a * x).hypot(c * y)
        let dy = (b * x).hypot(d * y)
        return (dx.isFinite ? dx : 0, dy.isFinite ? dy : 0)
    }

    // A blur that is not along the pixel axes, as covariance Σ = [[p, q], [q, r]] = α·eₓeₓᵀ + β·v·vᵀ with
    // v = (slope, 1): a blur of √α across (along x) then of √β along v. The axis with the larger variance
    // takes the shear so |slope| ≤ 1; when that is x the bitmap is transposed first. nil when Σ is diagonal.
    func blurShear(_ x: Float, _ y: Float) -> (across: Float, along: Float, slope: Float, isTransposed: Bool)? {
        let vx = x * x
        let vy = y * y
        var p = a * a * vx + c * c * vy
        var r = b * b * vx + d * d * vy
        let q = a * b * vx + c * d * vy
        guard p.isFinite, r.isFinite, q.isFinite, p > 0, r > 0,
            // within a thousandth of the deviations the blur is along the axes
            q * q > 1e-6 * p * r
        else { return nil }
        let isTransposed = p > r
        if isTransposed {
            swap(&p, &r)
        }
        let slope = q / r
        let across = max(0, p - q * slope).squareRoot()
        return (across, r.squareRoot(), slope, isTransposed)
    }

    // Filter Effects 1 §9.17: a radius in user units as whole pixels along the pixel axes (the extent of the
    // rectangle, as for a blur), rounded down
    // as WebKit and Chrome do, and at most a million (beyond the bitmap, every window is the whole row)
    func pixelRadius(_ x: Float, _ y: Float) -> (x: Int, y: Int) {
        func whole(_ value: Float) -> Int {
            // a little tolerance so 10 × 1.5 is 15, not 14.999…; an overflow is the largest radius
            let value = (value + 0.001).rounded(.down)
            guard value >= 1 else { return 0 }
            return Int(Swift.min(value, 1_000_000))
        }
        return (whole((a * x).hypot(c * y)), whole((b * x).hypot(d * y)))
    }

    func vector(_ x: Float, _ y: Float) -> (x: Float, y: Float) {
        let vx = a * x + c * y
        let vy = b * x + d * y
        return (vx.isFinite ? vx : 0, vy.isFinite ? vy : 0)
    }

    func invertedMatrix() -> Self? {
        let determinant = a * d - b * c
        guard determinant != 0, determinant.isFinite else { return nil }
        return Self(
            a: d / determinant,
            b: -b / determinant,
            c: -c / determinant,
            d: a / determinant,
            tx: (c * ty - d * tx) / determinant,
            ty: (b * tx - a * ty) / determinant
        )
    }
}

private extension Float {
    func hypot(_ other: Float) -> Float {
        (self * self + other * other).squareRoot()
    }
}

// MARK: - Shearing

extension FilterBitmap {

    // rows and columns swapped
    func transposed() -> FilterBitmap {
        var result = FilterBitmap(width: height, height: width)
        pixels.withUnsafeBytes { src in
            result.pixels.withUnsafeMutableBytes { dst in
                for y in 0..<height {
                    for x in 0..<width {
                        let s = (y * width + x) * 4
                        let d = (x * height + y) * 4
                        dst[d] = src[s]; dst[d + 1] = src[s + 1]; dst[d + 2] = src[s + 2]; dst[d + 3] = src[s + 3]
                    }
                }
            }
        }
        return result
    }

    // How far rows are shifted right so that the line x = x₀ + slope·y becomes a column: never negative
    static func shearOrigin(slope: Float, height: Int) -> Float {
        max(0, slope * Float(max(height - 1, 0)))
    }

    // Each row shifted so that a line of the slope (x = x₀ + slope·y) becomes vertical, widened to keep it all
    func shearingRows(by slope: Float) -> FilterBitmap {
        let origin = Self.shearOrigin(slope: slope, height: height)
        let extra = Int((abs(slope) * Float(max(height - 1, 0))).rounded(.up)) + 1
        return shiftingRows(width: width + extra) { y in origin - slope * Float(y) }
    }

    // The inverse of shearingRows, back to the original width
    func unshearingRows(by slope: Float, width: Int) -> FilterBitmap {
        let origin = Self.shearOrigin(slope: slope, height: height)
        return shiftingRows(width: width) { y in slope * Float(y) - origin }
    }

    // Each row y moved right by shift(y) pixels into a bitmap of the width, interpolated linearly
    func shiftingRows(width newWidth: Int, by shift: (Int) -> Float) -> FilterBitmap {
        var result = FilterBitmap(width: newWidth, height: height)
        let width = width
        pixels.withUnsafeBytes { src in
            result.pixels.withUnsafeMutableBytes { dst in
                for y in 0..<height {
                    let offset = shift(y)
                    let whole = Int(offset.rounded(.down))
                    // 8-bit fixed point weight of the source pixel before
                    let w = Int(((offset - Float(whole)) * 256).rounded())
                    let row = y * width * 4
                    let out = y * newWidth * 4
                    for x in 0..<newWidth {
                        // destination x reads the source at x - offset: between sx - 1 (weight w) and sx
                        let sx = x - whole
                        let hasCurrent = sx >= 0 && sx < width
                        let hasPrevious = sx - 1 >= 0 && sx - 1 < width
                        guard hasCurrent || hasPrevious else { continue }
                        for channel in 0..<4 {
                            let current = hasCurrent ? Int(src[row + sx * 4 + channel]) : 0
                            let previous = hasPrevious ? Int(src[row + (sx - 1) * 4 + channel]) : 0
                            dst[out + x * 4 + channel] = UInt8((current * (256 - w) + previous * w + 128) >> 8)
                        }
                    }
                }
            }
        }
        return result
    }
}

// MARK: - Primitives

extension FilterBitmap {

    // Filter Effects 1 §9.2: the alpha of SourceGraphic with black colour channels
    static func sourceAlpha(of source: FilterBitmap) -> FilterBitmap {
        var result = FilterBitmap(width: source.width, height: source.height)
        source.pixels.withUnsafeBufferPointer { src in
            result.pixels.withUnsafeMutableBufferPointer { dst in
                guard let s = src.baseAddress, let d = dst.baseAddress else { return }
                let count = src.count
                var i = 3
                while i < count {
                    d[i] = s[i]
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
        let pixel = encode(
            FilterPixel(r: color.x * color.w, g: color.y * color.w, b: color.z * color.w, a: color.w),
            linear: false
        )
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

    // the stored bytes of a premultiplied pixel, r first
    static func encode(_ pixel: FilterPixel, linear: Bool) -> [UInt8] {
        // not stored through a pointer into a local array: optimized builds (Swift 6.4, -O) kept only the
        // first byte, so every flood was transparent in Release while Debug tests passed
        let bytes = quantize(pixel, linear: linear, encoding: encodingTable)
        return [
            UInt8(truncatingIfNeeded: bytes), UInt8(truncatingIfNeeded: bytes >> 8),
            UInt8(truncatingIfNeeded: bytes >> 16), UInt8(truncatingIfNeeded: bytes >> 24),
        ]
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

        // 8-bit fixed point weights: a destination pixel (x, y) reads the source at (x - sx, y - sy) and,
        // weighted wx and wy, at the pixel before along each axis
        let wx = Int((fx * 256).rounded())
        let wy = Int((fy * 256).rounded())
        let w11 = (256 - wx) * (256 - wy)
        let w01 = wx * (256 - wy)
        let w10 = (256 - wx) * wy
        let w00 = wx * wy

        var result = FilterBitmap(width: width, height: height)
        source.pixels.withUnsafeBufferPointer { src in
            result.pixels.withUnsafeMutableBufferPointer { dst in
                guard let srcBase = src.baseAddress, let dstBase = dst.baseAddress else { return }
                let raw = UnsafeRawPointer(srcBase)
                let rowBytes = width * 4
                // destination columns with a source column inside the bitmap
                let xStart = Swift.max(0, sx)
                let xEnd = Swift.min(width, width + sx + (wx > 0 ? 1 : 0))
                guard xStart < xEnd else { return }

                // a whole pixel offset copies row segments
                if wx == 0 && wy == 0 {
                    var y = Swift.max(0, sy)
                    let yEnd = Swift.min(height, height + sy)
                    while y < yEnd {
                        memcpy(
                            dstBase + y * rowBytes + xStart * 4,
                            srcBase + (y - sy) * rowBytes + (xStart - sx) * 4,
                            (xEnd - xStart) * 4
                        )
                        y += 1
                    }
                    return
                }

                // while loops and raw pointers: ranges and buffer subscripts are slow in unoptimized builds
                var y = 0
                while y < height {
                    defer { y += 1 }
                    let y1 = y - sy
                    let y0 = y1 - 1
                    let hasRow1 = y1 >= 0 && y1 < height
                    let hasRow0 = wy > 0 && y0 >= 0 && y0 < height
                    guard hasRow1 || hasRow0 else { continue }
                    let row1 = y1 * rowBytes
                    let row0 = y0 * rowBytes
                    var x = xStart
                    while x < xEnd {
                        defer { x += 1 }
                        let x1 = x - sx
                        let x0 = x1 - 1
                        let hasColumn1 = x1 < width
                        let hasColumn0 = wx > 0 && x0 >= 0
                        let o = y * rowBytes + x * 4

                        // transparent or uniform neighbourhoods need no weighting
                        let p11 =
                            hasRow1 && hasColumn1
                            ? raw.loadUnaligned(fromByteOffset: row1 + x1 * 4, as: UInt32.self) : 0
                        let p01 =
                            hasRow1 && hasColumn0
                            ? raw.loadUnaligned(fromByteOffset: row1 + x0 * 4, as: UInt32.self) : 0
                        let p10 =
                            hasRow0 && hasColumn1
                            ? raw.loadUnaligned(fromByteOffset: row0 + x1 * 4, as: UInt32.self) : 0
                        let p00 =
                            hasRow0 && hasColumn0
                            ? raw.loadUnaligned(fromByteOffset: row0 + x0 * 4, as: UInt32.self) : 0
                        let isUniform = (wx == 0 || p01 == p11) && (wy == 0 || (p10 == p11 && (wx == 0 || p00 == p11)))
                        if isUniform {
                            if p11 != 0 {
                                memcpy(dstBase + o, srcBase + row1 + x1 * 4, 4)
                            }
                            continue
                        }
                        let i11 = hasRow1 && hasColumn1 ? row1 + x1 * 4 : -1
                        let i01 = hasRow1 && hasColumn0 ? row1 + x0 * 4 : -1
                        let i10 = hasRow0 && hasColumn1 ? row0 + x1 * 4 : -1
                        let i00 = hasRow0 && hasColumn0 ? row0 + x0 * 4 : -1
                        var c = 0
                        while c < 4 {
                            var sum = 0
                            if i11 >= 0 { sum += Int(srcBase[i11 + c]) * w11 }
                            if i01 >= 0 { sum += Int(srcBase[i01 + c]) * w01 }
                            if i10 >= 0 { sum += Int(srcBase[i10 + c]) * w10 }
                            if i00 >= 0 { sum += Int(srcBase[i00 + c]) * w00 }
                            dstBase[o + c] = UInt8(truncatingIfNeeded: (sum + 32768) >> 16)
                            c += 1
                        }
                    }
                }
            }
        }
        return result
    }

    // Filter Effects 1 §9.8: `a` (in) is the source and `b` (in2) the destination of the Porter-Duff operator
    // (Compositing and Blending 1 §9.1); arithmetic is clamped to 0...1 with colour never above alpha.
    static func composite(
        _ a: FilterBitmap,
        _ b: FilterBitmap,
        op: DOM.Filter.CompositeOperator,
        linear: Bool
    ) -> FilterBitmap {
        switch op {
        case .over:
            return combine(a, b, linear: linear, .over)
        case .in:
            return combine(a, b, linear: linear, .in)
        case .out:
            return combine(a, b, linear: linear, .out)
        case .atop:
            return combine(a, b, linear: linear, .atop)
        case .xor:
            return combine(a, b, linear: linear, .xor)
        case .lighter:
            return combine(a, b, linear: linear, .lighter)
        case let .arithmetic(k1: k1, k2: k2, k3: k3, k4: k4):
            return combine(a, b, linear: linear, .arithmetic(Float(k1), Float(k2), Float(k3), Float(k4)))
        }
    }

    // Filter Effects 1 §9.16: the inputs composited with `over`, the first at the bottom
    static func merge(_ inputs: [FilterBitmap], width: Int, height: Int, linear: Bool) -> FilterBitmap {
        guard var result = inputs.first else { return FilterBitmap(width: width, height: height) }
        for input in inputs.dropFirst() {
            result = combine(input, result, linear: linear, .over)
        }
        return result
    }

    // Filter Effects 1 §9.5, Compositing and Blending 1 §5.8 and §10: `a` (in) is the source Cs,
    // `b` (in2) the backdrop Cb, blended then composited with source-over.
    static func blend(_ a: FilterBitmap, _ b: FilterBitmap, mode: DOM.Filter.BlendMode, linear: Bool) -> FilterBitmap {
        combine(a, b, linear: linear, .blend(mode))
    }

    // Filter Effects 1 §9.6: on non-premultiplied values, clamped to 0...1
    static func colorMatrix(_ source: FilterBitmap, matrix: [Float], linear: Bool) -> FilterBitmap {
        guard matrix.count == 20 else { return source }
        return matrix.withUnsafeBufferPointer { m in
            map(source, linear: linear, .matrix(m.baseAddress!))
        }
    }

    // Filter Effects 1 §9.7: on non-premultiplied values, each result clamped to 0...1.
    // Each function is sampled into a table, read with linear interpolation: exact for the table and linear
    // types between their breakpoints, within 1/255 for the others.
    static func componentTransfer(
        _ source: FilterBitmap,
        _ transfer: DOM.Filter.ComponentTransfer,
        linear: Bool
    ) -> FilterBitmap {
        let functions = [transfer.r, transfer.g, transfer.b, transfer.a]
        guard functions.contains(where: { $0 != .identity }) else { return source }
        var table = [Float](repeating: 0, count: 4 * (transferSegments + 1))
        for (channel, function) in functions.enumerated() {
            for index in 0...transferSegments {
                table[channel * (transferSegments + 1) + index] = function.evaluate(
                    Float(index) / Float(transferSegments)
                )
            }
        }
        return table.withUnsafeBufferPointer { t in
            map(source, linear: linear, .transfer(t.baseAddress!))
        }
    }

    static let transferSegments = 4096

    // Filter Effects 1 §9.17: the minimum (erode) or maximum (dilate) of each premultiplied channel over a
    // rectangle 2·radius + 1 pixels wide, in the colour space of the primitive. Pixels outside the bitmap
    // are not in the rectangle, as in resvg and Skia. Separable, and each pass is van Herk/Gil-Werman:
    // three comparisons a pixel whatever the radius.
    static func morphology(
        _ source: FilterBitmap,
        _ op: DOM.Filter.MorphologyOperator,
        radiusX: Int,
        radiusY: Int,
        linear: Bool
    ) -> FilterBitmap {
        let width = source.width
        let height = source.height
        let rx = Swift.min(Swift.max(radiusX, 0), width)
        let ry = Swift.min(Swift.max(radiusY, 0), height)
        guard rx > 0 || ry > 0, width > 0, height > 0 else { return source }

        let count = width * height
        let values = UnsafeMutablePointer<Float>.allocate(capacity: count * 4)
        defer { values.deallocate() }
        let unit = unitTable
        let decoding = linearTable
        let encoding = encodingTable
        source.pixels.withUnsafeBytes { src in
            guard let raw = src.baseAddress else { return }
            var i = 0
            while i < count {
                let p = load(
                    raw.loadUnaligned(fromByteOffset: i * 4, as: UInt32.self),
                    linear: linear,
                    unit: unit,
                    decoding: decoding
                )
                values[i * 4] = p.r
                values[i * 4 + 1] = p.g
                values[i * 4 + 2] = p.b
                values[i * 4 + 3] = p.a
                i += 1
            }
        }

        let isDilate = op == .dilate
        let longest = Swift.max(width + 2 * rx, height + 2 * ry)
        let scratch = UnsafeMutablePointer<Float>.allocate(capacity: longest * 3)
        defer { scratch.deallocate() }
        if rx > 0 {
            var y = 0
            while y < height {
                var channel = 0
                while channel < 4 {
                    extremes(
                        values + y * width * 4 + channel,
                        stride: 4,
                        count: width,
                        radius: rx,
                        isMax: isDilate,
                        scratch: scratch
                    )
                    channel += 1
                }
                y += 1
            }
        }
        if ry > 0 {
            var x = 0
            while x < width * 4 {
                extremes(values + x, stride: width * 4, count: height, radius: ry, isMax: isDilate, scratch: scratch)
                x += 1
            }
        }

        var result = FilterBitmap(width: width, height: height)
        result.pixels.withUnsafeMutableBytes { dst in
            guard let out = dst.baseAddress else { return }
            var i = 0
            while i < count {
                let p = FilterPixel(r: values[i * 4], g: values[i * 4 + 1], b: values[i * 4 + 2], a: values[i * 4 + 3])
                let value = quantize(p, linear: linear, encoding: encoding)
                if value != 0 {
                    store(value, out, i * 4)
                }
                i += 1
            }
        }
        return result
    }

    // In place, each value becomes the minimum or maximum of the values up to radius away along the line.
    // The line is padded by radius at each end with a value that never wins, then split into blocks of the
    // window size: a window spans at most two blocks, so it is the suffix extreme of one and the prefix
    // extreme of the next. scratch holds 3 × (count + 2 × radius) values.
    static func extremes(
        _ line: UnsafeMutablePointer<Float>,
        stride: Int,
        count: Int,
        radius: Int,
        isMax: Bool,
        scratch: UnsafeMutablePointer<Float>
    ) {
        let window = 2 * radius + 1
        let length = count + 2 * radius
        let padded = scratch
        let prefix = scratch + length
        let suffix = scratch + 2 * length
        let identity: Float = isMax ? -1 : 2

        var i = 0
        while i < length {
            let source = i - radius
            padded[i] = source >= 0 && source < count ? line[source * stride] : identity
            i += 1
        }
        var start = 0
        while start < length {
            let end = Swift.min(start + window, length)
            prefix[start] = padded[start]
            var j = start + 1
            while j < end {
                prefix[j] = pick(prefix[j - 1], padded[j], isMax)
                j += 1
            }
            suffix[end - 1] = padded[end - 1]
            j = end - 2
            while j >= start {
                suffix[j] = pick(suffix[j + 1], padded[j], isMax)
                j -= 1
            }
            start = end
        }
        // the window of value i is padded[i ... i + 2 × radius]
        i = 0
        while i < count {
            line[i * stride] = pick(suffix[i], prefix[i + window - 1], isMax)
            i += 1
        }
    }

    @inline(__always)
    static func pick(_ x: Float, _ y: Float, _ isMax: Bool) -> Float {
        isMax ? maximum(x, y) : minimum(x, y)
    }

    // Filter Effects 1 §9.4: pixels whose centre falls outside the subregion become transparent black
    mutating func clip(to rect: LayerTree.Rect, transform: LayerTree.Transform.Matrix) {
        let corners = [
            LayerTree.Point(rect.minX, rect.minY),
            LayerTree.Point(rect.maxX, rect.minY),
            LayerTree.Point(rect.maxX, rect.maxY),
            LayerTree.Point(rect.minX, rect.maxY),
        ].map(transform.transform(point:))
        let isAxisAligned = (transform.b == 0 && transform.c == 0) || (transform.a == 0 && transform.d == 0)

        if isAxisAligned {
            let xs = corners.map(\.x)
            let ys = corners.map(\.y)
            // whole columns and rows with their centre inside
            let minX = Swift.max(0, Swift.min(width, Int((xs.min()! - 0.5).rounded(.up).clamped(-1, Float(width)))))
            let maxX = Swift.max(minX, Swift.min(width, Int((xs.max()! - 0.5).rounded(.up).clamped(-1, Float(width)))))
            let minY = Swift.max(0, Swift.min(height, Int((ys.min()! - 0.5).rounded(.up).clamped(-1, Float(height)))))
            let maxY = Swift.max(
                minY,
                Swift.min(height, Int((ys.max()! - 0.5).rounded(.up).clamped(-1, Float(height))))
            )
            guard minX > 0 || minY > 0 || maxX < width || maxY < height else { return }
            let w = width
            pixels.withUnsafeMutableBufferPointer { dst in
                guard let base = dst.baseAddress else { return }
                var y = 0
                while y < height {
                    let row = base + y * w * 4
                    if y < minY || y >= maxY {
                        row.update(repeating: 0, count: w * 4)
                    } else {
                        row.update(repeating: 0, count: minX * 4)
                        (row + maxX * 4).update(repeating: 0, count: (w - maxX) * 4)
                    }
                    y += 1
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

// A premultiplied pixel, 0...1, in linear light when linear.
// The kernels below use it rather than SIMD4<Float>, name their operation with an enum rather than a closure,
// and read through raw pointers: generic SIMD operations, per-pixel closures and array subscripts are not
// specialized or inlined in unoptimized builds, where they made filters around 20x slower. Apps build their
// packages unoptimized in Debug, and SwiftPM refuses unsafe flags (-O) in packages used by version.
struct FilterPixel {
    var r: Float
    var g: Float
    var b: Float
    var a: Float

    static let zero = FilterPixel(r: 0, g: 0, b: 0, a: 0)
}

// internal so the kernels in other files share them
extension FilterBitmap {

    enum CombineOperation {
        case over
        case `in`
        case out
        case atop
        case xor
        case lighter
        case arithmetic(Float, Float, Float, Float)
        case blend(DOM.Filter.BlendMode)
    }

    // Runs of equal pixels (transparent areas, solid fills) are computed once.
    static func combine(_ a: FilterBitmap, _ b: FilterBitmap, linear: Bool, _ op: CombineOperation) -> FilterBitmap {
        precondition(a.pixels.count == b.pixels.count)
        var result = FilterBitmap(width: a.width, height: a.height)
        let unit = unitTable
        let decoding = linearTable
        let encoding = encodingTable
        a.pixels.withUnsafeBufferPointer { pa in
            b.pixels.withUnsafeBufferPointer { pb in
                result.pixels.withUnsafeMutableBufferPointer { dst in
                    guard let baseA = pa.baseAddress, let baseB = pb.baseAddress, let base = dst.baseAddress else {
                        return
                    }
                    let out = UnsafeMutableRawPointer(base)
                    let rawA = UnsafeRawPointer(baseA)
                    let rawB = UnsafeRawPointer(baseB)
                    let count = dst.count
                    var keyA: UInt32 = 0
                    var keyB: UInt32 = 0
                    var value = quantize(apply(op, .zero, .zero), linear: linear, encoding: encoding)
                    var i = 0
                    while i < count {
                        let pixelA = rawA.loadUnaligned(fromByteOffset: i, as: UInt32.self)
                        let pixelB = rawB.loadUnaligned(fromByteOffset: i, as: UInt32.self)
                        if pixelA != keyA || pixelB != keyB {
                            keyA = pixelA
                            keyB = pixelB
                            let s = load(pixelA, linear: linear, unit: unit, decoding: decoding)
                            let d = load(pixelB, linear: linear, unit: unit, decoding: decoding)
                            value = quantize(apply(op, s, d), linear: linear, encoding: encoding)
                        }
                        if value != 0 {
                            store(value, out, i)
                        }
                        i += 4
                    }
                }
            }
        }
        return result
    }

    @inline(__always)
    static func apply(_ op: CombineOperation, _ s: FilterPixel, _ d: FilterPixel) -> FilterPixel {
        switch op {
        case .over:
            let k = 1 - s.a
            return FilterPixel(r: s.r + d.r * k, g: s.g + d.g * k, b: s.b + d.b * k, a: s.a + d.a * k)
        case .in:
            let k = d.a
            return FilterPixel(r: s.r * k, g: s.g * k, b: s.b * k, a: s.a * k)
        case .out:
            let k = 1 - d.a
            return FilterPixel(r: s.r * k, g: s.g * k, b: s.b * k, a: s.a * k)
        case .atop:
            let ks = d.a
            let kd = 1 - s.a
            return FilterPixel(
                r: s.r * ks + d.r * kd,
                g: s.g * ks + d.g * kd,
                b: s.b * ks + d.b * kd,
                a: s.a * ks + d.a * kd
            )
        case .xor:
            let ks = 1 - d.a
            let kd = 1 - s.a
            return FilterPixel(
                r: s.r * ks + d.r * kd,
                g: s.g * ks + d.g * kd,
                b: s.b * ks + d.b * kd,
                a: s.a * ks + d.a * kd
            )
        case .lighter:
            return FilterPixel(r: s.r + d.r, g: s.g + d.g, b: s.b + d.b, a: s.a + d.a)
        case let .arithmetic(k1, k2, k3, k4):
            return FilterPixel(
                r: k1 * s.r * d.r + k2 * s.r + k3 * d.r + k4,
                g: k1 * s.g * d.g + k2 * s.g + k3 * d.g + k4,
                b: k1 * s.b * d.b + k2 * s.b + k3 * d.b + k4,
                a: k1 * s.a * d.a + k2 * s.a + k3 * d.a + k4
            )
        case .blend(let mode):
            return blend(s, d, mode: mode)
        }
    }

    @inline(__always)
    static func blend(_ s: FilterPixel, _ d: FilterPixel, mode: DOM.Filter.BlendMode) -> FilterPixel {
        let alphaS = s.a
        let alphaB = d.a
        let ks = 1 - alphaB
        let kd = 1 - alphaS
        var result = FilterPixel(
            r: s.r * ks + d.r * kd,
            g: s.g * ks + d.g * kd,
            b: s.b * ks + d.b * kd,
            a: s.a * ks + d.a * kd
        )
        guard alphaS > 0, alphaB > 0 else { return result }
        let alpha = alphaS * alphaB
        let sr = s.r / alphaS, sg = s.g / alphaS, sb = s.b / alphaS
        let br = d.r / alphaB, bg = d.g / alphaB, bb = d.b / alphaB
        if let separable = mode.separable {
            result.r += blendChannel(br, sr, separable) * alpha
            result.g += blendChannel(bg, sg, separable) * alpha
            result.b += blendChannel(bb, sb, separable) * alpha
        } else {
            let mixed = blendColor(SIMD3(br, bg, bb), SIMD3(sr, sg, sb), mode: mode) * alpha
            result.r += mixed.x
            result.g += mixed.y
            result.b += mixed.z
        }
        result.a += alpha
        return result
    }

    enum MapOperation {
        // a 4x5 matrix
        case matrix(UnsafePointer<Float>)
        // a table of transferSegments + 1 samples per channel, red to alpha
        case transfer(UnsafePointer<Float>)
    }

    // Each run of equal pixels is computed once.
    static func map(_ source: FilterBitmap, linear: Bool, _ op: MapOperation) -> FilterBitmap {
        var result = FilterBitmap(width: source.width, height: source.height)
        let unit = unitTable
        let decoding = linearTable
        let encoding = encodingTable
        source.pixels.withUnsafeBufferPointer { src in
            result.pixels.withUnsafeMutableBufferPointer { dst in
                guard let base = src.baseAddress, let outBase = dst.baseAddress else { return }
                let raw = UnsafeRawPointer(base)
                let out = UnsafeMutableRawPointer(outBase)
                let count = dst.count
                var key: UInt32 = 0
                var value = quantize(apply(op, .zero), linear: linear, encoding: encoding)
                var i = 0
                while i < count {
                    let pixel = raw.loadUnaligned(fromByteOffset: i, as: UInt32.self)
                    if pixel != key {
                        key = pixel
                        value = quantize(
                            apply(op, load(pixel, linear: linear, unit: unit, decoding: decoding)),
                            linear: linear,
                            encoding: encoding
                        )
                    }
                    if value != 0 {
                        store(value, out, i)
                    }
                    i += 4
                }
            }
        }
        return result
    }

    @inline(__always)
    static func apply(_ op: MapOperation, _ p: FilterPixel) -> FilterPixel {
        switch op {
        case .matrix(let m):
            return applyMatrix(m, p)
        case .transfer(let t):
            return applyTransfer(t, p)
        }
    }

    // the transfer tables on straight colour, premultiplied again
    @inline(__always)
    static func applyTransfer(_ t: UnsafePointer<Float>, _ p: FilterPixel) -> FilterPixel {
        var c = p
        if c.a > 0 {
            c.r /= c.a
            c.g /= c.a
            c.b /= c.a
        }
        let stride = transferSegments + 1
        let r = sample(t, c.r)
        let g = sample(t + stride, c.g)
        let b = sample(t + 2 * stride, c.b)
        let a = sample(t + 3 * stride, c.a)
        return FilterPixel(r: r * a, g: g * a, b: b * a, a: a)
    }

    // a table of transferSegments + 1 samples over 0...1, interpolated linearly
    @inline(__always)
    static func sample(_ t: UnsafePointer<Float>, _ value: Float) -> Float {
        let x = clamp01(value) * Float(transferSegments)
        var index = Int(x)
        if index >= transferSegments { index = transferSegments - 1 }
        let lower = t[index]
        return lower + (x - Float(index)) * (t[index + 1] - lower)
    }

    // the 4x5 matrix on straight colour, clamped to 0...1 and premultiplied again
    @inline(__always)
    static func applyMatrix(_ m: UnsafePointer<Float>, _ p: FilterPixel) -> FilterPixel {
        var c = p
        if c.a > 0 {
            c.r /= c.a
            c.g /= c.a
            c.b /= c.a
        }
        let r = clamp01(m[0] * c.r + m[1] * c.g + m[2] * c.b + m[3] * c.a + m[4])
        let g = clamp01(m[5] * c.r + m[6] * c.g + m[7] * c.b + m[8] * c.a + m[9])
        let b = clamp01(m[10] * c.r + m[11] * c.g + m[12] * c.b + m[13] * c.a + m[14])
        let a = clamp01(m[15] * c.r + m[16] * c.g + m[17] * c.b + m[18] * c.a + m[19])
        return FilterPixel(r: r * a, g: g * a, b: b * a, a: a)
    }

    // the pixel's 4 bytes as loaded from memory, premultiplied, 0...1, in linear light when linear.
    // Channels come from the loaded word rather than pointer subscripts, generic calls when unoptimized.
    @inline(__always)
    static func load(
        _ pixel: UInt32,
        linear: Bool,
        unit: UnsafePointer<Float>,
        decoding: UnsafePointer<Float>
    ) -> FilterPixel {
        let bytes = UInt32(littleEndian: pixel)
        let r = Int(bytes & 0xFF)
        let g = Int((bytes >> 8) & 0xFF)
        let b = Int((bytes >> 16) & 0xFF)
        let a = Int(bytes >> 24)
        guard linear, a > 0 else {
            return FilterPixel(r: unit[r], g: unit[g], b: unit[b], a: unit[a])
        }
        let alpha = unit[a]
        return FilterPixel(
            r: decode(r, a, decoding) * alpha,
            g: decode(g, a, decoding) * alpha,
            b: decode(b, a, decoding) * alpha,
            a: alpha
        )
    }

    // the bytes of quantize, r first in memory
    @inline(__always)
    static func store(_ value: UInt32, _ p: UnsafeMutableRawPointer, _ i: Int) {
        p.storeBytes(of: value.littleEndian, toByteOffset: i, as: UInt32.self)
    }

    // NaN as 0, then clamped to 0...1
    @inline(__always)
    static func clamp01(_ x: Float) -> Float {
        if x != x { return 0 }
        return x < 0 ? 0 : (x > 1 ? 1 : x)
    }

    // Swift.min and Swift.max, which are generic calls when unoptimized
    @inline(__always)
    static func minimum(_ x: Float, _ y: Float) -> Float {
        y < x ? y : x
    }

    @inline(__always)
    static func maximum(_ x: Float, _ y: Float) -> Float {
        y >= x ? y : x
    }

    // clamped to 0...1 with colour never above alpha (premultiplied), then rounded:
    // r, g, b, a in the low to high bytes, 0 when transparent black
    @inline(__always)
    static func quantize(_ value: FilterPixel, linear: Bool, encoding: UnsafePointer<Float>) -> UInt32 {
        let a = clamp01(value.a)
        var r = minimum(clamp01(value.r), a)
        var g = minimum(clamp01(value.g), a)
        var b = minimum(clamp01(value.b), a)
        if linear && a > 0 {
            r = encode(r / a, encoding) * a
            g = encode(g / a, encoding) * a
            b = encode(b / a, encoding) * a
        }
        return UInt32(UInt8(r * 255 + 0.5))
            | UInt32(UInt8(g * 255 + 0.5)) << 8
            | UInt32(UInt8(b * 255 + 0.5)) << 16
            | UInt32(UInt8(a * 255 + 0.5)) << 24
    }

    // a premultiplied channel to its straight value in linear light
    @inline(__always)
    static func decode(_ c: Int, _ a: Int, _ table: UnsafePointer<Float>) -> Float {
        let straight = (c * 255 + a / 2) / a
        return table[straight < 255 ? straight : 255]
    }

    // linear light 0...1 to the sRGB encoding 0...1
    @inline(__always)
    static func encode(_ linear: Float, _ table: UnsafePointer<Float>) -> Float {
        let index = Int(linear * Float(encodingTableCount - 1) + 0.5)
        let last = encodingTableCount - 1
        return table[index < 0 ? 0 : (index > last ? last : index)]
    }

    // Tables are allocated once and never freed, so kernels can read them through a pointer.

    // a byte to 0...1
    nonisolated(unsafe) static let unitTable: UnsafePointer<Float> = makeTable(count: 256) { Float($0) / 255 }

    // sRGB transfer function (IEC 61966-2-1), 256 entries
    nonisolated(unsafe) static let linearTable: UnsafePointer<Float> = makeTable(count: 256) { value in
        let c = Float(value) / 255
        return c <= 0.04045 ? c / 12.92 : Float(pow(Double((c + 0.055) / 1.055), 2.4))
    }

    static let encodingTableCount = 8192

    nonisolated(unsafe) static let encodingTable: UnsafePointer<Float> = makeTable(count: encodingTableCount) { index in
        let l = Float(index) / 8191
        return l <= 0.0031308 ? l * 12.92 : 1.055 * Float(pow(Double(l), 1 / 2.4)) - 0.055
    }

    static func makeTable(count: Int, _ value: (Int) -> Float) -> UnsafePointer<Float> {
        let table = UnsafeMutablePointer<Float>.allocate(capacity: count)
        for index in 0..<count {
            table[index] = value(index)
        }
        return UnsafePointer(table)
    }
}

extension DOM.Filter.TransferFunction {

    // Filter Effects 1 §9.7: the function at a non-premultiplied value 0...1, clamped to 0...1.
    // A table of one value is that value everywhere.
    func evaluate(_ c: Float) -> Float {
        let value: Float
        switch self {
        case .identity:
            value = c
        case .table(let v):
            guard !v.isEmpty else { return c }
            guard v.count > 1 else { value = v[0]; break }
            let n = Float(v.count - 1)
            let k = Swift.min(Int(c * n), v.count - 2)
            value = v[k] + (c * n - Float(k)) * (v[k + 1] - v[k])
        case .discrete(let v):
            guard !v.isEmpty else { return c }
            let k = Swift.min(Int(c * Float(v.count)), v.count - 1)
            value = v[k]
        case let .linear(slope: slope, intercept: intercept):
            value = slope * c + intercept
        case let .gamma(amplitude: amplitude, exponent: exponent, offset: offset):
            value = amplitude * Float(pow(Double(c), Double(exponent))) + offset
        }
        // NaN as 0
        guard value == value else { return 0 }
        return Swift.max(0, Swift.min(1, value))
    }
}

private extension Float {
    func clamped(_ lower: Float, _ upper: Float) -> Float {
        guard !isNaN else { return lower }
        return Swift.max(lower, Swift.min(upper, self))
    }
}

// MARK: - Blend modes

private extension DOM.Filter.BlendMode {

    // modes blending each channel on its own, computed without SIMD3
    var separable: DOM.Filter.BlendMode? {
        switch self {
        case .hue, .saturation, .color, .luminosity:
            return nil
        default:
            return self
        }
    }
}

private extension FilterBitmap {

    // Compositing and Blending 1 §10: B(cb, cs) of one channel, for separable modes
    @inline(__always)
    static func blendChannel(_ b: Float, _ s: Float, _ mode: DOM.Filter.BlendMode) -> Float {
        switch mode {
        case .normal:
            return s
        case .multiply:
            return b * s
        case .screen:
            return b + s - b * s
        case .overlay:
            return hardLight(s, b)
        case .darken:
            return minimum(b, s)
        case .lighten:
            return maximum(b, s)
        case .colorDodge:
            if b == 0 { return 0 }
            if s >= 1 { return 1 }
            return minimum(1, b / (1 - s))
        case .colorBurn:
            if b >= 1 { return 1 }
            if s <= 0 { return 0 }
            return 1 - minimum(1, (1 - b) / s)
        case .hardLight:
            return hardLight(b, s)
        case .softLight:
            if s <= 0.5 {
                return b - (1 - 2 * s) * b * (1 - b)
            }
            let d = b <= 0.25 ? ((16 * b - 12) * b + 4) * b : b.squareRoot()
            return b + (2 * s - 1) * (d - b)
        case .difference:
            return abs(b - s)
        case .exclusion:
            return b + s - 2 * b * s
        case .hue, .saturation, .color, .luminosity:
            return s
        }
    }

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
