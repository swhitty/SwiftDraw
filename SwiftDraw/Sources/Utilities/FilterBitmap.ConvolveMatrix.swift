//
//  FilterBitmap.ConvolveMatrix.swift
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

import SwiftDrawDOM

// MARK: - feConvolveMatrix

extension FilterBitmap {

    // kernel taps × pixels past which a convolution is not computed (transparent black), so a hostile kernel
    // cannot stall a frame: a 15 × 15 kernel over a million pixels is within it
    static let maxConvolveWork = 1 << 28

    // Filter Effects 1 §9.9: each pixel is the sum of its neighbours weighted by the kernel turned by 180°,
    // divided by the divisor, plus the bias. On premultiplied values, or on straight colour with the input's
    // alpha when preserveAlpha. The bias is scaled by the result's alpha, as in resvg. Pixels beyond the
    // bitmap are the nearest edge pixel (duplicate), the opposite side (wrap) or transparent black (none).
    // The kernel is in pixels, as in resvg, its rows running down and its columns right in user space:
    // flipped when the bitmap's rows run up (flipY) or its columns left (flipX).
    static func convolve(
        _ source: FilterBitmap,
        _ matrix: LayerTree.FilterLayer.ConvolveMatrix,
        flipX: Bool = false,
        flipY: Bool = false,
        linear: Bool
    ) -> FilterBitmap {
        let width = source.width
        let height = source.height
        var result = FilterBitmap(width: width, height: height)
        let count = width * height
        guard count > 0 else { return result }

        // the taps with a weight, as offsets from the pixel
        var taps = [(dx: Int, dy: Int, weight: Float)]()
        for row in 0..<matrix.orderY {
            for column in 0..<matrix.orderX {
                let weight = matrix.kernelMatrix[
                    (matrix.orderY - row - 1) * matrix.orderX + (matrix.orderX - column - 1)
                ]
                if weight != 0 {
                    let dx = column - matrix.targetX
                    let dy = row - matrix.targetY
                    taps.append((flipX ? -dx : dx, flipY ? -dy : dy, weight))
                }
            }
        }
        guard taps.count <= maxConvolveWork / count else { return result }

        let values = UnsafeMutablePointer<Float>.allocate(capacity: count * 4)
        defer { values.deallocate() }
        let unit = unitTable
        let decoding = linearTable
        let encoding = encodingTable
        let preserveAlpha = matrix.preserveAlpha
        source.pixels.withUnsafeBytes { src in
            guard let raw = src.baseAddress else { return }
            var i = 0
            while i < count {
                var p = load(
                    raw.loadUnaligned(fromByteOffset: i * 4, as: UInt32.self),
                    linear: linear,
                    unit: unit,
                    decoding: decoding
                )
                if preserveAlpha && p.a > 0 {
                    p.r /= p.a
                    p.g /= p.a
                    p.b /= p.a
                }
                values[i * 4] = p.r
                values[i * 4 + 1] = p.g
                values[i * 4 + 2] = p.b
                values[i * 4 + 3] = p.a
                i += 1
            }
        }

        let divisor = matrix.divisor
        let bias = matrix.bias
        let edgeMode = matrix.edgeMode
        let tapCount = taps.count
        let dxs = taps.map(\.dx)
        let dys = taps.map(\.dy)
        let weights = taps.map(\.weight)
        dxs.withUnsafeBufferPointer { dxs in
            dys.withUnsafeBufferPointer { dys in
                weights.withUnsafeBufferPointer { weights in
                    result.pixels.withUnsafeMutableBytes { dst in
                        guard let out = dst.baseAddress else { return }
                        var y = 0
                        while y < height {
                            var x = 0
                            while x < width {
                                var r: Float = 0, g: Float = 0, b: Float = 0, a: Float = 0
                                var t = 0
                                while t < tapCount {
                                    var sx = x + dxs[t]
                                    var sy = y + dys[t]
                                    if sx < 0 || sx >= width || sy < 0 || sy >= height {
                                        switch edgeMode {
                                        case .none:
                                            t += 1
                                            continue
                                        case .duplicate:
                                            sx = sx < 0 ? 0 : (sx >= width ? width - 1 : sx)
                                            sy = sy < 0 ? 0 : (sy >= height ? height - 1 : sy)
                                        case .wrap:
                                            sx %= width
                                            if sx < 0 { sx += width }
                                            sy %= height
                                            if sy < 0 { sy += height }
                                        }
                                    }
                                    let k = weights[t]
                                    let s = (sy * width + sx) * 4
                                    r += values[s] * k
                                    g += values[s + 1] * k
                                    b += values[s + 2] * k
                                    a += values[s + 3] * k
                                    t += 1
                                }
                                let i = (y * width + x) * 4
                                let pixel: FilterPixel
                                if preserveAlpha {
                                    let alpha = values[i + 3]
                                    pixel = FilterPixel(
                                        r: clamp01(r / divisor + bias * alpha) * alpha,
                                        g: clamp01(g / divisor + bias * alpha) * alpha,
                                        b: clamp01(b / divisor + bias * alpha) * alpha,
                                        a: alpha
                                    )
                                } else {
                                    let alpha = a / divisor + bias
                                    pixel = FilterPixel(
                                        r: r / divisor + bias * alpha,
                                        g: g / divisor + bias * alpha,
                                        b: b / divisor + bias * alpha,
                                        a: alpha
                                    )
                                }
                                let value = quantize(pixel, linear: linear, encoding: encoding)
                                if value != 0 {
                                    store(value, out, i)
                                }
                                x += 1
                            }
                            y += 1
                        }
                    }
                }
            }
        }
        return result
    }
}
