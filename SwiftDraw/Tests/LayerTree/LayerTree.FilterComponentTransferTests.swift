//
//  LayerTree.FilterComponentTransferTests.swift
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

// Filter Effects 1 §9.7 feComponentTransfer, with the cases of resvg's filters/feComponentTransfer tests:
// the expected pixels are those of resvg's reference renders, a #aabbcc rect filtered
struct LayerTreeFilterComponentTransferTests {

    typealias Transfer = DOM.Filter.ComponentTransfer

    @Test(arguments: [
        (#"<feFuncB type="table" tableValues="1 1 0 0"/>"#, Transfer(b: .table([1, 1, 0, 0]))),
        (#"<feFuncG type="discrete" tableValues="1 1 1 0"/>"#, Transfer(g: .discrete([1, 1, 1, 0]))),
        (#"<feFuncR type="linear" slope=".5" intercept=".25"/>"#, Transfer(r: .linear(slope: 0.5, intercept: 0.25))),
        (#"<feFuncA type="gamma" amplitude="2" exponent="3" offset="0.5"/>"#, Transfer(a: .gamma(amplitude: 2, exponent: 3, offset: 0.5))),
        (#"<feFuncR type="identity"/><feFuncG type="identity"/>"#, Transfer()),
        // missing attributes take their initial values
        (#"<feFuncB type="linear"/>"#, Transfer(b: .linear(slope: 1, intercept: 0))),
        (#"<feFuncB type="gamma"/>"#, Transfer(b: .gamma(amplitude: 1, exponent: 1, offset: 0))),
        (#"<feFuncB type="table"/>"#, Transfer(b: .table([]))),
        // type=table-and-tableValues=1px, type=table-with-an-empty-tableValues: no table
        (#"<feFuncB type="table" tableValues="1px"/>"#, Transfer(b: .table([]))),
        (#"<feFuncB type="table" tableValues=""/>"#, Transfer(b: .table([]))),
        // type=linear-with-invalid-values, type=gamma-with-invalid-values, type=gamma-with-an-invalid-offset:
        // numbers with units are unreadable and take the initial value
        (#"<feFuncB type="linear" slope="0.5px" intercept="0.5%"/>"#, Transfer(b: .linear(slope: 1, intercept: 0))),
        (#"<feFuncB type="gamma" amplitude="2px" exponent="1px" offset="0.5px"/>"#, Transfer(b: .gamma(amplitude: 1, exponent: 1, offset: 0))),
        (#"<feFuncB type="gamma" amplitude="2" exponent="1" offset="50%"/>"#, Transfer(b: .gamma(amplitude: 2, exponent: 1, offset: 0))),
        // invalid-type
        (#"<feFuncB type="random" tableValues="1 1 0 0"/>"#, Transfer()),
        (#"<feFuncB tableValues="1 1 0 0"/>"#, Transfer()),
        // type=table-on-blue-twice: the last feFuncB wins
        (#"<feFuncB type="table" tableValues="0 0 1 1"/><feFuncB type="table" tableValues="1 1 0 0"/>"#, Transfer(b: .table([1, 1, 0, 0]))),
        // no-children
        ("", Transfer())
    ] as [(String, DOM.Filter.ComponentTransfer)])
    func parsesFunctions(functions: String, transfer: DOM.Filter.ComponentTransfer) throws {
        let layer = try makeFilterLayer(functions: functions)
        #expect(layer.effects == [.componentTransfer(transfer)])
        #expect(layer.primitives.first?.colorInterpolation == .linearRGB)
    }

    @Test(arguments: [
        // type=table-on-blue, in linearRGB
        (#"<feFuncB type="table" tableValues="1 1 0 0"/>"#, nil, [170, 187, 120, 255]),
        // type=table-on-blue-with-sRGB-interpolation
        (#"<feFuncB type="table" tableValues="1 1 0 0"/>"#, "sRGB", [170, 187, 0, 255]),
        // type=discrete-on-blue
        (#"<feFuncB type="discrete" tableValues="1 1 0 0"/>"#, nil, [170, 187, 0, 255]),
        // type=linear-on-blue
        (#"<feFuncB type="linear" slope=".5" intercept=".25"/>"#, nil, [170, 187, 196, 255]),
        // type=gamma-on-blue, type=gamma-with-an-invalid-offset
        (#"<feFuncB type="gamma" amplitude="2" exponent="1" offset="0.5"/>"#, nil, [170, 187, 255, 255]),
        (#"<feFuncB type="gamma" amplitude="2" exponent="1" offset="50%"/>"#, nil, [170, 187, 255, 255]),
        // type=linear-with-large-values
        (#"<feFuncB type="linear" slope="999999" intercept="999999"/>"#, nil, [170, 187, 255, 255]),
        // type=table-and-tableValues=1: one value is that value everywhere
        (#"<feFuncB type="table" tableValues="1"/>"#, nil, [170, 187, 255, 255]),
        // type=table-and-tableValues=1-0-1
        (#"<feFuncB type="table" tableValues="1 0 1"/>"#, nil, [170, 187, 125, 255]),
        // type=table-and-tableValues=100--100, type=table-with-large-values: clamped
        (#"<feFuncB type="table" tableValues="100 -100"/>"#, nil, [170, 187, 0, 255]),
        (#"<feFuncB type="table" tableValues="9999999 -9999999"/>"#, nil, [170, 187, 0, 255]),
        // type=table-on-blue-twice
        (#"<feFuncB type="table" tableValues="0 0 1 1"/><feFuncB type="table" tableValues="1 1 0 0"/>"#, nil, [170, 187, 120, 255]),
        // type=table-with-an-empty-tableValues, invalid-type: the identity
        (#"<feFuncB type="table" tableValues=""/>"#, nil, [170, 187, 204, 255]),
        (#"<feFuncB type="random" tableValues="1 1 0 0"/>"#, nil, [170, 187, 204, 255]),
        // type=table-on-alpha (its opacity="0.5" applies after the filter)
        (#"<feFuncA type="table" tableValues="1 0 0 1"/>"#, nil, [170, 187, 204, 255]),
        // mixed-types (its opacity="0.8" applies after the filter)
        (#"""
        <feFuncR type="table" tableValues="1 1 0 0"/>
        <feFuncG type="discrete" tableValues="1 1 1 0"/>
        <feFuncB type="linear" slope=".5" intercept=".25"/>
        <feFuncA type="gamma" amplitude="2" exponent="1" offset="0.5"/>
        """#, nil, [229, 255, 196, 255])
    ] as [(String, String?, [UInt8])])
    func evaluatesLikeResvg(functions: String, colorInterpolation: String?, expected: [UInt8]) throws {
        let pixel = try evaluate(functions: functions, colorInterpolation: colorInterpolation, source: [0xAA, 0xBB, 0xCC, 255])
        for (value, reference) in zip(pixel, expected) {
            #expect(abs(Int(value) - Int(reference)) <= 1, "\(pixel) != \(expected)")
        }
    }

    // transparent pixels are transparent black: functions of alpha can make them opaque
    @Test
    func transparentPixelsAreTransformed() throws {
        let pixel = try evaluate(functions: #"""
            <feFuncR type="linear" intercept="1"/><feFuncA type="table" tableValues="1 0"/>
            """#, colorInterpolation: "sRGB", source: [0, 0, 0, 0])
        #expect(pixel == [255, 0, 0, 255])
    }

    // the result is premultiplied again
    @Test
    func translucentPixelsKeepTheirAlpha() throws {
        let pixel = try evaluate(functions: #"<feFuncR type="linear" intercept="1"/>"#,
                                 colorInterpolation: "sRGB", source: [0, 0, 0, 128])
        #expect(pixel == [128, 0, 0, 128])
    }

    @Test(arguments: [
        (DOM.Filter.TransferFunction.identity, Float(0.3), Float(0.3)),
        (.table([]), 0.3, 0.3),
        (.table([0.2]), 0.9, 0.2),
        (.table([0, 1, 0]), 0.25, 0.5),
        (.table([0, 1, 0]), 1, 0),
        (.discrete([]), 0.3, 0.3),
        (.discrete([0.1, 0.9]), 0.49, 0.1),
        (.discrete([0.1, 0.9]), 0.5, 0.9),
        (.discrete([0.1, 0.9]), 1, 0.9),
        (.linear(slope: 2, intercept: -0.5), 0.5, 0.5),
        (.linear(slope: 2, intercept: -0.5), 1, 1),
        (.gamma(amplitude: 1, exponent: 2, offset: 0), 0.5, 0.25),
        // pow(0, -1) is infinite: clamped
        (.gamma(amplitude: 1, exponent: -1, offset: 0), 0, 1),
        (.gamma(amplitude: 0, exponent: -1, offset: 0), 0, 0)
    ] as [(DOM.Filter.TransferFunction, Float, Float)])
    func transferFunction(function: DOM.Filter.TransferFunction, value: Float, expected: Float) {
        #expect(abs(function.evaluate(value) - expected) < 0.0001)
    }
}

private extension LayerTreeFilterComponentTransferTests {

    func makeFilterLayer(functions: String, colorInterpolation: String? = nil) throws -> LayerTree.FilterLayer {
        let attribute = colorInterpolation.map { #" color-interpolation-filters="\#($0)""# } ?? ""
        let svg = try DOM.SVG.parse(xml: #"""
        <svg width="200" height="200" xmlns="http://www.w3.org/2000/svg">
            <filter id="f"\#(attribute)><feComponentTransfer>\#(functions)</feComponentTransfer></filter>
            <rect x="20" y="20" width="160" height="160" fill="#aabbcc" filter="url(#f)" />
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

    // the filtered pixel at the centre of the rect
    func evaluate(functions: String, colorInterpolation: String?, source: [UInt8]) throws -> [UInt8] {
        let filter = try makeFilterLayer(functions: functions, colorInterpolation: colorInterpolation)
        let environment = LayerTree.FilterLayer.Environment(
            transform: LayerTree.Transform.Matrix(a: 1, b: 0, c: 0, d: 1, tx: -99.5, ty: -99.5),
            blur: { _, _, _ in }
        )
        let result = filter.evaluate(source: FilterBitmap(width: 1, height: 1, pixels: source), environment: environment)
        return result.pixel(x: 0, y: 0)
    }
}
