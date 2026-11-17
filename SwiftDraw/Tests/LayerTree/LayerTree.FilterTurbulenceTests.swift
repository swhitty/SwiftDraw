//
//  LayerTree.FilterTurbulenceTests.swift
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

// Filter Effects 1 §9.21 feTurbulence, with the cases of resvg's filters/feTurbulence tests
struct LayerTreeFilterTurbulenceTests {

    typealias Effect = LayerTree.FilterLayer.Effect

    static func noise(_ x: Float, _ y: Float, octaves: Int = 1, seed: Int = 0,
                      fractal: Bool = false, stitch: Bool = false) -> Effect {
        .turbulence(LayerTree.FilterLayer.Turbulence(baseFrequencyX: x, baseFrequencyY: y, numOctaves: octaves,
                                                     seed: seed, isFractalNoise: fractal, stitchTiles: stitch))
    }

    @Test(arguments: [
        // no-attributes: no frequency, one octave
        ("", noise(0, 0)),
        (#"baseFrequency="0.05""#, noise(0.05, 0.05)),
        (#"baseFrequency="0.05 0.01""#, noise(0.05, 0.01)),
        (#"baseFrequency="0.05,0""#, noise(0.05, 0)),
        // an unreadable list is the initial 0
        (#"baseFrequency="0.05 0.01 0.1""#, noise(0, 0)),
        (#"baseFrequency="0.05px""#, noise(0, 0)),
        // baseFrequency=-0.05, baseFrequency=0.05--0.01: an error, transparent black
        (#"baseFrequency="-0.05""#, .flood(.none)),
        (#"baseFrequency="0.05 -0.01""#, .flood(.none)),
        (#"baseFrequency="0.05" numOctaves="5""#, noise(0.05, 0.05, octaves: 5)),
        // numOctaves=0, numOctaves=-1: no octaves
        (#"baseFrequency="0.05" numOctaves="0""#, noise(0.05, 0.05, octaves: 0)),
        (#"baseFrequency="0.05" numOctaves="-1""#, noise(0.05, 0.05, octaves: 0)),
        // seed=1.5, seed=-20: truncated towards zero
        (#"baseFrequency="0.05" seed="1.5""#, noise(0.05, 0.05, seed: 1)),
        (#"baseFrequency="0.05" seed="-1.5""#, noise(0.05, 0.05, seed: -1)),
        (#"baseFrequency="0.05" seed="-20""#, noise(0.05, 0.05, seed: -20)),
        (#"baseFrequency="0.05" seed="1e30""#, noise(0.05, 0.05, seed: 2_147_483_647)),
        (#"baseFrequency="0.1" type="fractalNoise""#, noise(0.1, 0.1, fractal: true)),
        // type=invalid: the initial turbulence
        (#"baseFrequency="0.05" type="invalid""#, noise(0.05, 0.05)),
        (#"baseFrequency="0.03" stitchTiles="stitch""#, noise(0.03, 0.03, stitch: true)),
        (#"baseFrequency="0.03" stitchTiles="noStitch""#, noise(0.03, 0.03))
    ] as [(String, LayerTree.FilterLayer.Effect)])
    func parsesAttributes(attributes: String, effect: LayerTree.FilterLayer.Effect) throws {
        let layer = try makeFilterLayer(#"<feTurbulence \#(attributes)/>"#)
        #expect(layer.effects == [effect])
    }

    // primitiveUnits=objectBoundingBox: baseFrequency stays in user space, as in resvg, Chrome and Safari
    @Test
    func objectBoundingBoxKeepsFrequency() throws {
        let layer = try makeFilterLayer(#"<feTurbulence baseFrequency="0.05"/>"#, primitiveUnits: "objectBoundingBox")
        #expect(layer.effects == [Self.noise(0.05, 0.05)])
    }

    // noise has no input: its subregion defaults to the filter region
    @Test
    func hasNoInput() throws {
        let layer = try makeFilterLayer(#"<feTurbulence baseFrequency="0.05" in="SourceAlpha"/>"#)
        let primitive = try #require(layer.primitives.first)
        #expect(primitive.inputs.isEmpty)
        #expect(primitive.subregion == layer.region)
    }
}

private extension LayerTreeFilterTurbulenceTests {

    func makeFilterLayer(_ primitive: String, primitiveUnits: String = "userSpaceOnUse") throws -> LayerTree.FilterLayer {
        let svg = try DOM.SVG.parse(xml: #"""
        <svg width="200" height="200" xmlns="http://www.w3.org/2000/svg">
            <filter id="f" primitiveUnits="\#(primitiveUnits)">\#(primitive)</filter>
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

// The noise against values printed by the C reference code of Filter Effects 1 §9.21, compiled as written
// (frequencies 0.05 and 0.03, three octaves)
struct PerlinNoiseTests {

    @Test(arguments: [
        (0, 190, 240, 0.99599039648326382, -0.98325018400043218),
        (20, 0, 16, 0.27472112789737807, 0.99999231073843808),
        (-20, 0, 190, -0.36086262172643979, -0.68848590804304932)
    ] as [(Int, Int, Int, Double, Double)])
    func setsUpTheLattice(seed: Int, selector0: Int, selector255: Int, red0x: Double, alpha255y: Double) {
        let noise = PerlinNoise(seed: seed)
        let count = PerlinNoise.bSize * 2 + 2
        #expect(noise.latticeSelector[0] == selector0)
        #expect(noise.latticeSelector[255] == selector255)
        #expect(noise.gradient[0] == red0x)
        #expect(noise.gradient[(3 * count + 255) * 2 + 1] == alpha255y)
    }

    @Test(arguments: [
        (0, 10.5, 20.25, false, [0.085832433445746634, 0.50799993590842862, 0.28968427516331408, 0.48900597807147084]),
        (0, 10.5, 20.25, true, [0.085832433445746634, -0.34961802023433725, -0.13213047809077422, -0.33023226027287667]),
        (0, 123, 7.75, false, [0.31770736488724388, 0.10003680463021528, 0.37361705564326742, 0.1316675308600383]),
        (0, -3.5, 60, true, [-0.21235383972040625, -0.089029286658188683, 0.21510163292820483, 0.06048290354542072]),
        (20, 10.5, 20.25, false, [0.3934635936745996, 0.27941188848024157, 0.1888503846748833, 0.32759625541161208]),
        (20, 123, 7.75, true, [-0.024927373156541754, 0.16694018421090201, -0.04336665331122793, -0.30759041775847495]),
        (-20, -3.5, 60, false, [0.50317442338571039, 0.16371239941134369, 0.10985019508893862, 0.26174195458121174]),
        (-20, 123, 7.75, true, [0.58615643017649099, -0.18777120091055996, 0.29426011261372054, 0.048015016370716042])
    ] as [(Int, Double, Double, Bool, [Double])])
    func matchesTheReference(seed: Int, x: Double, y: Double, fractal: Bool, expected: [Double]) {
        let parameters = PerlinNoise.Parameters(baseFrequencyX: 0.05, baseFrequencyY: 0.03, numOctaves: 3, isFractalNoise: fractal)
        let sum = PerlinNoise(seed: seed).withTables { PerlinNoise.turbulence($0, x, y, parameters) }
        let values = [sum.r, sum.g, sum.b, sum.a]
        for (value, reference) in zip(values, expected) {
            #expect(abs(value - reference) < 1e-12)
        }
    }

    // stitching a 120 × 120 tile at 40, 40: frequency 0.03, two octaves, turbulence at 10.5, 20.25
    @Test(arguments: [
        (0, [0.07411320993212285, 0.30741545521022817, 0.25651736546409071, 0.37404150265706115]),
        (20, [0.56364852347843508, 0.42166834668067893, 0.28608434358870677, 0.3905317539847718]),
        (-20, [0.10286987277376639, 0.18230939252684847, 0.3199589772594672, 0.31103724050121939])
    ] as [(Int, [Double])])
    func stitchesLikeTheReference(seed: Int, expected: [Double]) {
        let parameters = PerlinNoise.Parameters(baseFrequencyX: 0.03, baseFrequencyY: 0.03, numOctaves: 2,
                                                isFractalNoise: false, stitchTile: (40, 40, 120, 120))
        let sum = PerlinNoise(seed: seed).withTables { PerlinNoise.turbulence($0, 10.5, 20.25, parameters) }
        let values = [sum.r, sum.g, sum.b, sum.a]
        for (value, reference) in zip(values, expected) {
            #expect(abs(value - reference) < 1e-12)
        }
    }

    // the tile's frequency has a whole number of cycles: 3.6 cycles become 4
    @Test
    func stitchingRoundsTheFrequency() {
        #expect(abs(PerlinNoise.stitchedFrequency(0.03, tileSize: 120) - 4.0 / 120) < 1e-15)
        #expect(PerlinNoise.stitchedFrequency(0, tileSize: 120) == 0)
    }

    @Test
    func randomMatchesParkMiller() {
        #expect(PerlinNoise.setupSeed(0) == 1)
        #expect(PerlinNoise.setupSeed(-20) == 21)
        #expect(PerlinNoise.setupSeed(Int(Int32.max)) == 2_147_483_646)
        #expect(PerlinNoise.random(1) == 16807)
        #expect(PerlinNoise.random(16807) == 282_475_249)
    }
}

// the bitmap: each pixel is the noise at its top-left corner in user space, in the primitive's colour space
struct FilterBitmapTurbulenceTests {

    static func noise(_ x: Float, octaves: Int = 3, seed: Int = 0, fractal: Bool = false) -> LayerTree.FilterLayer.Turbulence {
        LayerTree.FilterLayer.Turbulence(baseFrequencyX: x, baseFrequencyY: x, numOctaves: octaves, seed: seed,
                                         isFractalNoise: fractal, stitchTiles: false)
    }

    @Test(arguments: [false, true] as [Bool])
    func samplesUserSpace(fractal: Bool) {
        // user space is scaled by 1.5 and moved 10 pixels right
        let transform = LayerTree.Transform.Matrix(a: 1.5, b: 0, c: 0, d: 1.5, tx: 10, ty: 0)
        let turbulence = Self.noise(0.05, seed: 20, fractal: fractal)
        let bitmap = FilterBitmap.turbulence(width: 16, height: 8, turbulence, tile: .zero, transform: transform, linear: false)

        let parameters = PerlinNoise.Parameters(baseFrequencyX: Double(Float(0.05)), baseFrequencyY: Double(Float(0.05)),
                                                numOctaves: 3, isFractalNoise: fractal)
        for (x, y) in [(0, 0), (13, 5), (7, 2)] {
            var sum = PerlinNoise(seed: 20).withTables {
                PerlinNoise.turbulence($0, (Double(x) - 10) / 1.5, Double(y) / 1.5, parameters)
            }
            if fractal {
                sum = PerlinNoise.Channels(r: (sum.r + 1) / 2, g: (sum.g + 1) / 2, b: (sum.b + 1) / 2, a: (sum.a + 1) / 2)
            }
            let a = Float(min(max(sum.a, 0), 1))
            func channel(_ c: Double) -> Float { Float(min(max(c, 0), 1)) * a }
            let expected = FilterBitmap.encode(FilterPixel(r: channel(sum.r), g: channel(sum.g), b: channel(sum.b), a: a), linear: false)
            #expect(bitmap.pixel(x: x, y: y) == expected, "\(x), \(y)")
        }
    }

    // linearRGB noise is encoded to sRGB when stored: lighter than the same noise in sRGB
    @Test
    func linearRGBIsEncoded() {
        let identity = LayerTree.Transform.Matrix(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)
        let turbulence = Self.noise(0.05, fractal: true)
        let srgb = FilterBitmap.turbulence(width: 8, height: 8, turbulence, tile: .zero, transform: identity, linear: false)
        let linear = FilterBitmap.turbulence(width: 8, height: 8, turbulence, tile: .zero, transform: identity, linear: true)
        let pixel = srgb.pixel(x: 3, y: 3)
        let encoded = linear.pixel(x: 3, y: 3)
        #expect(pixel[3] == encoded[3])
        #expect(encoded[0] > pixel[0])
    }

    // numOctaves=0 (and -1): turbulence of no octaves is transparent, fractalNoise is mid grey at half alpha
    @Test
    func noOctaves() {
        let identity = LayerTree.Transform.Matrix(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)
        let turbulence = FilterBitmap.turbulence(width: 4, height: 4, Self.noise(0.05, octaves: 0), tile: .zero, transform: identity, linear: false)
        #expect(turbulence == FilterBitmap(width: 4, height: 4))
        let fractal = FilterBitmap.turbulence(width: 4, height: 4, Self.noise(0.05, octaves: 0, fractal: true), tile: .zero, transform: identity, linear: false)
        #expect(fractal.pixel(x: 1, y: 2) == [64, 64, 64, 128])
    }

    // a hostile numOctaves costs no more than maxTurbulenceOctaves, which are all that show
    @Test
    func octavesAreBounded() {
        let identity = LayerTree.Transform.Matrix(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)
        let huge = FilterBitmap.turbulence(width: 32, height: 32, Self.noise(0.05, octaves: 1_000_000), tile: .zero, transform: identity, linear: false)
        let capped = FilterBitmap.turbulence(width: 32, height: 32, Self.noise(0.05, octaves: FilterBitmap.maxTurbulenceOctaves), tile: .zero, transform: identity, linear: false)
        #expect(huge == capped)
    }

    // huge frequencies and stitch tiles neither trap nor hang
    @Test(arguments: [
        (Float(1e30), LayerTree.Rect(x: 0, y: 0, width: 32, height: 32)),
        (Float.greatestFiniteMagnitude, LayerTree.Rect(x: -1e30, y: 1e30, width: 1e-30, height: 1e30)),
        (0.05, LayerTree.Rect(x: 0, y: 0, width: 1e-30, height: 1e-30))
    ] as [(Float, LayerTree.Rect)])
    func hostileValuesDoNotTrap(frequency: Float, tile: LayerTree.Rect) {
        let identity = LayerTree.Transform.Matrix(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)
        var turbulence = Self.noise(frequency, octaves: 1_000_000)
        turbulence.stitchTiles = true
        let bitmap = FilterBitmap.turbulence(width: 16, height: 16, turbulence, tile: tile, transform: identity, linear: true)
        #expect(bitmap.width == 16)
    }
}
