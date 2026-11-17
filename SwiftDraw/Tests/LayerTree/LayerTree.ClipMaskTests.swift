//
//  LayerTree.ClipMaskTests.swift
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

import Testing
@testable import SwiftDraw
import Foundation

/// SD8: clip paths and masks to spec (SVG 1.1 §14.3.5, §14.4). Asserts on the command stream.
struct LayerTreeClipMaskTests {

    typealias Command = RendererCommand<LayerTreeProvider.Types>

    private func commands(_ body: String) throws -> [Command] {
        let svg = try DOM.SVG.parse(
            xml: """
                <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="100" height="100">\(body)</svg>
                """
        )
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(), size: .zero, options: .default)
        return flattened(generator.renderCommands(for: layer, colorConverter: .default))
    }

    /// Mask contents are drawn inside `.clipToMask` (#162): inline them so assertions see every command.
    private func flattened(_ commands: [Command]) -> [Command] {
        commands.flatMap { command -> [Command] in
            if case let .clipToMask(contents) = command { return [command] + flattened(contents) }
            return [command]
        }
    }

    private func clips(_ commands: [Command]) -> [(bounds: LayerTree.Rect, rule: LayerTree.FillRule)] {
        commands.compactMap {
            guard case let .setClip(path: shapes, rule: rule) = $0 else { return nil }
            return (bounds(shapes), rule)
        }
    }

    private func fills(_ commands: [Command]) -> [(bounds: LayerTree.Rect, rule: LayerTree.FillRule)] {
        commands.compactMap {
            guard case let .fill(shapes, rule: rule) = $0 else { return nil }
            return (bounds(shapes), rule)
        }
    }

    private func bounds(_ shapes: [LayerTree.Shape]) -> LayerTree.Rect {
        shapes.map(\.path.bounds).reduce(nil as LayerTree.Rect?) { acc, b in acc.map { $0.union(b) } ?? b } ?? .zero
    }

    private func maskContents(_ commands: [Command]) -> [Command]? {
        commands.lazy.compactMap { command -> [Command]? in
            if case let .clipToMask(contents) = command { return contents } else { return nil }
        }.first
    }

    private func transparencyLayers(_ commands: [Command]) -> Int {
        commands.filter { if case .pushTransparencyLayer = $0 { return true } else { return false } }.count
    }

    private func assertRect(
        _ rect: LayerTree.Rect?,
        _ x: Float,
        _ y: Float,
        _ w: Float,
        _ h: Float,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        guard let rect else {
            Issue.record("no rect", sourceLocation: sourceLocation)
            return
        }
        #expect(abs(rect.x - x) <= 0.001, sourceLocation: sourceLocation)
        #expect(abs(rect.y - y) <= 0.001, sourceLocation: sourceLocation)
        #expect(abs(rect.width - w) <= 0.001, sourceLocation: sourceLocation)
        #expect(abs(rect.height - h) <= 0.001, sourceLocation: sourceLocation)
    }

    // MARK: - clipPathUnits

    @Test
    func clipPathUnitsObjectBoundingBox() throws {
        let c = try commands(
            """
            <clipPath id="c" clipPathUnits="objectBoundingBox"><rect x="0.25" y="0.25" width="0.5" height="0.5"/></clipPath>
            <rect x="20" y="20" width="60" height="60" clip-path="url(#c)"/>
            """
        )
        #expect(clips(c).count == 1)
        assertRect(clips(c).first?.bounds, 35, 35, 30, 30)
    }

    @Test
    func clipPathUnitsObjectBoundingBoxOfGroup() throws {
        // group bounds: union of (0,0,20,20) and (60,40,40,40 translated by 0,20) = (0,0,100,100)
        let c = try commands(
            """
            <clipPath id="c" clipPathUnits="objectBoundingBox"><rect width="0.5" height="1"/></clipPath>
            <g clip-path="url(#c)">
              <rect width="20" height="20"/>
              <rect x="60" y="40" width="40" height="40" transform="translate(0 20)"/>
            </g>
            """
        )
        assertRect(clips(c).first?.bounds, 0, 0, 50, 100)
    }

    @Test
    func clipPathUnitsObjectBoundingBoxIgnoresElementTransform() throws {
        // the clip lives in the element's user space, after its own transform
        let c = try commands(
            """
            <clipPath id="c" clipPathUnits="objectBoundingBox"><rect width="0.5" height="0.5"/></clipPath>
            <rect x="10" y="10" width="20" height="20" transform="scale(2)" clip-path="url(#c)"/>
            """
        )
        assertRect(clips(c).first?.bounds, 10, 10, 10, 10)
    }

    @Test
    func clipPathUnitsObjectBoundingBoxAppliesClipPathTransform() throws {
        let c = try commands(
            """
            <clipPath id="c" clipPathUnits="objectBoundingBox" transform="translate(0.5 0)"><rect width="0.5" height="1"/></clipPath>
            <rect width="40" height="40" clip-path="url(#c)"/>
            """
        )
        // the bbox mapping comes first, then the transform in user units (Blink, Gecko, resvg)
        assertRect(clips(c).first?.bounds, 0.5, 0, 20, 40)
    }

    @Test
    func clipPathUnitsObjectBoundingBoxOfEmptyBoxClipsEverything() throws {
        let c = try commands(
            """
            <clipPath id="c" clipPathUnits="objectBoundingBox"><rect width="1" height="1"/></clipPath>
            <line x1="0" y1="10" x2="100" y2="10" stroke="black" clip-path="url(#c)"/>
            """
        )
        assertRect(clips(c).first?.bounds, 0, 0, 0, 0)
    }

    @Test
    func clipPathUnitsUserSpaceOnUse() throws {
        let c = try commands(
            """
            <clipPath id="c" clipPathUnits="userSpaceOnUse"><rect x="5" y="5" width="10" height="10"/></clipPath>
            <rect x="20" y="20" width="60" height="60" clip-path="url(#c)"/>
            """
        )
        assertRect(clips(c).first?.bounds, 5, 5, 10, 10)
    }

    @Test
    func invalidClipPathUnitsKeepsDocument() throws {
        let c = try commands(
            """
            <clipPath id="c" clipPathUnits="bogus"><rect x="5" y="5" width="10" height="10"/></clipPath>
            <rect x="20" y="20" width="60" height="60" clip-path="url(#c)"/>
            """
        )
        assertRect(clips(c).first?.bounds, 5, 5, 10, 10)
        #expect(fills(c).count == 1)
    }

    // MARK: - clip-rule

    @Test
    func clipRuleOnClipPathChild() throws {
        let c = try commands(
            """
            <clipPath id="c"><rect width="10" height="10" clip-rule="evenodd"/></clipPath>
            <rect width="50" height="50" clip-path="url(#c)"/>
            """
        )
        #expect(clips(c).first?.rule == .evenodd)
    }

    @Test
    func clipRuleInheritedFromClipPath() throws {
        let c = try commands(
            """
            <clipPath id="c" clip-rule="evenodd"><rect width="10" height="10"/></clipPath>
            <rect width="50" height="50" clip-path="url(#c)"/>
            """
        )
        #expect(clips(c).first?.rule == .evenodd)
    }

    @Test
    func clipRuleOnChildOverridesClipPath() throws {
        let c = try commands(
            """
            <clipPath id="c" clip-rule="evenodd"><rect width="10" height="10" clip-rule="nonzero"/></clipPath>
            <rect width="50" height="50" clip-path="url(#c)"/>
            """
        )
        #expect(clips(c).first?.rule == .nonzero)
    }

    @Test
    func clipRuleOnReferencingElementIsNotUsed() throws {
        // clip-rule is inherited by the <clipPath> contents from the <clipPath>, not from the element it clips
        let c = try commands(
            """
            <clipPath id="c"><rect width="10" height="10"/></clipPath>
            <rect width="50" height="50" clip-rule="evenodd" clip-path="url(#c)"/>
            """
        )
        #expect(clips(c).first?.rule == .nonzero)
    }

    @Test
    func clipRuleFromStyleAttribute() throws {
        let c = try commands(
            """
            <clipPath id="c"><path d="M0 0h10v10h-10z" style="clip-rule:evenodd"/></clipPath>
            <rect width="50" height="50" clip-path="url(#c)"/>
            """
        )
        #expect(clips(c).first?.rule == .evenodd)
    }

    @Test
    func mixedClipRulesBecomeMask() throws {
        let c = try commands(
            """
            <clipPath id="c">
              <rect width="10" height="10" clip-rule="evenodd"/>
              <rect x="20" width="10" height="10"/>
            </clipPath>
            <rect width="50" height="50" fill="red" clip-path="url(#c)"/>
            """
        )
        #expect(clips(c).isEmpty)
        #expect(transparencyLayers(c) > 0)
        let maskFills = fills(c).filter { $0.bounds.width == 10 }
        #expect(maskFills.map(\.rule) == [.evenodd, .nonzero])
    }

    // MARK: - <use> and <text> inside <clipPath>

    @Test
    func useInsideClipPath() throws {
        let c = try commands(
            """
            <defs><rect id="r" width="10" height="10" transform="translate(1 2)"/></defs>
            <clipPath id="c"><use xlink:href="#r" x="20" y="30" transform="scale(2)"/></clipPath>
            <rect width="100" height="100" clip-path="url(#c)"/>
            """
        )
        // rect → translate(1,2) → translate(20,30) → scale(2)
        assertRect(clips(c).first?.bounds, 42, 64, 20, 20)
    }

    @Test
    func useInsideClipPathInheritsClipRule() throws {
        let c = try commands(
            """
            <defs><rect id="r" width="10" height="10"/></defs>
            <clipPath id="c"><use xlink:href="#r" clip-rule="evenodd"/></clipPath>
            <rect width="100" height="100" clip-path="url(#c)"/>
            """
        )
        #expect(clips(c).first?.rule == .evenodd)
    }

    @Test
    func useOfGroupInsideClipPathIsIgnored() throws {
        let c = try commands(
            """
            <defs><g id="g"><rect width="10" height="10"/></g></defs>
            <clipPath id="c"><use xlink:href="#g"/></clipPath>
            <rect width="100" height="100" clip-path="url(#c)"/>
            """
        )
        assertRect(clips(c).first?.bounds, 0, 0, 0, 0)
    }

    @Test
    func textInsideClipPathBecomesMask() throws {
        let svg = try DOM.SVG.parse(
            xml: """
                <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
                  <clipPath id="c"><text x="10" y="50" fill="black">Hi</text></clipPath>
                  <rect width="100" height="100" fill="red" clip-path="url(#c)"/>
                </svg>
                """
        )
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let clipped = try #require(findLayer(in: layer) { $0.mask != nil })
        #expect(clipped.clip.isEmpty)
        let texts = allContents(of: try #require(clipped.mask)).compactMap { c -> LayerTree.TextAttributes? in
            if case let .text(_, _, att) = c { return att } else { return nil }
        }
        #expect(texts.map(\.color) == [.white])
    }

    @Test
    func emptyClipPathClipsEverything() throws {
        let c = try commands(
            """
            <clipPath id="c"></clipPath>
            <rect width="50" height="50" clip-path="url(#c)"/>
            """
        )
        assertRect(clips(c).first?.bounds, 0, 0, 0, 0)
    }

    @Test
    func hiddenClipPathChildIsIgnored() throws {
        let c = try commands(
            """
            <clipPath id="c"><rect width="10" height="10"/><rect x="40" width="10" height="10" display="none"/></clipPath>
            <rect width="50" height="50" clip-path="url(#c)"/>
            """
        )
        assertRect(clips(c).first?.bounds, 0, 0, 10, 10)
    }

    // MARK: - clip-path on <clipPath>

    @Test
    func clipPathOnClipPathIntersects() throws {
        let c = try commands(
            """
            <clipPath id="inner"><rect x="5" y="5" width="10" height="10"/></clipPath>
            <clipPath id="c" clip-path="url(#inner)"><rect width="10" height="10"/></clipPath>
            <rect width="50" height="50" fill="red" clip-path="url(#c)"/>
            """
        )
        // the outer clip is drawn as a mask, clipped by the inner one
        #expect(transparencyLayers(c) > 0)
        assertRect(clips(c).first?.bounds, 5, 5, 10, 10)
        // the mask is drawn before the element it clips (#162)
        #expect(fills(c).map(\.bounds.width) == [10, 50])
    }

    @Test
    func selfReferencingClipPathKeepsDocument() throws {
        let c = try commands(
            """
            <clipPath id="c" clip-path="url(#c)"><rect width="10" height="10"/></clipPath>
            <rect width="50" height="50" clip-path="url(#c)"/>
            """
        )
        #expect(!fills(c).isEmpty)
    }

    @Test
    func clipAndMaskTogether() throws {
        let svg = try DOM.SVG.parse(
            xml: """
                <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
                  <mask id="m"><rect width="100" height="100" fill="white"/></mask>
                  <clipPath id="c"><text x="10" y="50">Hi</text></clipPath>
                  <rect width="100" height="100" fill="red" mask="url(#m)" clip-path="url(#c)"/>
                </svg>
                """
        )
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let masked = try #require(findLayer(in: layer) { $0.mask != nil })
        // the clip masks the mask's own contents
        let mask = try #require(masked.mask)
        let inner = try #require(findLayer(in: mask) { $0.mask != nil })
        let innerMask = try #require(inner.mask)
        #expect(!allContents(of: innerMask).isEmpty)
    }

    // MARK: - masks

    @Test
    func maskRegionDefaultsToBoundingBoxPlusTenPercent() throws {
        let c = try commands(
            """
            <mask id="m"><rect width="100" height="100" fill="white"/></mask>
            <rect x="10" y="20" width="50" height="40" mask="url(#m)"/>
            """
        )
        assertRect(clips(c).first?.bounds, 5, 16, 60, 48)
    }

    @Test
    func maskRegionObjectBoundingBox() throws {
        let c = try commands(
            """
            <mask id="m" x="0" y="0.5" width="50%" height="0.5"><rect width="100" height="100" fill="white"/></mask>
            <rect x="10" y="20" width="50" height="40" mask="url(#m)"/>
            """
        )
        assertRect(clips(c).first?.bounds, 10, 40, 25, 20)
    }

    @Test
    func maskRegionUserSpaceOnUse() throws {
        let c = try commands(
            """
            <mask id="m" maskUnits="userSpaceOnUse" x="5" y="10%" width="20" height="50%"><rect width="100" height="100" fill="white"/></mask>
            <rect x="10" y="20" width="50" height="40" mask="url(#m)"/>
            """
        )
        assertRect(clips(c).first?.bounds, 5, 10, 20, 50)
    }

    @Test
    func maskContentUnitsObjectBoundingBox() throws {
        let c = try commands(
            """
            <mask id="m" maskContentUnits="objectBoundingBox"><rect width="0.5" height="1" fill="white"/></mask>
            <rect x="10" y="20" width="50" height="40" fill="red" mask="url(#m)"/>
            """
        )
        // the content rect is scaled by the bounding box: (10,20,25,40)
        let scale = c.compactMap { cmd -> LayerTree.Transform? in
            if case let .concatenate(transform: t) = cmd { return t } else { return nil }
        }
        #expect(scale == [.matrix(.init(a: 50, b: 0, c: 0, d: 40, tx: 10, ty: 20))])
        // the mask is drawn before the element it masks (#162)
        #expect(fills(c).map(\.bounds.width) == [0.5, 50])
    }

    @Test
    func maskZeroRegionHidesElement() throws {
        let c = try commands(
            """
            <mask id="m" width="0"><rect width="100" height="100" fill="white"/></mask>
            <rect x="10" y="20" width="50" height="40" fill="red" mask="url(#m)"/>
            """
        )
        // the mask draws nothing, so nothing of the element survives
        let mask = try #require(maskContents(c))
        #expect(fills(mask).isEmpty)
        #expect(fills(c).count == 1)
    }

    @Test
    func maskContentUnitsObjectBoundingBoxOnEmptyBoxHidesElement() throws {
        let c = try commands(
            """
            <mask id="m" maskContentUnits="objectBoundingBox"><rect width="1" height="1" fill="white"/></mask>
            <line x1="0" y1="10" x2="100" y2="10" stroke="red" mask="url(#m)"/>
            """
        )
        // the mask draws nothing, so nothing of the element survives
        let mask = try #require(maskContents(c))
        #expect(fills(mask).isEmpty)
        #expect(transparencyLayers(c) > 0)
    }

    @Test
    func invalidMaskAttributesKeepDocument() throws {
        let c = try commands(
            """
            <mask id="m" maskUnits="bogus" maskContentUnits="bogus" x="abc" width=""><rect width="100" height="100" fill="white"/></mask>
            <rect x="10" y="20" width="50" height="40" mask="url(#m)"/>
            """
        )
        assertRect(clips(c).first?.bounds, 5, 16, 60, 48)
    }

    // MARK: - review round 1

    @Test
    func useOfTextInsideClipPathBecomesMask() throws {
        let svg = try DOM.SVG.parse(
            xml: """
                <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="100" height="100">
                  <defs><text id="t" x="10" y="50" fill="black">Hi</text></defs>
                  <clipPath id="c"><use xlink:href="#t" x="5"/></clipPath>
                  <rect width="100" height="100" fill="red" clip-path="url(#c)"/>
                </svg>
                """
        )
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let clipped = try #require(findLayer(in: layer) { $0.mask != nil })
        #expect(clipped.maskIsClip)
        let mask = try #require(clipped.mask)
        let texts = allContents(of: mask).compactMap { c -> LayerTree.TextAttributes? in
            if case let .text(_, _, att) = c { return att } else { return nil }
        }
        #expect(texts.map(\.color) == [.white])
        // the <use> offset reaches the text's layer
        #expect(findLayer(in: mask) { $0.transform == [.matrix(.init(a: 1, b: 0, c: 0, d: 1, tx: 5, ty: 0))] } != nil)
    }

    @Test
    func mutualClipCycleKeepsDocument() throws {
        let c = try commands(
            """
            <clipPath id="a" clip-path="url(#b)"><rect width="10" height="10"/></clipPath>
            <clipPath id="b" clip-path="url(#a)"><rect width="20" height="20"/></clipPath>
            <rect width="50" height="50" fill="red" clip-path="url(#a)"/>
            """
        )
        // a → b → (a dropped): b clips a, both are drawn as masks, before the element (#162)
        #expect(fills(c).map(\.bounds.width) == [20, 10, 50])
    }

    @Test
    func clipPathInsideMaskContents() throws {
        let c = try commands(
            """
            <clipPath id="c"><rect width="10" height="10"/></clipPath>
            <mask id="m" maskUnits="userSpaceOnUse" x="0" y="0" width="100" height="100">
              <rect width="100" height="100" fill="white" clip-path="url(#c)"/>
            </mask>
            <rect width="50" height="50" fill="red" mask="url(#m)"/>
            """
        )
        #expect(clips(c).map(\.bounds.width) == [100, 10])
    }

    @Test
    func manyElementsSharingOneClipAllRender() throws {
        // above what the old document-wide budget (20,000 references, three per element here) allowed
        let count = 7_000
        let rects = (0..<count).map { ##"<use xlink:href="#r" x="\##($0 % 100)" clip-path="url(#c)"/>"## }.joined()
        let c = try commands(
            """
            <defs><rect id="r" width="1" height="1"/></defs>
            <clipPath id="c" clipPathUnits="objectBoundingBox"><rect width="0.5" height="1"/></clipPath>
            \(rects)
            """
        )
        #expect(clips(c).count == count)
        #expect(fills(c).count == count)
    }

    #if canImport(CoreText)
    @Test
    func groupWithTextIsMeasuredWithItsGlyphCells() throws {
        let svg = try DOM.SVG.parse(
            xml: """
                <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
                  <clipPath id="c" clipPathUnits="objectBoundingBox"><rect width="0.5" height="1"/></clipPath>
                  <g id="clipped" clip-path="url(#c)"><rect width="10" height="10"/><text x="50" y="50">Hi</text></g>
                </svg>
                """
        )
        let builder = LayerTree.Builder(svg: svg)
        let group = svg.childElements[0]
        // text is measured with its cascaded font: without a state its box is unknown
        #expect(builder.makeBoundingBox(for: group) == nil)
        let bounds = try #require(
            builder.makeBoundingBox(for: group, state: builder.createState(for: group, inheriting: .init()))
        )
        #expect(bounds.x == 0 && bounds.y == 0)
        #expect(bounds.x + bounds.width > 60)
        #expect(bounds.y + bounds.height > 50)
        // the objectBoundingBox clip now applies
        #expect(findLayer(in: builder.makeLayer()) { !$0.clip.isEmpty } != nil)
    }
    #else
    @Test
    func groupWithTextHasUnknownBoundingBox() throws {
        // a bbox measured without the text would cut it away: the region and the bbox clip are skipped
        let svg = try DOM.SVG.parse(
            xml: """
                <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
                  <mask id="m"><rect width="100" height="100" fill="white"/></mask>
                  <clipPath id="c" clipPathUnits="objectBoundingBox"><rect width="0.5" height="1"/></clipPath>
                  <g id="masked" mask="url(#m)"><rect width="10" height="10"/><text x="50" y="50">Hi</text></g>
                  <g id="clipped" clip-path="url(#c)"><rect width="10" height="10"/><text x="50" y="50">Hi</text></g>
                </svg>
                """
        )
        let builder = LayerTree.Builder(svg: svg)
        #expect(builder.makeBoundingBox(for: svg.childElements[0]) == nil)
        let layer = builder.makeLayer()
        let masked = try #require(findLayer(in: layer) { $0.mask != nil })
        let mask = try #require(masked.mask)
        #expect(findLayer(in: mask) { !$0.clip.isEmpty } == nil)
        #expect(findLayer(in: layer) { !$0.clip.isEmpty } == nil)
    }
    #endif

    @Test
    func moveOnlyPathDoesNotCollapseGroupBoundingBox() throws {
        let c = try commands(
            """
            <clipPath id="c" clipPathUnits="objectBoundingBox"><rect width="0.5" height="1"/></clipPath>
            <g clip-path="url(#c)">
              <rect width="40" height="40"/>
              <path d="M 5 5" transform="scale(2)"/>
            </g>
            """
        )
        assertRect(clips(c).first?.bounds, 0, 0, 20, 40)
    }

    // MARK: - helpers

    @Test
    func boundingBoxOfUseFanOutStaysBounded() throws {
        // 4 uses per level over 12 levels is 4^12 walks: measuring gives up instead and the box is unknown
        var defs = ##"<g id="l12"><rect width="1" height="1"/></g>"##
        for level in stride(from: 11, through: 0, by: -1) {
            defs +=
                ##"<g id="l\##(level)">"## + String(repeating: ##"<use xlink:href="#l\##(level + 1)"/>"##, count: 4)
                + "</g>"
        }
        let svg = try DOM.SVG.parse(
            xml: """
                <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="100" height="100">
                <defs>\(defs)</defs><use id="u" xlink:href="#l0"/>
                </svg>
                """
        )
        let builder = LayerTree.Builder(svg: svg)
        let use = try #require(svg.firstGraphicsElement(with: "u"))
        #expect(builder.makeBoundingBox(for: use) == nil)
        #expect(builder.measurement.steps == LayerTree.Builder.MeasurementBudget.maxSteps)
    }

    @Test
    func clipPathChainFitsASmallSecondaryThreadStack() throws {
        // each nested clip-path costs native stack: the chain is cut at ReferenceGuard.maxDepth
        let chain = (0..<2_000).map {
            ##"<clipPath id="c\##($0)" clip-path="url(#c\##($0 + 1))"><rect width="90" height="90"/></clipPath>"##
        }.joined()
        nonisolated(unsafe) let svg = try DOM.SVG.parse(
            xml: """
                <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
                <defs>\(chain)</defs><rect width="50" height="50" clip-path="url(#c0)"/>
                </svg>
                """
        )
        nonisolated(unsafe) var result = [Command]()
        let done = DispatchSemaphore(value: 0)
        let thread = Thread {
            let layer = LayerTree.Builder(svg: svg).makeLayer()
            let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(), size: .zero, options: .default)
            result = generator.renderCommands(for: layer, colorConverter: .default)
            done.signal()
        }
        thread.stackSize = 512 * 1024
        thread.start()
        #expect(done.wait(timeout: .now() + 30) == .success)
        #expect(!fills(result).isEmpty)
    }

    private func findLayer(in layer: LayerTree.Layer, where predicate: (LayerTree.Layer) -> Bool) -> LayerTree.Layer? {
        if predicate(layer) { return layer }
        for case let .layer(child) in layer.contents {
            if let found = findLayer(in: child, where: predicate) { return found }
        }
        return nil
    }

    private func allContents(of layer: LayerTree.Layer) -> [LayerTree.Layer.Contents] {
        layer.contents.flatMap { c -> [LayerTree.Layer.Contents] in
            if case let .layer(child) = c { return allContents(of: child) }
            return [c]
        }
    }
}
