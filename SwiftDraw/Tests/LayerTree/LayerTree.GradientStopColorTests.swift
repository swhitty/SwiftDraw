//
//  LayerTree.GradientStopColorTests.swift
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

/// SVG 1.1 §13.2.4: `stop-color="currentColor"` is the `color` in effect on the <stop>, inherited
/// through the gradient and its ancestors in the document, not from the element being painted;
/// `stop-color="inherit"` takes the gradient's `stop-color`.
struct LayerTreeGradientStopColorTests {

    typealias Command = RendererCommand<LayerTreeTypes>

    static let yellow = LayerTree.Color(255, 255, 0)
    static let green = LayerTree.Color(0, 128, 0)
    static let black = LayerTree.Color(0, 0, 0)

    enum Kind: String, CaseIterable, CustomTestStringConvertible {
        case linearGradient
        case radialGradient

        var testDescription: String { rawValue }
    }

    @Test(arguments: Kind.allCases)
    func currentColorFromGradient(_ kind: Kind) throws {
        let stops = try makeStops(
            kind,
            """
            <\(kind) id="g" color="green">
                <stop offset="0" stop-color="yellow" /><stop offset="1" stop-color="currentColor" />
            </\(kind)>
            """
        )
        #expect(stops == [Self.yellow, Self.green])
    }

    @Test(arguments: Kind.allCases)
    func currentColorFromAncestorOfGradient(_ kind: Kind) throws {
        let stops = try makeStops(
            kind,
            """
            <g color="green"><defs>
                <\(kind) id="g"><stop offset="0" stop-color="yellow" /><stop offset="1" stop-color="currentColor" /></\(kind)>
            </defs></g>
            """
        )
        #expect(stops == [Self.yellow, Self.green])
    }

    @Test(arguments: Kind.allCases)
    func currentColorFromStop(_ kind: Kind) throws {
        let stops = try makeStops(
            kind,
            """
            <\(kind) id="g" color="red">
                <stop offset="0" stop-color="yellow" /><stop offset="1" style="color: green" stop-color="currentColor" />
            </\(kind)>
            """
        )
        #expect(stops == [Self.yellow, Self.green])
    }

    @Test(arguments: Kind.allCases)
    func currentColorIgnoresPaintedElement(_ kind: Kind) throws {
        let stops = try makeStops(
            kind,
            """
            <\(kind) id="g"><stop offset="0" stop-color="yellow" /><stop offset="1" stop-color="currentColor" /></\(kind)>
            """,
            painted: #"color="red""#
        )
        #expect(stops == [Self.yellow, Self.black])
    }

    @Test(arguments: Kind.allCases)
    func currentColorFromStyleSheet(_ kind: Kind) throws {
        let stops = try makeStops(
            kind,
            """
            <style>.c { color: green }</style>
            <g class="c">
                <\(kind) id="g"><stop offset="0" stop-color="yellow" /><stop offset="1" stop-color="currentColor" /></\(kind)>
            </g>
            """
        )
        #expect(stops == [Self.yellow, Self.green])
    }

    @Test(arguments: Kind.allCases)
    func inheritTakesGradientStopColor(_ kind: Kind) throws {
        let stops = try makeStops(
            kind,
            """
            <\(kind) id="g" stop-color="green">
                <stop offset="0" stop-color="yellow" /><stop offset="1" stop-color="inherit" />
            </\(kind)>
            """
        )
        #expect(stops == [Self.yellow, Self.green])
    }

    @Test(arguments: Kind.allCases)
    func hrefStopsUseColorOfTheirOwnGradient(_ kind: Kind) throws {
        let stops = try makeStops(
            kind,
            """
            <g color="green">
                <\(kind) id="base"><stop offset="0" stop-color="yellow" /><stop offset="1" stop-color="currentColor" /></\(kind)>
            </g>
            <\(kind) id="g" href="#base" color="red" />
            """
        )
        #expect(stops == [Self.yellow, Self.green])
    }

    @Test
    func colorCurrentColorInheritsColor() throws {
        let svg = try DOM.SVG.parse(
            xml: """
                <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20">
                    <g color="green"><rect width="10" height="10" fill="currentColor" color="currentColor" /></g>
                </svg>
                """
        )
        let fills = makeCommands(svg).compactMap {
            if case .setFill(let c) = $0 { return c }; return nil
        }
        #expect(fills == [Self.green])
    }

    func makeStops(_ kind: Kind, _ defs: String, painted: String = "") throws -> [LayerTree.Color] {
        let svg = try DOM.SVG.parse(
            xml: """
                <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20">
                    \(defs)
                    <rect width="10" height="10" fill="url(#g)" \(painted) />
                </svg>
                """
        )
        let gradient = try #require(
            makeCommands(svg).compactMap { command -> LayerTree.Gradient? in
                switch command {
                case let .drawLinearGradient(g, _, _), let .drawRadialGradient(g, _, _, _, _): return g
                default: return nil
                }
            }.first
        )
        return gradient.stops.map(\.color)
    }

    func makeCommands(_ svg: DOM.SVG) -> [Command] {
        let generator = LayerTree.CommandGenerator(
            provider: LayerTreeProvider(),
            size: .init(20, 20),
            options: .default
        )
        return generator.renderCommands(for: LayerTree.Builder(svg: svg).makeLayer(), colorConverter: .default)
    }
}
