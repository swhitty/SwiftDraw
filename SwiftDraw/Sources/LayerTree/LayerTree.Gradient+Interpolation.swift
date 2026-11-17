//
//  LayerTree.Gradient+Interpolation.swift
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

import Foundation

extension LayerTree.Gradient {

    typealias Components = SIMD4<LayerTree.Float>

    /// The gradient ready to draw: each stop's colour converted, with its opacity folded into the alpha.
    /// Renderers interpolate the stops in sRGB, so a gradient interpolated in linear light, or one whose
    /// colours `converter` does not convert linearly (a `linearRGB` mask), is resampled with extra stops.
    func resolved(using converter: any ColorConverter) -> LayerTree.Gradient {
        guard interpolation == .linearRGB || !converter.preservesInterpolation else {
            return convertColor(using: converter)
        }
        return resampled(using: converter)
    }

    func convertColor(using converter: any ColorConverter) -> LayerTree.Gradient {
        let stops: [LayerTree.Gradient.Stop] = stops.map { stop in
            var stop = stop
            stop.color = converter.createColor(from: stop.color).withMultiplyingAlpha(stop.opacity)
            return stop
        }
        return LayerTree.Gradient(stops: stops)
    }

    /// Most times a span between two stops is halved while resampling.
    static var maxResampleDepth: Int { 8 }

    /// Stops drawn in sRGB that differ from this gradient by at most `tolerance` in any component.
    /// Colours are interpolated unpremultiplied, as WebKit and resvg do with `color-interpolation`,
    /// in the gradient's own space (Display P3 when any stop is), and converted with `converter`.
    func resampled(
        using converter: any ColorConverter = .default,
        tolerance: LayerTree.Float = 0.5 / 255
    ) -> LayerTree.Gradient {
        let space = colorSpace
        let colors = stops.map { Self.components(of: $0.color, opacity: $0.opacity, in: space) }

        typealias Sample = (color: LayerTree.Color, components: Components)
        func converted(_ c: Components) -> Sample {
            let color = converter.createColor(from: .rgba(r: c.x, g: c.y, b: c.z, a: c.w, space: space))
            return (color, Self.components(of: color, opacity: 1, in: space))
        }

        var result = [Stop]()
        for (index, color) in colors.enumerated() {
            if index > 0, stops[index].offset > stops[index - 1].offset {
                let from = (offset: stops[index - 1].offset, color: colors[index - 1])
                let to = (offset: stops[index].offset, color: color)

                func subdivide(
                    _ t0: LayerTree.Float,
                    _ s0: Sample,
                    _ t1: LayerTree.Float,
                    _ s1: Sample,
                    depth: Int
                ) {
                    let t = (t0 + t1) / 2
                    let s = converted(interpolate(from.color, to.color, t))
                    let d = s.components - (s0.components + s1.components) * 0.5
                    let error = max(max(abs(d.x), abs(d.y)), max(abs(d.z), abs(d.w)))
                    guard depth < Self.maxResampleDepth, error > tolerance else { return }
                    subdivide(t0, s0, t, s, depth: depth + 1)
                    result.append(Stop(offset: from.offset + (to.offset - from.offset) * t, color: s.color, opacity: 1))
                    subdivide(t, s, t1, s1, depth: depth + 1)
                }
                subdivide(0, converted(from.color), 1, converted(to.color), depth: 0)
            }
            result.append(Stop(offset: stops[index].offset, color: converted(color).color, opacity: 1))
        }
        return LayerTree.Gradient(stops: result)
    }

    func interpolate(_ a: Components, _ b: Components, _ t: LayerTree.Float) -> Components {
        switch interpolation {
        case .sRGB:
            return a + (b - a) * t
        case .linearRGB:
            func mix(_ x: LayerTree.Float, _ y: LayerTree.Float) -> LayerTree.Float {
                let lx = LayerTree.Color.linear(x)
                return LayerTree.Color.encode(lx + (LayerTree.Color.linear(y) - lx) * t)
            }
            return Components(mix(a.x, b.x), mix(a.y, b.y), mix(a.z, b.z), a.w + (b.w - a.w) * t)
        }
    }

    /// Unpremultiplied components in `space`, the alpha multiplied by `opacity`.
    static func components(
        of color: LayerTree.Color,
        opacity: LayerTree.Float,
        in space: LayerTree.ColorSpace
    ) -> Components {
        switch color {
        case .none:
            return .zero
        case let .gray(white, a):
            return Components(white, white, white, a * opacity)
        case let .rgba(r, g, b, a, source):
            let (r, g, b) = LayerTree.Color.convert(r: r, g: g, b: b, from: source, to: space)
            return Components(r, g, b, a * opacity)
        }
    }
}
