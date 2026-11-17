//
//  LayerTree.TextBaselineTests.swift
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

import Foundation
import SwiftDrawDOM
@testable import SwiftDraw
import Testing
#if canImport(CoreText)
import CoreText
#endif

/// `dominant-baseline`, `alignment-baseline` and `baseline-shift`
struct LayerTreeTextBaselineTests {

    private func parse(_ text: String) throws -> DOM.SVG {
        try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="200" height="200" font-family="Times" font-size="100">\(text)</svg>
        """)
    }

    /// The state of each text node, in order
    private func runStates(_ text: String) throws -> [LayerTree.Builder.State] {
        let svg = try parse(text)
        let builder = LayerTree.Builder(svg: svg)
        let root = builder.createState(for: svg, inheriting: .init())
        var element = try #require(svg.childElements.first)
        var state = builder.createState(for: element, inheriting: root)
        while let group = element as? DOM.Group, let child = group.childElements.first {
            element = child
            state = builder.createState(for: element, inheriting: state)
        }
        let text = try #require(element as? DOM.Text)
        var states = [LayerTree.Builder.State]()
        func collect(_ runs: [DOM.TextRun], _ state: LayerTree.Builder.State) {
            for run in runs {
                switch run {
                case .text: states.append(state)
                case .span(let span): collect(span.runs, builder.createState(for: span, inheriting: state))
                }
            }
        }
        collect(text.runs, state)
        return states
    }

    // MARK: - parsing

    @Test(arguments: [
        ("auto", DOM.TextBaseline.auto), ("alphabetic", .alphabetic), ("middle", .middle), ("central", .central),
        ("hanging", .hanging), ("mathematical", .mathematical), ("ideographic", .ideographic),
        ("text-before-edge", .textBeforeEdge), ("text-after-edge", .textAfterEdge),
        // CSS Inline 3 and SVG 1.1 aliases
        ("text-top", .textBeforeEdge), ("text-bottom", .textAfterEdge),
        ("before-edge", .textBeforeEdge), ("after-edge", .textAfterEdge),
        ("baseline", .auto), ("use-script", .auto),
    ] as [(String, DOM.TextBaseline)])
    func baselinesAreParsed(value: String, expected: DOM.TextBaseline) {
        #expect(DOM.TextBaseline(css: value) == expected)
    }

    @Test(arguments: ["no-change", "reset-size", "top", ""])
    func baselinesThatKeepTheParentsAreNotParsed(value: String) {
        #expect(DOM.TextBaseline(css: value) == nil)
    }

    @Test
    func inheritIsParsed() {
        #expect(DOM.TextBaseline(css: " INHERIT ") == .inherit)
    }

    // alignment-baseline is not inherited, but `inherit` takes the parent's
    @Test
    func alignmentBaselineInheritTakesTheParents() throws {
        let states = try runStates(#"<g alignment-baseline="hanging"><text alignment-baseline="inherit">A</text></g>"#)
        #expect(states.map(\.alignmentBaseline) == [.hanging])
        let plain = try runStates(#"<g alignment-baseline="hanging"><text>A</text></g>"#)
        #expect(plain.map(\.alignmentBaseline) == [nil])
    }

    // dominant-baseline is inherited anyway: `inherit` keeps the parent's
    @Test
    func dominantBaselineInheritKeepsTheParents() throws {
        let states = try runStates(#"<g dominant-baseline="central"><text dominant-baseline="inherit">A</text></g>"#)
        #expect(states.map(\.textBaseline) == [.central])
    }

    @Test(arguments: [
        ("baseline", DOM.BaselineShift.baseline), ("sub", .sub), ("super", .super), ("inherit", .inherit),
        ("10", .length(.absolute(10))), ("-2mm", .length(.absolute(-2 * 96 / 25.4))),
        ("50%", .length(.percentage(50))), ("0.5em", .length(.em(0.5))),
    ] as [(String, DOM.BaselineShift)])
    func baselineShiftIsParsed(value: String, expected: DOM.BaselineShift) throws {
        let text = try #require(try parse(#"<text baseline-shift="\#(value)">A</text>"#).childElements.first)
        switch (text.attributes.baselineShift, expected) {
        case (.length(.absolute(let a))?, .length(.absolute(let b))):
            #expect(abs(a - b) < 0.001)
        default:
            #expect(text.attributes.baselineShift == expected)
        }
    }

    // MARK: - state

    @Test
    func dominantBaselineIsInheritedAndAlignmentBaselineIsNot() throws {
        let states = try runStates(#"<text dominant-baseline="middle">A<tspan alignment-baseline="hanging">B<tspan>C</tspan></tspan></text>"#)
        #expect(states.map(\.textBaseline) == [.middle, .middle, .middle])
        #expect(states.map(\.alignmentBaseline) == [nil, .hanging, nil])
        let builder = LayerTree.Builder(svg: DOM.SVG(width: 1, height: 1))
        // the run's baseline: its alignment-baseline, else its dominant-baseline
        #expect(states.map { builder.makeTextAttributes(with: $0).baseline } == [.middle, .hanging, .middle])
    }

    @Test
    func nestedShiftsAddUp() throws {
        let states = try runStates(#"<text>A<tspan baseline-shift="10">B<tspan baseline-shift="baseline">C<tspan font-size="50" baseline-shift="20%">D</tspan></tspan></tspan></text>"#)
        #expect(states.map { $0.baselineShifts.map(\.shift) } == [
            [],
            [.length(.absolute(10))],
            [.length(.absolute(10)), .baseline],
            [.length(.absolute(10)), .baseline, .length(.percentage(20))],
        ])
        // a percentage is of the font-size it was declared at
        #expect(states.last?.baselineShifts.last?.fontSize == 50)
    }

    @Test(arguments: [
        #"<text baseline-shift="super">A</text>"#,
        #"<g baseline-shift="super"><text>A</text></g>"#,
    ])
    func baselineShiftIsNotAppliedToTextOrInherited(text: String) throws {
        #expect(try runStates(text).allSatisfy { $0.baselineShifts.isEmpty })
    }

    @Test
    func inheritTakesTheParentsShift() throws {
        let states = try runStates(#"<text><tspan baseline-shift="10"><tspan baseline-shift="inherit">A</tspan></tspan></text>"#)
        #expect(states.first?.baselineShifts.map(\.shift) == [.length(.absolute(10)), .length(.absolute(10))])
    }

    @Test
    func lengthShiftsRaiseTheText() {
        let attributes = LayerTree.TextAttributes(color: .black, font: [.name("Times")], size: 100, anchor: .start, baseline: .auto)
        let shifts = [LayerTree.Builder.BaselineShiftEntry(shift: .length(.absolute(10)), fontSize: 100),
                      LayerTree.Builder.BaselineShiftEntry(shift: .length(.percentage(20)), fontSize: 50)]
        #expect(LayerTree.Builder.makeBaselineOffset(with: attributes, shifts: shifts) == -20)
    }

#if canImport(CoreText)
    @Test(arguments: [
        (DOM.TextBaseline.auto, 0 as LayerTree.Float),
        (.alphabetic, 0),
        (.textBeforeEdge, 75),
        (.textAfterEdge, -25),
        (.ideographic, -25),
        (.central, 25),
        (.hanging, 60),
        (.mathematical, 37.5),
    ] as [(DOM.TextBaseline, LayerTree.Float)])
    func baselinesComeFromTheFontsMetrics(baseline: DOM.TextBaseline, offset: LayerTree.Float) {
        // Times: ascent 0.75 em, descent 0.25 em
        let font = CTFontCreateWithName("Times-Roman" as CFString, 100, nil)
        #expect(abs(LayerTree.Builder.makeYOffset(font: font, baseline: baseline) - offset) < 0.01)
        #expect(abs(LayerTree.Builder.makeYOffset(font: font, baseline: .middle) - LayerTree.Float(CTFontGetXHeight(font)) / 2) < 0.01)
    }

    @Test
    func subAndSuperUseTheFontsScriptOffsets() {
        let font = CTFontCreateWithName("Times-Roman" as CFString, 100, nil)
        // OS/2 ySubscriptYOffset 140 and ySuperscriptYOffset 477 of 2048 units
        #expect(abs(LayerTree.Builder.makeBaselineShift(.sub, font: font, fontSize: 100) - -6.836) < 0.01)
        #expect(abs(LayerTree.Builder.makeBaselineShift(.super, font: font, fontSize: 100) - 23.291) < 0.01)
    }

    @Test
    func hangingTextHangsBelowItsY() throws {
        func y(_ text: String) throws -> LayerTree.Float? {
            let layer = LayerTree.Builder(svg: try parse(text)).makeLayer()
            func points(_ layer: LayerTree.Layer) -> [LayerTree.Point] {
                layer.contents.flatMap { contents -> [LayerTree.Point] in
                    switch contents {
                    case let .text(_, point, _): [point]
                    case .layer(let child): points(child)
                    default: []
                    }
                }
            }
            return points(layer).first?.y
        }
        #expect(try y(#"<text x="10" y="100">H</text>"#) == 100)
        #expect(try y(#"<text x="10" y="100" dominant-baseline="hanging">H</text>"#) == 160)
        #expect(try y(#"<text x="10" y="100"><tspan baseline-shift="super">H</tspan></text>"#).map { abs($0 - 76.709) < 0.01 } == true)
    }
#endif
}
