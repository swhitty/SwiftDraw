//
//  DOM.Filter.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 16/8/22.
//  Copyright 2022 Simon Whitty
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

package extension DOM {

    final class Filter: Element {
        package var id: String

        // one per filter primitive, in document order (SD12)
        package var primitives: [Primitive]

        package var effects: [Effect] {
            primitives.map(\.effect)
        }

        package var x: DOM.Coordinate?
        package var y: DOM.Coordinate?
        package var width: DOM.Coordinate?
        package var height: DOM.Coordinate?
        package var filterUnits: Units?
        package var primitiveUnits: Units?

        package init(id: String) {
            self.id = id
            self.primitives = []
        }
        
        package enum Effect: Hashable {
            // stdDeviationY is nil when stdDeviation has a single value
            case gaussianBlur(stdDeviation: DOM.Float, stdDeviationY: DOM.Float? = nil)

            // a filter primitive SwiftDraw cannot render yet
            case unsupported(name: String)

            // Filter Effects 1 §9.18 feOffset, in primitiveUnits
            case offset(dx: DOM.Float, dy: DOM.Float)

            // Filter Effects 1 §9.13 feFlood: currentColor is resolved while parsing
            case flood(color: DOM.Color, opacity: DOM.Float)

            // Filter Effects 1 §9.8 feComposite: `in` composited onto `in2`
            case composite(CompositeOperator)

            // Filter Effects 1 §9.16 feMerge: the inputs are the <feMergeNode> children
            case merge

            // Filter Effects 1 §9.5 feBlend: `in` blended onto `in2`
            case blend(BlendMode)

            // Filter Effects 1 §9.6 feColorMatrix
            case colorMatrix(ColorMatrix)
        }

        // A filter primitive with its wiring (Filter Effects 1 §9.2 in / in2 / result) and subregion (§9.4)
        package struct Primitive: Hashable {
            package var effect: Effect

            // `in` then `in2`, or one per <feMergeNode>; nil where the attribute is missing
            package var inputs: [Input?]
            package var result: String?

            // primitive subregion in primitiveUnits: user units, or fractions of the bounding box;
            // nil takes the default subregion
            package var x: DOM.Coordinate?
            package var y: DOM.Coordinate?
            package var width: DOM.Coordinate?
            package var height: DOM.Coordinate?

            // the computed color-interpolation-filters, inherited from the <filter> and its ancestors
            package var colorInterpolation: ColorInterpolation

            package init(effect: Effect,
                         inputs: [Input?] = [],
                         result: String? = nil,
                         colorInterpolation: ColorInterpolation = .linearRGB) {
                self.effect = effect
                self.inputs = inputs
                self.result = result
                self.colorInterpolation = colorInterpolation
            }
        }

        package enum Input: Hashable {
            case sourceGraphic
            case sourceAlpha
            case backgroundImage
            case backgroundAlpha
            case fillPaint
            case strokePaint
            case result(String)
        }

        package enum CompositeOperator: Hashable {
            case over
            case `in`
            case out
            case atop
            case xor
            // Filter Effects 1: the sum of both inputs
            case lighter
            // result = k1·i1·i2 + k2·i1 + k3·i2 + k4 on premultiplied values
            case arithmetic(k1: DOM.Float, k2: DOM.Float, k3: DOM.Float, k4: DOM.Float)
        }

        // Compositing and Blending 1 §10 blend modes
        package enum BlendMode: String, Hashable {
            case normal
            case multiply
            case screen
            case overlay
            case darken
            case lighten
            case colorDodge = "color-dodge"
            case colorBurn = "color-burn"
            case hardLight = "hard-light"
            case softLight = "soft-light"
            case difference
            case exclusion
            case hue
            case saturation
            case color
            case luminosity
        }

        package enum ColorMatrix: Hashable {
            // 20 values, row-major 4x5; any other count is a pass through
            case matrix([DOM.Float])
            case saturate(DOM.Float)
            // degrees
            case hueRotate(DOM.Float)
            case luminanceToAlpha
        }

        // Filter Effects 1 §10 color-interpolation-filters
        package enum ColorInterpolation: String, Hashable {
            case auto
            case sRGB
            case linearRGB
        }

        package enum Units: String {
            case userSpaceOnUse
            case objectBoundingBox
        }
    }
}
