//
//  LayerTree.Builder.FilterFunction.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 16/11/26.
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

extension LayerTree.Builder {

    /// Filter Effects 1 §12.2: a filter function as the filter primitive it is equivalent to, from
    /// SourceGraphic, in sRGB. A function has no filter region of its own; like resvg, blur and drop-shadow
    /// take a larger region (bbox -50% / 200%) than the default (-10% / 120%) so the blur is rarely cut.
    static func makeFilter(
        for function: DOM.FilterFunction,
        with state: State
    ) -> (primitives: [LayerTree.FilterPrimitive], region: LayerTree.FilterRegion) {
        let effect: DOM.Filter.Effect
        var region = LayerTree.FilterRegion()
        let fontSize = state.fontSize

        switch function {
        case .blur(let length):
            effect = .gaussianBlur(stdDeviation: length.resolve(fontSize: fontSize))
            region = .function
        case let .dropShadow(color: color, dx: dx, dy: dy, stdDeviation: stdDeviation):
            // currentColor is resolved here, as flood-color is while parsing
            var color = color ?? state.color
            if color == .currentColor {
                color = .keyword(.black)
            }
            effect = .dropShadow(
                DOM.Filter.DropShadow(
                    dx: dx.resolve(fontSize: fontSize),
                    dy: dy.resolve(fontSize: fontSize),
                    stdDeviation: stdDeviation.resolve(fontSize: fontSize),
                    color: color
                )
            )
            region = .function
        case .hueRotate(let degrees):
            effect = .colorMatrix(.hueRotate(degrees))
        case .saturate(let amount):
            effect = .colorMatrix(.saturate(amount))
        case .grayscale(let amount):
            // the saturate matrix of the complement
            effect = .colorMatrix(.saturate(1 - min(amount, 1)))
        case .sepia(let amount):
            let a = 1 - min(amount, 1)
            effect = .colorMatrix(
                .matrix([
                    0.393 + 0.607 * a, 0.769 - 0.769 * a, 0.189 - 0.189 * a, 0, 0,
                    0.349 - 0.349 * a, 0.686 + 0.314 * a, 0.168 - 0.168 * a, 0, 0,
                    0.272 - 0.272 * a, 0.534 - 0.534 * a, 0.131 + 0.869 * a, 0, 0,
                    0, 0, 0, 1, 0,
                ])
            )
        case .invert(let amount):
            let a = min(amount, 1)
            effect = .componentTransfer(colors(.table([a, 1 - a])))
        case .opacity(let amount):
            effect = .componentTransfer(DOM.Filter.ComponentTransfer(a: .table([0, min(amount, 1)])))
        case .brightness(let amount):
            effect = .componentTransfer(colors(.linear(slope: amount, intercept: 0)))
        case .contrast(let amount):
            effect = .componentTransfer(colors(.linear(slope: amount, intercept: 0.5 - 0.5 * amount)))
        }

        let primitive = LayerTree.FilterPrimitive(effect: effect, inputs: [nil], colorInterpolation: .sRGB)
        return ([primitive], region)
    }

    /// the same function on red, green and blue; alpha unchanged
    private static func colors(_ function: DOM.Filter.TransferFunction) -> DOM.Filter.ComponentTransfer {
        DOM.Filter.ComponentTransfer(r: function, g: function, b: function)
    }
}

extension LayerTree.FilterRegion {
    // the region of the blur and drop-shadow functions
    static let function = LayerTree.FilterRegion(x: -0.5, y: -0.5, width: 2, height: 2)
}
