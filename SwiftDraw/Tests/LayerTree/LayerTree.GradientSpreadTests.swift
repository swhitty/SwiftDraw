//
//  LayerTree.GradientSpreadTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 15/11/26.
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
import Foundation
import Testing

/// Gradient stops and spreadMethod (SVG 1.1 §13.2.2–§13.2.4).
/// Ported from SD6 in PR #142 by Michel Donais.
struct LayerTreeGradientSpreadTests {

    typealias Command = RendererCommand<LayerTreeTypes>
    typealias Generator = LayerTree.CommandGenerator<LayerTreeProvider>

    static let stops = #"<stop offset="0" stop-color="red"/><stop offset="1" stop-color="blue"/>"#
    static let red = LayerTree.Color.rgba(r: 1, g: 0, b: 0, a: 1, space: .srgb)
    static let blue = LayerTree.Color.rgba(r: 0, g: 0, b: 1, a: 1, space: .srgb)
    var stops: String { Self.stops }
    var red: LayerTree.Color { Self.red }
    var blue: LayerTree.Color { Self.blue }

    // MARK: - stops

    @Test
    func singleStopPaintsSolidColour() throws {
        #expect(try color(#"<defs><linearGradient id="g"><stop offset="0.3" stop-color="red" stop-opacity="0.5"/></linearGradient></defs>"#) ==
                .rgba(r: 1, g: 0, b: 0, a: 0.5, space: .srgb))

        let cmds = try commands("""
        <defs><radialGradient id="g"><stop stop-color="blue"/></radialGradient></defs>
        <rect width="10" height="10" fill="url(#g)" fill-opacity="0.5"/>
        <rect width="10" height="10" fill="none" stroke="url(#g)"/>
        """)
        #expect(cmds.contains { if case .setFill(color: .rgba(r: 0, g: 0, b: 1, a: 0.5, space: .srgb)) = $0 { return true }; return false })
        #expect(cmds.contains { if case .setStroke(color: .rgba(r: 0, g: 0, b: 1, a: 1, space: .srgb)) = $0 { return true }; return false })
    }

    @Test
    func singleStopInheritedThroughHref() throws {
        #expect(try color("""
        <defs>
          <linearGradient id="a"><stop stop-color="red"/></linearGradient>
          <radialGradient id="g" xlink:href="#a"/>
        </defs>
        """) == red)
    }

    @Test
    func singleStopResolvesBeforeFallback() throws {
        let cmds = try commands("""
        <defs><linearGradient id="g"><stop stop-color="blue"/></linearGradient></defs>
        <rect width="10" height="10" fill="url(#g) red"/>
        """)
        #expect(cmds.contains { if case .setFill(color: .rgba(r: 0, g: 0, b: 1, a: 1, space: .srgb)) = $0 { return true }; return false })
    }

    @Test
    func zeroStopsPaintsNothing() throws {
        #expect(try paint(#"<defs><linearGradient id="g"/></defs>"#) == nil)
        let cmds = try commands(#"<defs><radialGradient id="g"/></defs><rect width="10" height="10" fill="url(#g)"/>"#)
        #expect(!cmds.contains { if case .fill = $0 { return true }; return false })
    }

    @Test
    func stopOffsetsAreClampedAndMonotonic() throws {
        let g = try linear("""
        <defs><linearGradient id="g">
          <stop offset="-1" stop-color="red"/><stop offset="0.6" stop-color="red"/>
          <stop offset="0.4" stop-color="blue"/><stop offset="2" stop-color="blue"/>
        </linearGradient></defs>
        """)
        #expect(g?.gradient.stops.map(\.offset) == [0, 0.6, 0.6, 1])
    }

    @Test
    func monotonicStopsClampUnparsedOffsets() {
        let stops = [-0.5, .nan, 0.8, 0.3, 4].map {
            LayerTree.Gradient.Stop(offset: $0, color: .none, opacity: 1)
        }
        // a second stop at 0 is moved just after it, so the first colour pads before the gradient
        #expect(LayerTree.Builder.makeMonotonic(stops).map(\.offset) == [0, 1e-5, 0.8, 0.8, 1])
    }

    // MARK: - spreadMethod parsing

    @Test(arguments: [
        ("repeat", LayerTree.Gradient.Spread.repeat),
        ("reflect", .reflect),
        ("pad", .pad),
        ("junk", .pad)
    ])
    func spreadMethodIsParsed(value: String, spread: LayerTree.Gradient.Spread) throws {
        #expect(try linear(#"<defs><linearGradient id="g" spreadMethod="\#(value)">\#(stops)</linearGradient></defs>"#)?.spread == spread)
    }

    @Test
    func spreadMethodDefaultsToPad() throws {
        #expect(try linear(#"<defs><linearGradient id="g">\#(stops)</linearGradient></defs>"#)?.spread == .pad)
    }

    @Test
    func spreadMethodIsInheritedThroughHref() throws {
        let g = try linear("""
        <defs>
          <radialGradient id="a" spreadMethod="reflect">\(stops)</radialGradient>
          <linearGradient id="b" xlink:href="#a"/>
          <linearGradient id="g" xlink:href="#b"/>
        </defs>
        """)
        #expect(g?.spread == .reflect)
    }

    // MARK: - linear spread

    @Test
    func padDrawsSinglePeriod() throws {
        let d = try drawnLinear("""
        <defs><linearGradient id="g" gradientUnits="userSpaceOnUse" x1="0" x2="25">\(stops)</linearGradient></defs>
        <rect width="100" height="10" fill="url(#g)"/>
        """)
        #expect(d?.start == LayerTree.Point(0, 0))
        #expect(d?.end == LayerTree.Point(25, 0))
        #expect(d?.gradient.stops.count == 2)
    }

    @Test
    func repeatCoversShape() throws {
        let d = try drawnLinear("""
        <defs><linearGradient id="g" gradientUnits="userSpaceOnUse" x1="0" x2="25" spreadMethod="repeat">\(stops)</linearGradient></defs>
        <rect width="100" height="10" fill="url(#g)"/>
        """)
        #expect(d?.start == LayerTree.Point(0, 0))
        #expect(d?.end == LayerTree.Point(100, 0))
        #expect(d?.gradient.stops.map(\.offset) == [0, 0.25, 0.25, 0.5, 0.5, 0.75, 0.75, 1])
        #expect(d?.gradient.stops.map(\.color) == [red, blue, red, blue, red, blue, red, blue])
    }

    @Test
    func reflectMirrorsOddPeriods() throws {
        let d = try drawnLinear("""
        <defs><linearGradient id="g" gradientUnits="userSpaceOnUse" x1="0" x2="50" spreadMethod="reflect">\(stops)</linearGradient></defs>
        <rect width="100" height="10" fill="url(#g)"/>
        """)
        #expect(d?.end == LayerTree.Point(100, 0))
        #expect(d?.gradient.stops.map(\.offset) == [0, 0.5, 0.5, 1])
        #expect(d?.gradient.stops.map(\.color) == [red, blue, blue, red])
    }

    @Test
    func reflectExtendsBeforeStart() throws {
        let d = try drawnLinear("""
        <defs><linearGradient id="g" gradientUnits="userSpaceOnUse" x1="50" x2="75" spreadMethod="reflect">\(stops)</linearGradient></defs>
        <rect width="100" height="10" fill="url(#g)"/>
        """)
        // periods -2...1: odd period -1 is mirrored
        #expect(d?.start == LayerTree.Point(0, 0))
        #expect(d?.end == LayerTree.Point(100, 0))
        #expect(d?.gradient.stops.map(\.color) == [red, blue, blue, red, red, blue, blue, red])
    }

    @Test
    func repeatCompletesPartialStops() throws {
        let d = try drawnLinear("""
        <defs><linearGradient id="g" gradientUnits="userSpaceOnUse" x1="0" x2="50" spreadMethod="repeat">
          <stop offset="0.25" stop-color="red"/><stop offset="0.75" stop-color="blue"/>
        </linearGradient></defs>
        <rect width="100" height="10" fill="url(#g)"/>
        """)
        #expect(d?.gradient.stops.map(\.offset) == [0, 0.125, 0.375, 0.5, 0.5, 0.625, 0.875, 1])
    }

    @Test
    func repeatHonoursGradientTransform() throws {
        // scaled ×2: one period spans 50 units, so two periods cover the rect
        let d = try drawnLinear("""
        <defs><linearGradient id="g" gradientUnits="userSpaceOnUse" x1="0" x2="25" spreadMethod="repeat" gradientTransform="scale(2)">\(stops)</linearGradient></defs>
        <rect width="100" height="10" fill="url(#g)"/>
        """)
        #expect(d?.end == LayerTree.Point(50, 0))
        #expect(d?.gradient.stops.count == 4)
    }

    @Test
    func objectBoundingBoxRepeatWithTransform() throws {
        let d = try drawnLinear("""
        <defs><linearGradient id="g" x1="0" x2="0.25" spreadMethod="repeat" gradientTransform="translate(0.1 0)">\(stops)</linearGradient></defs>
        <rect width="100" height="10" fill="url(#g)"/>
        """)
        // drawn in the bounding box: one period is 0.25, shifted by 0.1, so x -0.1...0.9 is periods -1...3
        #expect(d?.start == LayerTree.Point(-0.25, 0))
        #expect(d?.end == LayerTree.Point(1, 0))
        #expect(d?.gradient.stops.count == 10)
    }

    @Test
    func objectBoundingBoxReflectWithTransform() throws {
        let d = try drawnLinear("""
        <defs><linearGradient id="g" x1="0" x2="0.5" spreadMethod="reflect" gradientTransform="scale(0.5)">\(stops)</linearGradient></defs>
        <rect width="100" height="10" fill="url(#g)"/>
        """)
        // scaled by 0.5: the box 0...1 maps to 0...2 in gradient space, four periods of 0.5
        #expect(d?.end == LayerTree.Point(2, 0))
        #expect(d?.gradient.stops.map(\.color) == [red, blue, blue, red, red, blue, blue, red])
    }

    @Test
    func repeatStrokeCoversStrokeWidth() throws {
        let d = try drawnLinear("""
        <defs><linearGradient id="g" gradientUnits="userSpaceOnUse" x1="0" x2="0" y1="0" y2="10" spreadMethod="repeat">\(stops)</linearGradient></defs>
        <line x1="50" y1="10" x2="50" y2="30" stroke="url(#g)" stroke-width="4" stroke-linecap="round"/>
        """)
        // the line spans y 10...30, the stroke reaches 2 beyond (miter limit 4 → 8): periods 0...3
        #expect(d?.start == LayerTree.Point(0, 0))
        #expect(d?.end == LayerTree.Point(0, 40))
    }

    @Test(arguments: [("round", LayerTree.Point(0, 40)), ("square", LayerTree.Point(0, 50))])
    func squareCapCoverage(cap: String, end: LayerTree.Point) throws {
        // a square cap reaches 2·√2 = 2.83 beyond y = 37.5, past the fourth period
        let d = try drawnLinear("""
        <defs><linearGradient id="g" gradientUnits="userSpaceOnUse" x1="0" x2="0" y1="0" y2="10" spreadMethod="repeat">\(stops)</linearGradient></defs>
        <line x1="50" y1="12" x2="50" y2="37.5" stroke="url(#g)" stroke-width="4" stroke-linejoin="round" stroke-linecap="\(cap)"/>
        """)
        #expect(d?.end == end)
    }

    @Test
    func repeatFarFromItsVectorStillExpands() throws {
        // 10 periods per unit, shape at x = 20 000: only the periods under the shape are drawn,
        // not every period from 0 (which would exceed the cap and fall back to the average colour)
        let d = try drawnLinear("""
        <defs><linearGradient id="g" gradientUnits="userSpaceOnUse" x1="0" x2="0.1" spreadMethod="repeat">\(stops)</linearGradient></defs>
        <rect x="20000" width="100" height="10" fill="url(#g)"/>
        """)
        #expect((d?.gradient.stops.count ?? 0) > 1000)
    }

    @Test
    func spreadPeriodsCoverOnlyTheArea() {
        let area = LayerTree.Rect(x: 10_000.3, y: 0, width: 0.4, height: 1)
        let periods = Generator.spreadPeriods(start: .zero, end: LayerTree.Point(1, 0), transform: [], covering: area)
        #expect(periods == 10_000...10_000)
        let wider = LayerTree.Rect(x: -0.5, y: 0, width: 2.7, height: 1)
        #expect(Generator.spreadPeriods(start: .zero, end: LayerTree.Point(1, 0), transform: [], covering: wider) == -1...2)
    }

    // MARK: - stop cap

    @Test
    func repeatJustUnderTheCapExpands() throws {
        // 2 stops: up to 4096 / 4 = 1024 periods
        let d = try drawnLinear("""
        <defs><linearGradient id="g" gradientUnits="userSpaceOnUse" x1="0" x2="0.1" spreadMethod="repeat">\(stops)</linearGradient></defs>
        <rect width="100" height="10" fill="url(#g)"/>
        """)
        #expect(Generator.maxSpreadPeriods(stopCount: 2) == 1024)
        #expect(d?.gradient.stops.count == 2000)
        #expect(d?.end == LayerTree.Point(100, 0))
    }

    @Test
    func repeatBeyondTheCapPaintsAverageColour() throws {
        let d = try #require(try drawnLinear("""
        <defs><linearGradient id="g" gradientUnits="userSpaceOnUse" x1="0" x2="0.001" spreadMethod="repeat">
          <stop offset="0" stop-color="red"/><stop offset="0.5" stop-color="blue"/>
        </linearGradient></defs>
        <rect width="100" height="10" fill="url(#g)"/>
        """))
        // red→blue over the first half, blue pad over the second: 1/4 red, 3/4 blue
        #expect(d.gradient.stops.count == 2)
        #expect(d.gradient.stops[0].color == d.gradient.stops[1].color)
        guard case let .rgba(r, g, b, a, _) = d.gradient.stops[0].color else {
            Issue.record("expected an rgba colour"); return
        }
        #expect(abs(r - 0.25) < 0.001)
        #expect(abs(g) < 0.001)
        #expect(abs(b - 0.75) < 0.001)
        #expect(abs(a - 1) < 0.001)
    }

    @Test
    func averageColourIsPremultiplied() throws {
        let d = try #require(try drawnLinear("""
        <defs><linearGradient id="g" gradientUnits="userSpaceOnUse" x1="0" x2="0.001" spreadMethod="reflect">
          <stop offset="0" stop-color="red"/><stop offset="1" stop-color="blue" stop-opacity="0"/>
        </linearGradient></defs>
        <rect width="100" height="10" fill="url(#g)"/>
        """))
        // transparent blue contributes no hue
        guard case let .rgba(r, _, b, a, _) = d.gradient.stops[0].color else {
            Issue.record("expected an rgba colour"); return
        }
        #expect(abs(r - 1) < 0.001)
        #expect(abs(b) < 0.001)
        #expect(abs(a - 0.5) < 0.001)
    }

    @Test
    func averageOfMixedColourSpacesConvertsIntoTheGradientSpace() throws {
        // sRGB mid grey and P3 mid grey are the same colour: the average stays that grey
        let d = try #require(try drawnLinear("""
        <defs><linearGradient id="g" gradientUnits="userSpaceOnUse" x1="0" x2="0.001" spreadMethod="repeat">
          <stop offset="0" stop-color="#808080"/><stop offset="1" stop-color="color(display-p3 0.50196 0.50196 0.50196)"/>
        </linearGradient></defs>
        <rect width="100" height="10" fill="url(#g)"/>
        """))
        guard case let .rgba(r, g, b, _, space) = d.gradient.stops[0].color else {
            Issue.record("expected an rgba colour"); return
        }
        #expect(space == .p3)
        #expect(abs(r - 0.50196) < 0.002)
        #expect(abs(g - 0.50196) < 0.002)
        #expect(abs(b - 0.50196) < 0.002)
    }

    @Test
    func colourConversionBetweenSpaces() {
        let grey = LayerTree.Color.convert(r: 0.5, g: 0.5, b: 0.5, from: .p3, to: .srgb)
        #expect(abs(grey.0 - 0.5) < 0.002)
        #expect(abs(grey.2 - 0.5) < 0.002)
        let red = LayerTree.Color.convert(r: 1, g: 0, b: 0, from: .srgb, to: .p3)
        #expect(abs(red.0 - 0.917) < 0.005)   // sRGB red is inside P3
        #expect(abs(red.1 - 0.2) < 0.01)
        #expect(LayerTree.Color.convert(r: 0.2, g: 0.3, b: 0.4, from: .srgb, to: .srgb).1 == 0.3)
    }

    // MARK: - radial

    @Test(arguments: ["reflect", "repeat"])
    func radialSpreadIsPaddedLikeWebKit(spread: String) throws {
        // WebKit pads radial gradients whatever their spreadMethod, so SwiftDraw does too
        let d = try drawnRadial("""
        <defs><radialGradient id="g" gradientUnits="userSpaceOnUse" cx="0" cy="0" r="10" spreadMethod="\(spread)">\(stops)</radialGradient></defs>
        <rect width="30" height="40" fill="url(#g)"/>
        """)
        #expect(d?.endRadius == 10)
        #expect(d?.gradient.stops.count == 2)
    }

    // MARK: - code generation

    @Test
    func repeatGradientCode() throws {
        let svg = #"""
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="10">
          <defs><linearGradient id="g" gradientUnits="userSpaceOnUse" x1="0" x2="25" spreadMethod="repeat">
            <stop offset="0" stop-color="red"/><stop offset="1" stop-color="blue"/>
          </linearGradient></defs>
          <rect width="100" height="10" fill="url(#g)"/>
        </svg>
        """#
        let code = try CGTextRenderer.render(data: Data(svg.utf8), options: .default, api: .uiKit, precision: 2)
        #expect(code.contains("[0.0, 0.25, 0.25, 0.5, 0.5, 0.75, 0.75, 1.0]"))
        #expect(code.contains("end: CGPoint(x: 100, y: 0)"))
    }
}

private extension LayerTreeGradientSpreadTests {

    func parse(_ body: String) throws -> DOM.SVG {
        try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="100" height="100">\(body)</svg>
        """)
    }

    func commands(_ body: String) throws -> [Command] {
        let layer = try LayerTree.Builder(svg: parse(body)).makeLayer()
        let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(), size: .zero, options: .default)
        return generator.renderCommands(for: layer, colorConverter: .default)
    }

    func paint(_ body: String, id: String = "g") throws -> LayerTree.Builder.GradientPaint? {
        try LayerTree.Builder(svg: parse(body)).makeGradientPaint(for: URL(string: "#\(id)")!)
    }

    func linear(_ body: String) throws -> LayerTree.LinearGradient? {
        if case .linear(let g) = try paint(body) { return g }
        return nil
    }

    func color(_ body: String) throws -> LayerTree.Color? {
        if case .color(let c) = try paint(body) { return c }
        return nil
    }

    func drawnLinear(_ body: String) throws -> (gradient: LayerTree.Gradient, start: LayerTree.Point, end: LayerTree.Point)? {
        for case let .drawLinearGradient(g, from: s, to: e) in try commands(body) {
            return (g, s, e)
        }
        return nil
    }

    func drawnRadial(_ body: String) throws -> (gradient: LayerTree.Gradient, endRadius: LayerTree.Float)? {
        for case let .drawRadialGradient(g, startCenter: _, startRadius: _, endCenter: _, endRadius: er) in try commands(body) {
            return (g, er)
        }
        return nil
    }
}
