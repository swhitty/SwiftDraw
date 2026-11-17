//
//  LayerTree.GradientInterpolationTests.swift
//  SwiftDraw
//
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

@testable import SwiftDraw
import SwiftDrawDOM
import Testing

/// Stops with equal offsets, `fr`, `gradientTransform` through href, and `color-interpolation`
/// on gradients and masks, as WebKit and resvg draw them.
struct LayerTreeGradientInterpolationTests {

    typealias Stop = LayerTree.Gradient.Stop
    typealias Command = RendererCommand<LayerTreeTypes>

    static let black = LayerTree.Color(0, 0, 0)
    static let red = LayerTree.Color(255, 0, 0)
    static let gray = LayerTree.Color(128, 128, 128)
    static let white = LayerTree.Color(255, 255, 255)

    // MARK: - equal offsets

    static let equalOffsets: [(offsets: [LayerTree.Float], expected: [LayerTree.Float])] = [
        ([0, 0.5, 1], [0, 0.5, 1]),
        ([0, 0.5, 0.5, 1], [0, 0.5, 0.5, 1]),
        ([0, 0.5, 0.5, 0.5, 1], [0, 0.5, 0.5, 1]),
        ([0, 0, 0.9, 1], [0, 1e-5, 0.9, 1]),
        ([0, 0, 0, 0.9, 1], [0, 1e-5, 0.9, 1]),
        ([0, 0], [0, 1e-5]),
        ([0, 1, 1, 1], [0, 1, 1]),
        ([0.5, 0.2, 1], [0.5, 0.5, 1]),
    ]

    @Test(arguments: equalOffsets)
    func stopsWithEqualOffsets(_ test: (offsets: [LayerTree.Float], expected: [LayerTree.Float])) {
        let stops = test.offsets.map { Stop(offset: $0, color: Self.black, opacity: 1) }
        #expect(LayerTree.Builder.makeMonotonic(stops).map(\.offset) == test.expected)
    }

    @Test
    func repeatedStopsAtZeroKeepFirstAndLastColour() throws {
        let gradient = try makeLinearGradient(
            """
            <linearGradient id="g" x1="0.2" x2="0.8">
                <stop offset="0" stop-color="black"/><stop offset="0" stop-color="red"/>
                <stop offset="0" stop-color="gray"/><stop offset="1" stop-color="white"/>
            </linearGradient>
            """
        )
        #expect(gradient.gradient.stops.map(\.color) == [Self.black, Self.gray, Self.white])
        #expect(gradient.gradient.stops.map(\.offset) == [0, 1e-5, 1])
    }

    // MARK: - fr

    @Test
    func negativeFrIsZero() throws {
        let svg = try parse(
            #"<radialGradient id="g" fr="-1"><stop offset="0" /><stop offset="1" stop-color="white" /></radialGradient>"#
        )
        let element = try #require(svg.defs.radialGradients.first)
        let gradient = try #require(LayerTree.Builder(svg: svg).makeGradient(for: element))
        #expect(gradient.radius == 0)
        #expect(gradient.endRadius == 0.5)
    }

    // MARK: - gradientTransform through href

    enum TransformSource: Equatable {
        case inherited
        case identity
        case own
    }

    static let referencingTransforms: [(attribute: String, expected: TransformSource)] = [
        ("", .inherited),
        (#"gradientTransform="""#, .identity),
        (#"gradientTransform="scale(2)""#, .own),
        // resvg keeps the inherited transform for these; WebKit drops it
        (#"gradientTransform="none""#, .inherited),
        (#"gradientTransform="rotate(""#, .inherited),
    ]

    @Test(arguments: referencingTransforms)
    func gradientTransformThroughHref(_ test: (attribute: String, expected: TransformSource)) throws {
        let gradient = try makeLinearGradient(
            """
            <linearGradient id="base" gradientTransform="translate(5)"><stop offset="0" /><stop offset="1" stop-color="white" /></linearGradient>
            <linearGradient id="g" href="#base" \(test.attribute) />
            """
        )
        let source: TransformSource =
            switch gradient.transform {
            case []: .identity
            case [.translate(tx: 5, ty: 0)]: .inherited
            default: .own
            }
        #expect(source == test.expected)
    }

    // MARK: - color-interpolation on gradients

    static let interpolations: [(markup: String, expected: LayerTree.Gradient.Interpolation)] = [
        (#"<linearGradient id="g">"#, .sRGB),
        (#"<linearGradient id="g" color-interpolation="linearRGB">"#, .linearRGB),
        (#"<linearGradient id="g" color-interpolation="auto">"#, .sRGB),
        (#"<linearGradient id="g" style="color-interpolation: linearRGB">"#, .linearRGB),
    ]

    @Test(arguments: interpolations)
    func gradientColorInterpolation(_ test: (markup: String, expected: LayerTree.Gradient.Interpolation)) throws {
        let gradient = try makeLinearGradient(
            test.markup + #"<stop offset="0" /><stop offset="1" stop-color="white" /></linearGradient>"#
        )
        #expect(gradient.gradient.interpolation == test.expected)
    }

    @Test
    func colorInterpolationInheritsFromParent() throws {
        let gradient = try makeLinearGradient(
            """
            <defs color-interpolation="linearRGB">
                <linearGradient id="g"><stop offset="0" /><stop offset="1" stop-color="white" /></linearGradient>
            </defs>
            """
        )
        #expect(gradient.gradient.interpolation == .linearRGB)
    }

    @Test
    func referencingGradientDecidesColorInterpolation() throws {
        let gradient = try makeLinearGradient(
            """
            <linearGradient id="base" color-interpolation="linearRGB"><stop offset="0" /><stop offset="1" stop-color="white" /></linearGradient>
            <linearGradient id="g" href="#base" />
            """
        )
        #expect(gradient.gradient.interpolation == .sRGB)
    }

    @Test
    func sRGBGradientIsDrawnWithItsOwnStops() {
        let gradient = LayerTree.Gradient(stops: [
            Stop(offset: 0, color: Self.red, opacity: 1),
            Stop(offset: 1, color: Self.black, opacity: 0.5),
        ])
        let resolved = gradient.resolved(using: .default)
        #expect(resolved.stops.map(\.offset) == [0, 1])
        #expect(resolved.stops.map(\.color) == [Self.red, Self.black.withMultiplyingAlpha(0.5)])
    }

    static let linearGradients: [(from: LayerTree.Color, to: LayerTree.Color, opacity: LayerTree.Float)] = [
        (red, black, 1),
        (LayerTree.Color(255, 0, 0), LayerTree.Color(0, 255, 0), 1),
        (LayerTree.Color(0, 0, 255), LayerTree.Color(255, 255, 0), 0),
    ]

    /// Unpremultiplied colour interpolated in linear light, alpha interpolated linearly, drawn as
    /// sRGB stops within half a level of 8-bit colour.
    @Test(arguments: linearGradients)
    func linearRGBGradientIsResampled(
        _ test: (from: LayerTree.Color, to: LayerTree.Color, opacity: LayerTree.Float)
    ) throws {
        let gradient = LayerTree.Gradient(
            stops: [
                Stop(offset: 0, color: test.from, opacity: 1),
                Stop(offset: 1, color: test.to, opacity: test.opacity),
            ],
            interpolation: .linearRGB
        )
        let resolved = gradient.resolved(using: .default)
        #expect(resolved.stops.count > 2)

        let from = LayerTree.Gradient.components(of: test.from, opacity: 1, in: .srgb)
        let to = LayerTree.Gradient.components(of: test.to, opacity: test.opacity, in: .srgb)
        for step in 0...100 {
            let t = LayerTree.Float(step) / 100
            let expected = gradient.interpolate(from, to, t)
            let drawn = try #require(Self.sample(resolved, at: t))
            let error = Self.maxDifference(expected, drawn)
            #expect(error < 1 / 255, "t = \(t)")
        }
    }

    @Test
    func linearRGBMidpointIsEncodedHalf() throws {
        let gradient = LayerTree.Gradient(
            stops: [
                Stop(offset: 0, color: Self.red, opacity: 1),
                Stop(offset: 1, color: Self.black, opacity: 1),
            ],
            interpolation: .linearRGB
        )
        let mid = try #require(Self.sample(gradient.resolved(using: .default), at: 0.5))
        #expect(abs(mid.x - 0.7354) < 0.001)
        #expect(mid.y == 0 && mid.z == 0 && mid.w == 1)
    }

    // MARK: - color-interpolation on masks

    static let maskTypes: [(markup: String, expected: LayerTree.Layer.MaskType)] = [
        (#"<mask id="m">"#, .luminance),
        (#"<mask id="m" color-interpolation="linearRGB">"#, .linearLuminance),
        (#"<mask id="m" color-interpolation="sRGB">"#, .luminance),
        (#"<mask id="m" color-interpolation="linearRGB" mask-type="alpha">"#, .alpha),
        (#"<g color-interpolation="linearRGB"><mask id="m">"#, .linearLuminance),
    ]

    @Test(arguments: maskTypes)
    func maskColorInterpolation(_ test: (markup: String, expected: LayerTree.Layer.MaskType)) throws {
        let close = test.markup.hasPrefix("<g") ? "</mask></g>" : "</mask>"
        let svg = try parse(
            """
            \(test.markup)<rect width="10" height="10" fill="white" />\(close)
            <rect width="10" height="10" fill="green" mask="url(#m)" />
            """
        )
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let mask = try #require(Self.masks(in: layer).first)
        #expect(mask.maskType == test.expected)
    }

    static let linearLuminances: [(color: LayerTree.Color, expected: LayerTree.Float)] = [
        (white, 1),
        (black, 0),
        (red, 0.2125),
        (LayerTree.Color(0, 255, 0), 0.7154),
        (.gray(white: 0.5, a: 1), 0.2140),
    ]

    @Test(arguments: linearLuminances)
    func linearLuminance(_ test: (color: LayerTree.Color, expected: LayerTree.Float)) throws {
        guard case let .gray(white, a) = LinearLuminanceColorConverter().createColor(from: test.color) else {
            Issue.record("expected gray")
            return
        }
        #expect(abs(white - test.expected) < 0.0005)
        #expect(a == 1)
    }

    /// In a linearRGB mask an sRGB gradient is interpolated in sRGB, then each colour's luminance is
    /// taken in linear light: white at opacity 0 to black is lin(1 - t) × t (resvg, WebKit).
    @Test
    func sRGBGradientInLinearRGBMaskIsResampled() throws {
        let gradient = LayerTree.Gradient(stops: [
            Stop(offset: 0, color: Self.white, opacity: 0),
            Stop(offset: 1, color: Self.black, opacity: 1),
        ])
        let resolved = gradient.resolved(using: .linearLuminance)
        for step in 0...20 {
            let t = LayerTree.Float(step) / 20
            let drawn = try #require(Self.sample(resolved, at: t))
            #expect(abs(drawn.x * drawn.w - LayerTree.Color.linear(1 - t) * t) < 1 / 255, "t = \(t)")
        }
    }

    @Test
    func linearRGBMaskResamplesGradientCommands() throws {
        let svg = try parse(
            """
            <linearGradient id="lg"><stop offset="0" stop-color="white" stop-opacity="0" /><stop offset="1" /></linearGradient>
            <mask id="m" color-interpolation="linearRGB"><rect width="10" height="10" fill="url(#lg)" /></mask>
            <rect width="10" height="10" fill="green" mask="url(#m)" />
            """
        )
        let generator = LayerTree.CommandGenerator(
            provider: LayerTreeProvider(),
            size: .init(10, 10),
            options: .default
        )
        let commands = generator.renderCommands(for: LayerTree.Builder(svg: svg).makeLayer(), colorConverter: .default)
        let gradients = commands.flatMap(Self.flattened).compactMap { command -> LayerTree.Gradient? in
            if case let .drawLinearGradient(g, _, _) = command { return g }
            return nil
        }
        let gradient = try #require(gradients.first)
        #expect(gradient.stops.count > 2)
        #expect(gradient.stops.allSatisfy { if case .gray = $0.color { true } else { false } })
    }

    // MARK: - helpers

    func parse(_ contents: String) throws -> DOM.SVG {
        try DOM.SVG.parse(xml: #"<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">\#(contents)</svg>"#)
    }

    func makeLinearGradient(_ defs: String) throws -> LayerTree.LinearGradient {
        let svg = try parse(defs)
        let element = try #require(svg.defs.linearGradients.first { $0.id == "g" })
        return try #require(LayerTree.Builder(svg: svg).makeGradient(for: element))
    }

    static func masks(in layer: LayerTree.Layer) -> [LayerTree.Layer] {
        let own = layer.mask.map { [$0] } ?? []
        return own
            + layer.contents.flatMap { contents -> [LayerTree.Layer] in
                if case let .layer(child) = contents { return masks(in: child) }
                return []
            }
    }

    static func flattened(_ command: Command) -> [Command] {
        if case let .clipToMask(contents) = command { return [command] + contents.flatMap(flattened) }
        return [command]
    }

    /// The colour a renderer draws at `t`: unpremultiplied components interpolated between stops.
    static func sample(_ gradient: LayerTree.Gradient, at t: LayerTree.Float) -> LayerTree.Gradient.Components? {
        let stops = gradient.stops
        guard let upper = stops.firstIndex(where: { $0.offset >= t }) else { return nil }
        let b = stops[upper]
        let cb = LayerTree.Gradient.components(of: b.color, opacity: b.opacity, in: .srgb)
        guard upper > 0, b.offset > t else { return cb }
        let a = stops[upper - 1]
        let ca = LayerTree.Gradient.components(of: a.color, opacity: a.opacity, in: .srgb)
        let f = (t - a.offset) / (b.offset - a.offset)
        return ca + (cb - ca) * f
    }

    static func maxDifference(_ a: LayerTree.Gradient.Components, _ b: LayerTree.Gradient.Components) -> LayerTree.Float
    {
        let d = a - b
        return max(max(abs(d.x), abs(d.y)), max(abs(d.z), abs(d.w)))
    }
}
