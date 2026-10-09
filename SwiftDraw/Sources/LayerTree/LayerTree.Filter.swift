//
//  LayerTree.Filter.swift
//  SwiftDraw
//
//  Created by Misoservices on 8/10/26.
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

extension LayerTree {

    // The <filter> element's region and units, resolved against the layer when commands are generated.
    // nil values take the spec defaults: -10% / -10% / 120% / 120%.
    struct FilterRegion: Hashable {
        var x: Float?
        var y: Float?
        var width: Float?
        var height: Float?
        var units: FilterUnits = .objectBoundingBox
        var primitiveUnits: FilterUnits = .userSpaceOnUse
    }

    enum FilterUnits: Hashable {
        case userSpaceOnUse
        case objectBoundingBox
    }

    // A filter resolved into the user space of the layer it applies to.
    // Renderers draw the layer contents offscreen (SourceGraphic), evaluate the primitives in order, then
    // composite the result of the last one clipped to region.
    struct FilterLayer: Hashable {
        var region: Rect
        // the primary filter primitive tree (Filter Effects 1 §9.3); inputs only refer to earlier primitives
        var primitives: [Primitive]

        var effects: [Effect] {
            primitives.map(\.effect)
        }

        // A filter primitive resolved into user space (SD12)
        struct Primitive: Hashable {
            var effect: Effect
            var inputs: [Input]
            // Filter Effects 1 §9.4: a hard clip on the result, within the filter region;
            // an empty subregion disables the primitive (transparent black)
            var subregion: Rect
            var colorInterpolation: ColorInterpolation
        }

        enum Effect: Hashable {
            // user units, both values explicit; zero does not blur that direction
            case gaussianBlur(stdDeviation: Float, stdDeviationY: Float)
            // user units
            case offset(dx: Float, dy: Float)
            // flood-color with flood-opacity applied
            case flood(Color)
            // inputs[0] composited onto inputs[1]
            case composite(DOM.Filter.CompositeOperator)
            // inputs composited bottom to top
            case merge
            // inputs[0] blended onto inputs[1]
            case blend(DOM.Filter.BlendMode)
            // 4x5 row-major, applied to non-premultiplied values
            case colorMatrix([Float])
        }

        enum Input: Hashable {
            case sourceGraphic
            case sourceAlpha
            // BackgroundImage, BackgroundAlpha, FillPaint and StrokePaint
            case transparent
            // the result of an earlier primitive
            case primitive(Int)
        }

        // Filter Effects 1 §10: `auto` is drawn as sRGB, like Chrome
        enum ColorInterpolation: Hashable {
            case sRGB
            case linearRGB
        }
    }
}

extension LayerTree.FilterLayer {

    // A chain of effects from SourceGraphic, each primitive over the whole region in sRGB.
    init(region: LayerTree.Rect, effects: [Effect]) {
        self.region = region
        self.primitives = effects.enumerated().map { index, effect in
            Primitive(effect: effect,
                      inputs: [index == 0 ? .sourceGraphic : .primitive(index - 1)],
                      subregion: region,
                      colorInterpolation: .sRGB)
        }
    }

    // SD2's filters: blurs chained from SourceGraphic, each over the whole region.
    // Renderers may blur these in place instead of evaluating the primitive tree.
    var isBlurChain: Bool {
        guard !primitives.isEmpty else { return false }
        for (index, primitive) in primitives.enumerated() {
            guard case .gaussianBlur = primitive.effect,
                  primitive.inputs == [index == 0 ? .sourceGraphic : .primitive(index - 1)],
                  primitive.subregion == region else { return false }
        }
        return true
    }

    // Filter Effects 1 §9.2: a missing `in`, a forward reference and a reference to a result that does not
    // exist all take the previous result, or SourceGraphic for the first primitive. A repeated `result`
    // name refers to the closest preceding primitive. The background and paint inputs are not available
    // and are transparent black (SVG 1.1 §15.6 without enable-background: new).
    static func makeInputs(for primitives: [LayerTree.FilterPrimitive]) -> [[Input]] {
        var named = [String: Int]()
        var inputs = [[Input]]()
        for (index, primitive) in primitives.enumerated() {
            let previous: Input = index == 0 ? .sourceGraphic : .primitive(index - 1)
            inputs.append(primitive.inputs.map { input in
                switch input {
                case .sourceGraphic:
                    return .sourceGraphic
                case .sourceAlpha:
                    return .sourceAlpha
                case .backgroundImage, .backgroundAlpha, .fillPaint, .strokePaint:
                    return .transparent
                case .result(let name):
                    return named[name].map { .primitive($0) } ?? previous
                case nil:
                    return previous
                }
            })
            if let result = primitive.result {
                named[result] = index
            }
        }
        return inputs
    }

    // Filter Effects 1 §9.3: only the tree rooted at the last primitive contributes; ascending indices
    static func primaryTree(of inputs: [[Input]]) -> [Int] {
        guard !inputs.isEmpty else { return [] }
        var isReached = [Bool](repeating: false, count: inputs.count)
        isReached[inputs.count - 1] = true
        for index in inputs.indices.reversed() where isReached[index] {
            for case .primitive(let source) in inputs[index] {
                isReached[source] = true
            }
        }
        return inputs.indices.filter { isReached[$0] }
    }
}

extension LayerTree.Layer {

    // a primitive SwiftDraw cannot render in the primary tree; primitives outside it are never drawn
    var hasUnsupportedFilters: Bool {
        let inputs = LayerTree.FilterLayer.makeInputs(for: filters)
        return LayerTree.FilterLayer.primaryTree(of: inputs).contains { !filters[$0].effect.isSupported }
    }

    var containsText: Bool {
        contents.contains {
            switch $0 {
            case .text:
                return true
            case .layer(let layer):
                return layer.containsText
            case .shape, .image:
                return false
            }
        }
    }
}

extension LayerTree.Filter {

    var isSupported: Bool {
        switch self {
        case .gaussianBlur(_, _):
            return true
        case .unsupported:
            return false
        case .offset, .flood, .composite, .merge, .blend, .colorMatrix:
            return true
        }
    }
}

extension DOM.Filter.ColorMatrix {

    static let identity: [LayerTree.Float] = [1, 0, 0, 0, 0,
                                             0, 1, 0, 0, 0,
                                             0, 0, 1, 0, 0,
                                             0, 0, 0, 1, 0]

    // Filter Effects 1 §9.6: the 4x5 matrix of each type, row-major; a wrong number of values is a pass through.
    // The luminance coefficients are those of Filter Effects 1, their complements exact so that
    // saturate(1) and hueRotate(0) are the identity.
    var values: [LayerTree.Float] {
        switch self {
        case .matrix(let values):
            return values.count == 20 ? values.map { LayerTree.Float($0) } : Self.identity
        case .saturate(let value):
            let s = LayerTree.Float(value)
            return [0.2126 + 0.7874 * s, 0.7152 - 0.7152 * s, 0.0722 - 0.0722 * s, 0, 0,
                    0.2126 - 0.2126 * s, 0.7152 + 0.2848 * s, 0.0722 - 0.0722 * s, 0, 0,
                    0.2126 - 0.2126 * s, 0.7152 - 0.7152 * s, 0.0722 + 0.9278 * s, 0, 0,
                    0, 0, 0, 1, 0]
        case .hueRotate(let degrees):
            let radians = Double(degrees) * .pi / 180
            let c = LayerTree.Float(cos(radians))
            let s = LayerTree.Float(sin(radians))
            return [0.2126 + c * 0.7874 - s * 0.2126, 0.7152 - c * 0.7152 - s * 0.7152, 0.0722 - c * 0.0722 + s * 0.9278, 0, 0,
                    0.2126 - c * 0.2126 + s * 0.143, 0.7152 + c * 0.2848 + s * 0.140, 0.0722 - c * 0.0722 - s * 0.283, 0, 0,
                    0.2126 - c * 0.2126 - s * 0.7874, 0.7152 - c * 0.7152 + s * 0.7152, 0.0722 + c * 0.9278 + s * 0.0722, 0, 0,
                    0, 0, 0, 1, 0]
        case .luminanceToAlpha:
            return [0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0,
                    0.2126, 0.7152, 0.0722, 0, 0]
        }
    }
}
