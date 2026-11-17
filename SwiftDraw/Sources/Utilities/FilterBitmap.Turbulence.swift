//
//  FilterBitmap.Turbulence.swift
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

// MARK: - feTurbulence

extension FilterBitmap {

    // octaves past this add less than an eighth of a byte level (each adds at most 1 / 2ⁿ of the noise),
    // so a huge numOctaves costs no more than this
    static let maxTurbulenceOctaves = 12

    // Filter Effects 1 §9.21: Perlin noise per channel, sampled at the top-left corner of each pixel mapped
    // into user space (as resvg), and written in the primitive's colour space. turbulence is the sum
    // of |noise| over the octaves; fractalNoise is (sum + 1) / 2. The stitch tile is the primitive subregion.
    static func turbulence(
        width: Int,
        height: Int,
        _ turbulence: LayerTree.FilterLayer.Turbulence,
        tile: LayerTree.Rect,
        transform: LayerTree.Transform.Matrix,
        linear: Bool
    ) -> FilterBitmap {
        var result = FilterBitmap(width: width, height: height)
        guard width > 0, height > 0, let inverse = transform.invertedMatrix() else { return result }

        let noise = PerlinNoise(seed: turbulence.seed)
        let parameters = PerlinNoise.Parameters(
            baseFrequencyX: Double(turbulence.baseFrequencyX),
            baseFrequencyY: Double(turbulence.baseFrequencyY),
            numOctaves: Swift.min(turbulence.numOctaves, maxTurbulenceOctaves),
            isFractalNoise: turbulence.isFractalNoise,
            stitchTile: turbulence.stitchTiles
                ? (Double(tile.x), Double(tile.y), Double(tile.width), Double(tile.height)) : nil
        )
        let isFractal = turbulence.isFractalNoise
        let encoding = encodingTable

        // user space moves by (a, b) a pixel along a row and (c, d) a row down
        let a = Double(inverse.a), b = Double(inverse.b), c = Double(inverse.c), d = Double(inverse.d)
        let tx = Double(inverse.tx), ty = Double(inverse.ty)

        result.pixels.withUnsafeMutableBytes { dst in
            guard let out = dst.baseAddress else { return }
            noise.withTables { tables in
                var y = 0
                while y < height {
                    var x = 0
                    while x < width {
                        var sum = PerlinNoise.turbulence(
                            tables,
                            a * Double(x) + c * Double(y) + tx,
                            b * Double(x) + d * Double(y) + ty,
                            parameters
                        )
                        if isFractal {
                            sum.r = (sum.r + 1) / 2
                            sum.g = (sum.g + 1) / 2
                            sum.b = (sum.b + 1) / 2
                            sum.a = (sum.a + 1) / 2
                        }
                        let alpha = clamp01(Float(sum.a))
                        let pixel = FilterPixel(
                            r: clamp01(Float(sum.r)) * alpha,
                            g: clamp01(Float(sum.g)) * alpha,
                            b: clamp01(Float(sum.b)) * alpha,
                            a: alpha
                        )
                        let value = quantize(pixel, linear: linear, encoding: encoding)
                        if value != 0 {
                            store(value, out, (y * width + x) * 4)
                        }
                        x += 1
                    }
                    y += 1
                }
            }
        }
        return result
    }
}

// The reference implementation of Filter Effects 1 §9.21, the four channels at once
struct PerlinNoise {

    static let bSize = 0x100
    static let bMask = 0xFF
    static let perlinN = 4096.0

    // 2 × bSize + 2 entries
    private(set) var latticeSelector: [Int]
    // [channel][index][x, y] flattened: 4 × (2 × bSize + 2) × 2
    private(set) var gradient: [Double]

    struct Stitch {
        // how much to subtract to wrap, and the lattice value from which to wrap
        var width: Int
        var height: Int
        var wrapX: Int
        var wrapY: Int

        // each octave doubles the frequency: subtracting perlinN before the multiplication and adding it after
        // is subtracting it once
        mutating func double() {
            width = PerlinNoise.int(Double(width) * 2)
            height = PerlinNoise.int(Double(height) * 2)
            wrapX = PerlinNoise.int(2 * Double(wrapX) - PerlinNoise.perlinN)
            wrapY = PerlinNoise.int(2 * Double(wrapY) - PerlinNoise.perlinN)
        }
    }

    struct Channels {
        var r: Double = 0
        var g: Double = 0
        var b: Double = 0
        var a: Double = 0
    }

    // the frequencies, adjusted for stitching, and the stitch values of the first octave
    struct Parameters {
        var frequencyX: Double
        var frequencyY: Double
        var numOctaves: Int
        var isFractalNoise: Bool
        var stitch: Stitch?

        // the spec's turbulence() up to its octave loop; stitchTile is x, y, width and height
        init(
            baseFrequencyX: Double,
            baseFrequencyY: Double,
            numOctaves: Int,
            isFractalNoise: Bool,
            stitchTile: (Double, Double, Double, Double)? = nil
        ) {
            self.frequencyX = baseFrequencyX
            self.frequencyY = baseFrequencyY
            self.numOctaves = numOctaves
            self.isFractalNoise = isFractalNoise
            guard let (x, y, width, height) = stitchTile else { return }
            // the frequencies must be adjusted so that the tile borders are continuous
            self.frequencyX = PerlinNoise.stitchedFrequency(frequencyX, tileSize: width)
            self.frequencyY = PerlinNoise.stitchedFrequency(frequencyY, tileSize: height)
            let stitchWidth = PerlinNoise.int(width * frequencyX + 0.5)
            let stitchHeight = PerlinNoise.int(height * frequencyY + 0.5)
            self.stitch = Stitch(
                width: stitchWidth,
                height: stitchHeight,
                wrapX: PerlinNoise.int(x * frequencyX + PerlinNoise.perlinN + Double(stitchWidth)),
                wrapY: PerlinNoise.int(y * frequencyY + PerlinNoise.perlinN + Double(stitchHeight))
            )
        }
    }

    // the spec's turbulence() for each channel at a point in user space: the sum over the octaves of the
    // noise (fractalNoise) or of its magnitude (turbulence), each octave at twice the frequency and half the weight
    @inline(__always)
    static func turbulence(_ tables: Tables, _ x: Double, _ y: Double, _ parameters: Parameters) -> Channels {
        var sum = Channels()
        var vx = x * parameters.frequencyX
        var vy = y * parameters.frequencyY
        var ratio = 1.0
        var stitch = parameters.stitch
        var octave = 0
        while octave < parameters.numOctaves {
            let n = noise2(tables, vx, vy, stitch)
            if parameters.isFractalNoise {
                sum.r += n.r / ratio
                sum.g += n.g / ratio
                sum.b += n.b / ratio
                sum.a += n.a / ratio
            } else {
                sum.r += abs(n.r) / ratio
                sum.g += abs(n.g) / ratio
                sum.b += abs(n.b) / ratio
                sum.a += abs(n.a) / ratio
            }
            vx *= 2
            vy *= 2
            ratio *= 2
            stitch?.double()
            octave += 1
        }
        return sum
    }

    struct Tables {
        var selector: UnsafePointer<Int>
        var gradient: UnsafePointer<Double>
    }

    init(seed: Int) {
        let size = Self.bSize
        let count = size + size + 2
        var selector = [Int](repeating: 0, count: count)
        var gradient = [Double](repeating: 0, count: 4 * count * 2)
        var seed = Self.setupSeed(seed)
        var i = 0
        for k in 0..<4 {
            i = 0
            while i < size {
                selector[i] = i
                let g = (k * count + i) * 2
                for j in 0..<2 {
                    seed = Self.random(seed)
                    gradient[g + j] = Double((seed % (size + size)) - size) / Double(size)
                }
                let s = (gradient[g] * gradient[g] + gradient[g + 1] * gradient[g + 1]).squareRoot()
                gradient[g] /= s
                gradient[g + 1] /= s
                i += 1
            }
        }
        // while(--i): i is bSize here
        i -= 1
        while i > 0 {
            let k = selector[i]
            seed = Self.random(seed)
            let j = seed % size
            selector[i] = selector[j]
            selector[j] = k
            i -= 1
        }
        for i in 0..<(size + 2) {
            selector[size + i] = selector[i]
            for k in 0..<4 {
                for j in 0..<2 {
                    gradient[(k * count + size + i) * 2 + j] = gradient[(k * count + i) * 2 + j]
                }
            }
        }
        self.latticeSelector = selector
        self.gradient = gradient
    }

    func withTables<R>(_ body: (Tables) -> R) -> R {
        latticeSelector.withUnsafeBufferPointer { selector in
            gradient.withUnsafeBufferPointer { gradient in
                body(Tables(selector: selector.baseAddress!, gradient: gradient.baseAddress!))
            }
        }
    }

    static let randM = 2147483647  // 2³¹ - 1
    static let randA = 16807  // 7⁵, a primitive root of m
    static let randQ = 127773  // m / a
    static let randR = 2836  // m % a

    static func setupSeed(_ seed: Int) -> Int {
        var seed = seed
        if seed <= 0 {
            seed = -(seed % (randM - 1)) + 1
        }
        if seed > randM - 1 {
            seed = randM - 1
        }
        return seed
    }

    static func random(_ seed: Int) -> Int {
        var result = randA * (seed % randQ) - randR * (seed / randQ)
        if result <= 0 {
            result += randM
        }
        return result
    }

    // the C cast of a double to a 32-bit int, without its undefined behaviour: NaN is 0 and values beyond the
    // range saturate (also where Int is 32 bits)
    @inline(__always)
    static func int(_ value: Double) -> Int {
        guard value == value else { return 0 }
        if value >= 2_147_483_647 { return 2_147_483_647 }
        if value <= -2_147_483_648 { return -2_147_483_648 }
        return Int(value)
    }

    // the frequency nearest to it with a whole number of cycles in the tile, by ratio
    static func stitchedFrequency(_ frequency: Double, tileSize: Double) -> Double {
        guard frequency != 0 else { return frequency }
        let lo = (tileSize * frequency).rounded(.down) / tileSize
        let hi = (tileSize * frequency).rounded(.up) / tileSize
        return frequency / lo < hi / frequency ? lo : hi
    }

    @inline(__always)
    static func sCurve(_ t: Double) -> Double {
        t * t * (3 - 2 * t)
    }

    @inline(__always)
    static func lerp(_ t: Double, _ a: Double, _ b: Double) -> Double {
        a + t * (b - a)
    }

    static func noise2(_ tables: Tables, _ x: Double, _ y: Double, _ stitch: Stitch?) -> Channels {
        var t = x + perlinN
        var bx0 = int(t)
        var bx1 = bx0 &+ 1
        let rx0 = t - Double(bx0)
        let rx1 = rx0 - 1
        t = y + perlinN
        var by0 = int(t)
        var by1 = by0 &+ 1
        let ry0 = t - Double(by0)
        let ry1 = ry0 - 1
        guard rx0.isFinite, ry0.isFinite else { return Channels() }

        // if stitching, adjust the lattice points
        if let stitch {
            if bx0 >= stitch.wrapX { bx0 &-= stitch.width }
            if bx1 >= stitch.wrapX { bx1 &-= stitch.width }
            if by0 >= stitch.wrapY { by0 &-= stitch.height }
            if by1 >= stitch.wrapY { by1 &-= stitch.height }
        }
        bx0 &= bMask
        bx1 &= bMask
        by0 &= bMask
        by1 &= bMask

        let selector = tables.selector
        let i = selector[bx0]
        let j = selector[bx1]
        let b00 = selector[i + by0]
        let b10 = selector[j + by0]
        let b01 = selector[i + by1]
        let b11 = selector[j + by1]
        let sx = sCurve(rx0)
        let sy = sCurve(ry0)

        let count = 2 * (bSize + bSize + 2)
        func channel(_ k: Int) -> Double {
            let q = tables.gradient + k * count
            var u = rx0 * q[b00 * 2] + ry0 * q[b00 * 2 + 1]
            var v = rx1 * q[b10 * 2] + ry0 * q[b10 * 2 + 1]
            let a = lerp(sx, u, v)
            u = rx0 * q[b01 * 2] + ry1 * q[b01 * 2 + 1]
            v = rx1 * q[b11 * 2] + ry1 * q[b11 * 2 + 1]
            let b = lerp(sx, u, v)
            return lerp(sy, a, b)
        }
        return Channels(r: channel(0), g: channel(1), b: channel(2), a: channel(3))
    }
}
