//
//  LayerTree.GradientTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 13/12/18.
//  Copyright 2020 WhileLoop Pty Ltd. All rights reserved.
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
import XCTest
@testable import SwiftDraw
import Foundation

final class LayerTreeGradientTests: XCTestCase {

    private typealias Command = RendererCommand<LayerTreeProvider.Types>

    private func commands(_ body: String) throws -> [Command] {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="100" height="100">\(body)</svg>
        """)
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(), size: .zero, options: .default)
        return generator.renderCommands(for: layer, colorConverter: .default)
    }

    private func paint(_ body: String, id: String = "g") throws -> LayerTree.Builder.GradientPaint? {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="100" height="100">\(body)</svg>
        """)
        return LayerTree.Builder(svg: svg).makeGradientPaint(for: URL(string: "#\(id)")!)
    }

    private func linear(_ body: String) throws -> LayerTree.LinearGradient? {
        if case .linear(let g) = try paint(body) { return g }
        return nil
    }

    private func radial(_ body: String) throws -> LayerTree.RadialGradient? {
        if case .radial(let g) = try paint(body) { return g }
        return nil
    }

    private func color(_ body: String) throws -> LayerTree.Color? {
        if case .color(let c) = try paint(body) { return c }
        return nil
    }

    private let stops = #"<stop offset="0" stop-color="red"/><stop offset="1" stop-color="blue"/>"#
    private let red = LayerTree.Color.rgba(r: 1, g: 0, b: 0, a: 1, space: .srgb)
    private let blue = LayerTree.Color.rgba(r: 0, g: 0, b: 1, a: 1, space: .srgb)

    // MARK: - href inheritance (SVG 1.1 §13.2.2, §13.2.3)

    func testMultiHopInheritsStopsAndAttributes() throws {
        let g = try linear("""
        <defs>
          <linearGradient id="a">\(stops)</linearGradient>
          <linearGradient id="b" xlink:href="#a" x1="0.25" gradientUnits="userSpaceOnUse" spreadMethod="reflect" gradientTransform="translate(5 0)"/>
          <linearGradient id="c" xlink:href="#b" y2="0.5"/>
          <linearGradient id="g" xlink:href="#c" x2="0.75"/>
        </defs>
        """)
        XCTAssertEqual(g?.gradient.stops.map(\.color), [red, blue])
        XCTAssertEqual(g?.start, LayerTree.Point(0.25, 0))
        XCTAssertEqual(g?.end, LayerTree.Point(0.75, 0.5))
        XCTAssertEqual(g?.units, .userSpaceOnUse)
        XCTAssertEqual(g?.spread, .reflect)
        XCTAssertEqual(g?.transform, [.translate(tx: 5, ty: 0)])
    }

    func testOwnAttributesOverrideReferenced() throws {
        let g = try linear("""
        <defs>
          <linearGradient id="a" x1="0.5" gradientUnits="userSpaceOnUse" spreadMethod="repeat">\(stops)</linearGradient>
          <linearGradient id="g" xlink:href="#a" x1="0.1" gradientUnits="objectBoundingBox" spreadMethod="pad">
            <stop offset="0" stop-color="blue"/><stop offset="1" stop-color="red"/>
          </linearGradient>
        </defs>
        """)
        XCTAssertEqual(g?.gradient.stops.map(\.color), [blue, red])
        XCTAssertEqual(g?.start.x, 0.1)
        XCTAssertEqual(g?.units, .objectBoundingBox)
        XCTAssertEqual(g?.spread, .pad)
    }

    func testCrossKindInheritsStopsAndCommonAttributesOnly() throws {
        let g = try radial("""
        <defs>
          <linearGradient id="a" x1="0.3" gradientUnits="userSpaceOnUse" spreadMethod="repeat">\(stops)</linearGradient>
          <radialGradient id="g" xlink:href="#a" r="20"/>
        </defs>
        """)
        XCTAssertEqual(g?.gradient.stops.map(\.color), [red, blue])
        XCTAssertEqual(g?.units, .userSpaceOnUse)
        XCTAssertEqual(g?.spread, .repeat)
        XCTAssertEqual(g?.endRadius, 20)
        XCTAssertEqual(g?.endCenter, LayerTree.Point(0.5, 0.5))
    }

    func testRadialGeometryInheritsThroughLinear() throws {
        let g = try radial("""
        <defs>
          <radialGradient id="a" cx="10" cy="20" r="30" fx="12">\(stops)</radialGradient>
          <linearGradient id="b" xlink:href="#a" x1="0.3"/>
          <radialGradient id="g" xlink:href="#b" cy="25"/>
        </defs>
        """)
        XCTAssertEqual(g?.endCenter, LayerTree.Point(10, 25))
        XCTAssertEqual(g?.endRadius, 30)
        XCTAssertEqual(g?.center, LayerTree.Point(12, 25))
    }

    func testLinearReferencingRadialUsesDefaultGeometry() throws {
        let g = try linear("""
        <defs>
          <radialGradient id="a" cx="10">\(stops)</radialGradient>
          <linearGradient id="g" xlink:href="#a"/>
        </defs>
        """)
        XCTAssertEqual(g?.start, LayerTree.Point(0, 0))
        XCTAssertEqual(g?.end, LayerTree.Point(1, 0))
    }

    func testHrefCycleEndsChain() throws {
        let g = try linear("""
        <defs>
          <linearGradient id="g" xlink:href="#b" x1="0.2">\(stops)</linearGradient>
          <linearGradient id="b" xlink:href="#c" x2="0.8"/>
          <linearGradient id="c" xlink:href="#g" y2="0.5"/>
        </defs>
        """)
        XCTAssertEqual(g?.start, LayerTree.Point(0.2, 0))
        XCTAssertEqual(g?.end, LayerTree.Point(0.8, 0.5))
    }

    func testHrefCycleWithoutStopsPaintsNone() throws {
        XCTAssertEqual(try color("""
        <defs>
          <linearGradient id="g" xlink:href="#b"/>
          <radialGradient id="b" xlink:href="#g"/>
        </defs>
        """), LayerTree.Color.none)
    }

    func testSelfReferenceKeepsDocument() throws {
        let cmds = try commands("""
        <defs><linearGradient id="g" xlink:href="#g">\(stops)</linearGradient></defs>
        <rect width="10" height="10" fill="url(#g)"/>
        """)
        XCTAssertTrue(cmds.contains { if case .drawLinearGradient = $0 { return true }; return false })
    }

    private func chain(hops: Int) -> String {
        var defs = #"<linearGradient id="n0" x1="0.5">\#(stops)</linearGradient>"#
        for i in 1..<hops {
            defs += "<linearGradient id=\"n\(i)\" xlink:href=\"#n\(i - 1)\"/>"
        }
        defs += "<linearGradient id=\"g\" xlink:href=\"#n\(hops - 1)\" x2=\"0.75\"/>"
        return "<defs>\(defs)</defs>"
    }

    func testFortyHopChainResolves() throws {
        let g = try linear(chain(hops: 40))
        XCTAssertEqual(g?.start.x, 0.5)
        XCTAssertEqual(g?.end.x, 0.75)
        XCTAssertEqual(g?.gradient.stops.count, 2)
    }

    func testLongChainIsBounded() throws {
        // cut after maxGradientHops: the stops at the far end are out of reach, so it paints none
        XCTAssertEqual(try color(chain(hops: LayerTree.Builder.maxGradientHops + 10)), LayerTree.Color.none)
    }

    func testManyShapesSharingAnHrefdGradientAllPaint() throws {
        // more paints than ReferenceGuard.maxReferences: gradient hrefs must not spend that budget
        let count = LayerTree.Builder.ReferenceGuard.maxReferences + 100
        let rects = String(repeating: #"<rect width="1" height="1" fill="url(#g)"/>"#, count: count)
        let cmds = try commands("""
        <defs><linearGradient id="a">\(stops)</linearGradient><linearGradient id="g" xlink:href="#a"/></defs>
        \(rects)
        """)
        let drawn = cmds.filter { if case .drawLinearGradient = $0 { return true }; return false }
        XCTAssertEqual(drawn.count, count)
    }

    func testHrefChainResolvesInsideDeepUse() throws {
        // <use> nesting spends ReferenceGuard depth; the gradient chain must still resolve
        var body = "<defs><linearGradient id=\"a\">\(stops)</linearGradient>"
        body += "<linearGradient id=\"b\" xlink:href=\"#a\"/><linearGradient id=\"c\" xlink:href=\"#b\"/><linearGradient id=\"g\" xlink:href=\"#c\"/></defs>"
        body += "<rect id=\"u0\" width=\"1\" height=\"1\" fill=\"url(#g)\"/>"
        for i in 1...15 {
            body += "<g id=\"u\(i)\"><use xlink:href=\"#u\(i - 1)\"/></g>"
        }
        let cmds = try commands(body)
        XCTAssertGreaterThan(cmds.filter { if case .drawLinearGradient = $0 { return true }; return false }.count, 1)
        XCTAssertFalse(cmds.contains { if case .setFill = $0 { return true }; return false })
    }

    // MARK: - degenerate gradients (SVG 1.1 §13.2.2-§13.2.4)

    func testZeroStopsPaintsNone() throws {
        XCTAssertEqual(try color(#"<defs><linearGradient id="g"/></defs>"#), LayerTree.Color.none)
        let cmds = try commands(#"<defs><radialGradient id="g"/></defs><rect width="10" height="10" fill="url(#g)"/>"#)
        XCTAssertFalse(cmds.contains { if case .fill = $0 { return true }; return false })
    }

    func testSingleStopPaintsSolidColour() throws {
        XCTAssertEqual(try color(#"<defs><linearGradient id="g"><stop offset="0.3" stop-color="red" stop-opacity="0.5"/></linearGradient></defs>"#),
                       .rgba(r: 1, g: 0, b: 0, a: 0.5, space: .srgb))

        let cmds = try commands("""
        <defs><radialGradient id="g"><stop stop-color="blue"/></radialGradient></defs>
        <rect width="10" height="10" fill="url(#g)" fill-opacity="0.5"/>
        <rect width="10" height="10" fill="none" stroke="url(#g)"/>
        """)
        XCTAssertTrue(cmds.contains { if case .setFill(color: .rgba(r: 0, g: 0, b: 1, a: 0.5, space: .srgb)) = $0 { return true }; return false })
        XCTAssertTrue(cmds.contains { if case .setStroke(color: .rgba(r: 0, g: 0, b: 1, a: 1, space: .srgb)) = $0 { return true }; return false })
    }

    func testSingleStopInheritedThroughHref() throws {
        XCTAssertEqual(try color("""
        <defs>
          <linearGradient id="a"><stop stop-color="red"/></linearGradient>
          <radialGradient id="g" xlink:href="#a"/>
        </defs>
        """), red)
    }

    func testZeroLengthVectorPaintsLastStop() throws {
        XCTAssertEqual(try color(#"<defs><linearGradient id="g" x1="0.5" x2="0.5">\#(stops)</linearGradient></defs>"#), blue)
    }

    func testZeroRadiusPaintsLastStop() throws {
        XCTAssertEqual(try color(#"<defs><radialGradient id="g" r="0">\#(stops)</radialGradient></defs>"#), blue)
    }

    func testStopOffsetsAreClampedAndMonotonic() throws {
        let g = try linear("""
        <defs><linearGradient id="g">
          <stop offset="-1" stop-color="red"/><stop offset="0.6" stop-color="red"/>
          <stop offset="0.4" stop-color="blue"/><stop offset="2" stop-color="blue"/>
        </linearGradient></defs>
        """)
        XCTAssertEqual(g?.gradient.stops.map(\.offset), [0, 0.6, 0.6, 1])
    }

    // MARK: - focal point

    func testFocalPointDefaultsToCentre() throws {
        let g = try radial(#"<defs><radialGradient id="g" cx="0.2" cy="0.3" fx="0.25">\#(stops)</radialGradient></defs>"#)
        XCTAssertEqual(g?.center, LayerTree.Point(0.25, 0.3))
        XCTAssertEqual(g?.endCenter, LayerTree.Point(0.2, 0.3))
    }

    // MARK: - spreadMethod (SVG 1.1 §13.2.2)

    func testSpreadMethodParsing() throws {
        XCTAssertEqual(try linear(#"<defs><linearGradient id="g" spreadMethod="repeat">\#(stops)</linearGradient></defs>"#)?.spread, .repeat)
        XCTAssertEqual(try linear(#"<defs><linearGradient id="g" spreadMethod="reflect">\#(stops)</linearGradient></defs>"#)?.spread, .reflect)
        XCTAssertEqual(try linear(#"<defs><linearGradient id="g" spreadMethod="junk">\#(stops)</linearGradient></defs>"#)?.spread, .pad)
        XCTAssertEqual(try linear(#"<defs><linearGradient id="g">\#(stops)</linearGradient></defs>"#)?.spread, .pad)
    }

    private func drawnLinear(_ body: String) throws -> (gradient: LayerTree.Gradient, start: LayerTree.Point, end: LayerTree.Point)? {
        for case let .drawLinearGradient(g, from: s, to: e) in try commands(body) {
            return (g, s, e)
        }
        return nil
    }

    private func drawnRadial(_ body: String) throws -> (gradient: LayerTree.Gradient, center: LayerTree.Point, radius: Float, endCenter: LayerTree.Point, endRadius: Float)? {
        for case let .drawRadialGradient(g, startCenter: c, startRadius: r, endCenter: ec, endRadius: er) in try commands(body) {
            return (g, c, r, ec, er)
        }
        return nil
    }

    func testPadDrawsSinglePeriod() throws {
        let d = try drawnLinear("""
        <defs><linearGradient id="g" gradientUnits="userSpaceOnUse" x1="0" x2="25">\(stops)</linearGradient></defs>
        <rect width="100" height="10" fill="url(#g)"/>
        """)
        XCTAssertEqual(d?.start, LayerTree.Point(0, 0))
        XCTAssertEqual(d?.end, LayerTree.Point(25, 0))
        XCTAssertEqual(d?.gradient.stops.count, 2)
    }

    func testRepeatLinearCoversShape() throws {
        let d = try drawnLinear("""
        <defs><linearGradient id="g" gradientUnits="userSpaceOnUse" x1="0" x2="25" spreadMethod="repeat">\(stops)</linearGradient></defs>
        <rect width="100" height="10" fill="url(#g)"/>
        """)
        XCTAssertEqual(d?.start, LayerTree.Point(0, 0))
        XCTAssertEqual(d?.end, LayerTree.Point(100, 0))
        XCTAssertEqual(d?.gradient.stops.map(\.offset), [0, 0.25, 0.25, 0.5, 0.5, 0.75, 0.75, 1])
        XCTAssertEqual(d?.gradient.stops.map(\.color), [red, blue, red, blue, red, blue, red, blue])
    }

    func testReflectLinearMirrorsOddPeriods() throws {
        let d = try drawnLinear("""
        <defs><linearGradient id="g" gradientUnits="userSpaceOnUse" x1="0" x2="50" spreadMethod="reflect">\(stops)</linearGradient></defs>
        <rect width="100" height="10" fill="url(#g)"/>
        """)
        XCTAssertEqual(d?.end, LayerTree.Point(100, 0))
        XCTAssertEqual(d?.gradient.stops.map(\.offset), [0, 0.5, 0.5, 1])
        XCTAssertEqual(d?.gradient.stops.map(\.color), [red, blue, blue, red])
    }

    func testRepeatExtendsBeforeStart() throws {
        let d = try drawnLinear("""
        <defs><linearGradient id="g" gradientUnits="userSpaceOnUse" x1="50" x2="75" spreadMethod="reflect">\(stops)</linearGradient></defs>
        <rect width="100" height="10" fill="url(#g)"/>
        """)
        // periods -2...1: odd period -1 is mirrored
        XCTAssertEqual(d?.start, LayerTree.Point(0, 0))
        XCTAssertEqual(d?.end, LayerTree.Point(100, 0))
        XCTAssertEqual(d?.gradient.stops.map(\.color), [red, blue, blue, red, red, blue, blue, red])
    }

    func testRepeatCompletesPartialStops() throws {
        let d = try drawnLinear("""
        <defs><linearGradient id="g" gradientUnits="userSpaceOnUse" x1="0" x2="50" spreadMethod="repeat">
          <stop offset="0.25" stop-color="red"/><stop offset="0.75" stop-color="blue"/>
        </linearGradient></defs>
        <rect width="100" height="10" fill="url(#g)"/>
        """)
        XCTAssertEqual(d?.gradient.stops.map(\.offset), [0, 0.125, 0.375, 0.5, 0.5, 0.625, 0.875, 1])
    }

    func testRepeatHonoursGradientTransform() throws {
        // scaled ×2: one period spans 50 units, so two periods cover the rect
        let d = try drawnLinear("""
        <defs><linearGradient id="g" gradientUnits="userSpaceOnUse" x1="0" x2="25" spreadMethod="repeat" gradientTransform="scale(2)">\(stops)</linearGradient></defs>
        <rect width="100" height="10" fill="url(#g)"/>
        """)
        XCTAssertEqual(d?.end, LayerTree.Point(50, 0))
        XCTAssertEqual(d?.gradient.stops.count, 4)
    }

    func testRepeatJustUnderTheCapExpands() throws {
        // 2 stops: up to 4096 / 4 = 1024 periods
        let d = try drawnLinear("""
        <defs><linearGradient id="g" gradientUnits="userSpaceOnUse" x1="0" x2="0.1" spreadMethod="repeat">\(stops)</linearGradient></defs>
        <rect width="100" height="10" fill="url(#g)"/>
        """)
        XCTAssertEqual(LayerTree.CommandGenerator<LayerTreeProvider>.maxSpreadPeriods(stopCount: 2), 1024)
        XCTAssertEqual(d?.gradient.stops.count, 2000)
        XCTAssertEqual(d?.end, LayerTree.Point(100, 0))
    }

    func testRepeatBeyondTheCapPaintsAverageColour() throws {
        let d = try drawnLinear("""
        <defs><linearGradient id="g" gradientUnits="userSpaceOnUse" x1="0" x2="0.001" spreadMethod="repeat">
          <stop offset="0" stop-color="red"/><stop offset="0.5" stop-color="blue"/>
        </linearGradient></defs>
        <rect width="100" height="10" fill="url(#g)"/>
        """)
        // red→blue over the first half, blue pad over the second: 1/4 red, 3/4 blue
        guard let d, case let .rgba(r, g, b, a, _) = d.gradient.stops[0].color else { return XCTFail("no gradient") }
        XCTAssertEqual(d.gradient.stops.count, 2)
        XCTAssertEqual(d.gradient.stops[0].color, d.gradient.stops[1].color)
        XCTAssertEqual(r, 0.25, accuracy: 0.001)
        XCTAssertEqual(g, 0, accuracy: 0.001)
        XCTAssertEqual(b, 0.75, accuracy: 0.001)
        XCTAssertEqual(a, 1, accuracy: 0.001)
    }

    func testAverageColourIsPremultiplied() throws {
        let d = try drawnLinear("""
        <defs><linearGradient id="g" gradientUnits="userSpaceOnUse" x1="0" x2="0.001" spreadMethod="reflect">
          <stop offset="0" stop-color="red"/><stop offset="1" stop-color="blue" stop-opacity="0"/>
        </linearGradient></defs>
        <rect width="100" height="10" fill="url(#g)"/>
        """)
        // transparent blue contributes no hue
        guard let d, case let .rgba(r, _, b, a, _) = d.gradient.stops[0].color else { return XCTFail("no gradient") }
        XCTAssertEqual(r, 1, accuracy: 0.001)
        XCTAssertEqual(b, 0, accuracy: 0.001)
        XCTAssertEqual(a, 0.5, accuracy: 0.001)
    }

    func testRepeatFarFromItsVectorStillExpands() throws {
        // 10 periods per unit, shape at x = 20 000: only the periods under the shape are drawn,
        // not every period from 0 (which would exceed the cap and fall back to the average colour)
        let d = try drawnLinear("""
        <defs><linearGradient id="g" gradientUnits="userSpaceOnUse" x1="0" x2="0.1" spreadMethod="repeat">\(stops)</linearGradient></defs>
        <rect x="20000" width="100" height="10" fill="url(#g)"/>
        """)
        XCTAssertGreaterThan(d?.gradient.stops.count ?? 0, 1000)
    }

    func testMakePeriodsLinearHasNoPeriodZeroFloor() {
        typealias Generator = LayerTree.CommandGenerator<LayerTreeProvider>
        XCTAssertEqual(Generator.makePeriods(lower: 10_000.3, upper: 10_000.7, includingZero: false), 10_000...10_000)
        XCTAssertEqual(Generator.makePeriods(lower: -0.5, upper: 2.2, includingZero: false), -1...2)
        XCTAssertEqual(Generator.makePeriods(lower: 5, upper: 5, includingZero: false), 5...5)
        XCTAssertEqual(Generator.makePeriods(lower: 10_000.3, upper: 10_000.7), 0...10_000)
    }

    func testAverageOfMixedColourSpacesConvertsIntoTheGradientSpace() throws {
        // sRGB mid grey and P3 mid grey are the same colour: the average stays that grey
        let d = try drawnLinear("""
        <defs><linearGradient id="g" gradientUnits="userSpaceOnUse" x1="0" x2="0.001" spreadMethod="repeat">
          <stop offset="0" stop-color="#808080"/><stop offset="1" stop-color="color(display-p3 0.50196 0.50196 0.50196)"/>
        </linearGradient></defs>
        <rect width="100" height="10" fill="url(#g)"/>
        """)
        guard let d, case let .rgba(r, g, b, _, space) = d.gradient.stops[0].color else { return XCTFail("no gradient") }
        XCTAssertEqual(space, .p3)
        XCTAssertEqual(r, 0.50196, accuracy: 0.002)
        XCTAssertEqual(g, 0.50196, accuracy: 0.002)
        XCTAssertEqual(b, 0.50196, accuracy: 0.002)
    }

    func testColourConversionBetweenSpaces() {
        let grey = LayerTree.Color.convert(r: 0.5, g: 0.5, b: 0.5, from: .p3, to: .srgb)
        XCTAssertEqual(grey.0, 0.5, accuracy: 0.002)
        XCTAssertEqual(grey.2, 0.5, accuracy: 0.002)
        let red = LayerTree.Color.convert(r: 1, g: 0, b: 0, from: .srgb, to: .p3)
        XCTAssertEqual(red.0, 0.917, accuracy: 0.005)   // sRGB red is inside P3
        XCTAssertEqual(red.1, 0.2, accuracy: 0.01)
        XCTAssertEqual(LayerTree.Color.convert(r: 0.2, g: 0.3, b: 0.4, from: .srgb, to: .srgb).1, 0.3)
    }

    func testObjectBoundingBoxRepeatWithTransform() throws {
        let d = try drawnLinear("""
        <defs><linearGradient id="g" x1="0" x2="0.25" spreadMethod="repeat" gradientTransform="translate(10 0)">\(stops)</linearGradient></defs>
        <rect width="100" height="10" fill="url(#g)"/>
        """)
        // one period is 25 units, shifted by 10: x -10...90 is periods -1...3
        XCTAssertEqual(d?.start, LayerTree.Point(-25, 0))
        XCTAssertEqual(d?.end, LayerTree.Point(100, 0))
        XCTAssertEqual(d?.gradient.stops.count, 10)
    }

    func testObjectBoundingBoxReflectWithTransform() throws {
        let d = try drawnLinear("""
        <defs><linearGradient id="g" x1="0" x2="0.5" spreadMethod="reflect" gradientTransform="scale(0.5)">\(stops)</linearGradient></defs>
        <rect width="100" height="10" fill="url(#g)"/>
        """)
        // scaled by 0.5: x 0...100 maps to 0...200 in gradient space, four periods of 50
        XCTAssertEqual(d?.end, LayerTree.Point(200, 0))
        XCTAssertEqual(d?.gradient.stops.map(\.color), [red, blue, blue, red, red, blue, blue, red])
    }

    func testObjectBoundingBoxRadialRepeatWithTransform() throws {
        let d = try drawnRadial("""
        <defs><radialGradient id="g" r="0.25" spreadMethod="repeat" gradientTransform="scale(2)">\(stops)</radialGradient></defs>
        <rect width="40" height="40" fill="url(#g)"/>
        """)
        // centre (20, 20), radius 10; scale(2) maps the rect to 0...20, farthest corner 28.3 away
        XCTAssertEqual(d?.endCenter, LayerTree.Point(20, 20))
        XCTAssertEqual(d?.endRadius, 30)
        XCTAssertEqual(d?.gradient.stops.count, 6)
    }

    func testObjectBoundingBoxRadialReflect() throws {
        let d = try drawnRadial("""
        <defs><radialGradient id="g" r="0.25" spreadMethod="reflect" gradientTransform="translate(5 0)">\(stops)</radialGradient></defs>
        <rect width="40" height="40" fill="url(#g)"/>
        """)
        // corners -5...35: farthest from (20, 20) is 35.4, four periods of 10
        XCTAssertEqual(d?.endRadius, 40)
        XCTAssertEqual(d?.gradient.stops.map(\.color), [red, blue, blue, red, red, blue, blue, red])
    }

    func testRadialStrokeWithSpread() throws {
        let d = try drawnRadial("""
        <defs><radialGradient id="g" gradientUnits="userSpaceOnUse" cx="50" cy="50" r="10" spreadMethod="repeat">\(stops)</radialGradient></defs>
        <circle cx="50" cy="50" r="20" fill="none" stroke="url(#g)" stroke-width="4"/>
        """)
        // bounds 30...70 outset by 8 (miter limit 4): farthest corner 39.6 away, four periods
        XCTAssertEqual(d?.endRadius, 40)
        XCTAssertEqual(d?.gradient.stops.count, 8)
    }

    func testRadialPeriodsAreExactWithFocalNearEdge() throws {
        let d = try drawnRadial("""
        <defs><radialGradient id="g" gradientUnits="userSpaceOnUse" cx="50" cy="50" r="50" fx="99" fy="50" spreadMethod="repeat">\(stops)</radialGradient></defs>
        <rect width="100" height="100" fill="url(#g)"/>
        """)
        // the farthest corners, (100, 0) and (100, 100), are covered from t = 5.54: six periods,
        // not the ~110 that a bound of (distance − r0) / (Δr − |Δc|) gives
        XCTAssertEqual(d?.gradient.stops.count, 12)
    }

    func testSquareCapCoverage() throws {
        func end(_ cap: String) throws -> LayerTree.Point? {
            try drawnLinear("""
            <defs><linearGradient id="g" gradientUnits="userSpaceOnUse" x1="0" x2="0" y1="0" y2="10" spreadMethod="repeat">\(stops)</linearGradient></defs>
            <line x1="50" y1="12" x2="50" y2="37.5" stroke="url(#g)" stroke-width="4" stroke-linejoin="round" stroke-linecap="\(cap)"/>
            """)?.end
        }
        // a square cap reaches 2·√2 = 2.83 beyond y = 37.5, past the fourth period
        XCTAssertEqual(try end("round"), LayerTree.Point(0, 40))
        XCTAssertEqual(try end("square"), LayerTree.Point(0, 50))
    }

    func testRepeatRadialCoversShape() throws {
        let d = try drawnRadial("""
        <defs><radialGradient id="g" gradientUnits="userSpaceOnUse" cx="0" cy="0" r="10" spreadMethod="repeat">\(stops)</radialGradient></defs>
        <rect width="30" height="40" fill="url(#g)"/>
        """)
        // the farthest corner is 50 from the centre: five periods
        XCTAssertEqual(d?.center, LayerTree.Point(0, 0))
        XCTAssertEqual(d?.radius, 0)
        XCTAssertEqual(d?.endRadius, 50)
        XCTAssertEqual(d?.gradient.stops.count, 10)
    }

    func testReflectRadialWithFocalPoint() throws {
        let d = try drawnRadial("""
        <defs><radialGradient id="g" gradientUnits="userSpaceOnUse" cx="10" cy="0" r="20" fx="5" spreadMethod="reflect">\(stops)</radialGradient></defs>
        <rect width="20" height="20" fill="url(#g)"/>
        """)
        guard let d else { return XCTFail("no radial gradient") }
        let periods = Float(d.gradient.stops.count / 2)
        XCTAssertGreaterThan(periods, 1)
        XCTAssertEqual(d.endRadius, 20 * periods)
        XCTAssertEqual(d.endCenter, LayerTree.Point(5 + 5 * periods, 0))
        XCTAssertEqual(d.gradient.stops.map(\.color).prefix(4), [red, blue, blue, red])
    }

    func testRadialFocalOutsideCirclePads() throws {
        let d = try drawnRadial("""
        <defs><radialGradient id="g" gradientUnits="userSpaceOnUse" cx="10" cy="10" r="5" fx="30" spreadMethod="repeat">\(stops)</radialGradient></defs>
        <rect width="20" height="20" fill="url(#g)"/>
        """)
        XCTAssertEqual(d?.endRadius, 5)
        XCTAssertEqual(d?.gradient.stops.count, 2)
    }

    func testRepeatStrokeCoversStrokeWidth() throws {
        let d = try drawnLinear("""
        <defs><linearGradient id="g" gradientUnits="userSpaceOnUse" x1="0" x2="0" y1="0" y2="10" spreadMethod="repeat">\(stops)</linearGradient></defs>
        <line x1="50" y1="10" x2="50" y2="30" stroke="url(#g)" stroke-width="4" stroke-linecap="round"/>
        """)
        // the line spans y 10...30, the stroke reaches 2 beyond (miter limit 4 → 8): periods 0...3
        XCTAssertEqual(d?.start, LayerTree.Point(0, 0))
        XCTAssertEqual(d?.end, LayerTree.Point(0, 40))
    }
}
