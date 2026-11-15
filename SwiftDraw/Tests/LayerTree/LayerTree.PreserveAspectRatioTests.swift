//
//  LayerTree.PreserveAspectRatioTests.swift
//  SwiftDraw
//
//  Copyright 2020 Simon Whitty
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
@testable import SwiftDrawDOM
import Foundation
import Testing

struct LayerTreePreserveAspectRatioTests {

    private typealias PAR = DOM.PreserveAspectRatio

    // MARK: parsing

    private func parse(_ value: String?) -> PAR? {
        XMLParser().parsePreserveAspectRatio(value)
    }

    private static let alignNames = ["xMinYMin", "xMidYMin", "xMaxYMin", "xMinYMid", "xMidYMid", "xMaxYMid", "xMinYMax", "xMidYMax", "xMaxYMax"]
    private static let aligns: [DOM.PreserveAspectRatio.Align] = [.xMinYMin, .xMidYMin, .xMaxYMin, .xMinYMid, .xMidYMid, .xMaxYMid, .xMinYMax, .xMidYMax, .xMaxYMax]

    @Test(arguments: zip(alignNames, aligns))
    func parsesAlignment(name: String, align: DOM.PreserveAspectRatio.Align) {
        #expect(parse(name) == PAR(align: align, meetOrSlice: .meet))
        #expect(parse("\(name) slice") == PAR(align: align, meetOrSlice: .slice))
        #expect(parse("  \(name)   meet ") == PAR(align: align, meetOrSlice: .meet))
    }

    @Test
    func parsesNoneAndDefer() {
        #expect(parse("none") == PAR(align: .none, meetOrSlice: .meet))
        #expect(parse("defer xMinYMax slice") == PAR(align: .xMinYMax, meetOrSlice: .slice))
    }

    @Test
    func invalidValueIsIgnored() {
        #expect(parse(nil) == nil)
        #expect(parse("") == nil)
        #expect(parse("xMidYMid crop") == nil)
        #expect(parse("middle") == nil)
        #expect(parse("xMidYMid meet slice") == nil)
        // the document still parses
        #expect(throws: Never.self) {
            try DOM.SVG.parse(xml: #"<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10" viewBox="0 0 5 5" preserveAspectRatio="bogus"/>"#)
        }
    }

    @Test
    func parsedOnSVGAndImage() throws {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10" viewBox="0 0 5 5" preserveAspectRatio="xMinYMax slice">
        <svg width="4" height="4" preserveAspectRatio="none"/>
        <image width="4" height="4" preserveAspectRatio="xMaxYMin" href="data:image/png;base64,iVBORw0KGgo="/>
        </svg>
        """)
        #expect(svg.preserveAspectRatio == PAR(align: .xMinYMax, meetOrSlice: .slice))
        #expect((svg.childElements[0] as? DOM.SVG)?.preserveAspectRatio == PAR(align: .none))
        #expect((svg.childElements[1] as? DOM.Image)?.preserveAspectRatio == PAR(align: .xMaxYMin))
    }

    // MARK: viewBox transform of the root

    private func transform(_ par: String?, viewBox: String = "0 0 100 50", width: Int = 200, height: Int = 200) throws -> [LayerTree.Transform] {
        let attribute = par.map { #"preserveAspectRatio="\#($0)""# } ?? ""
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="\(width)" height="\(height)" viewBox="\(viewBox)" \(attribute)/>
        """)
        return LayerTree.Builder(svg: svg).makeLayer().transform
    }

    @Test
    func defaultIsMeetMidMid() throws {
        // 100x50 into 200x200: scale 2, centred vertically ((200 - 100) / 2)
        #expect(try transform(nil) == [.translate(tx: 0, ty: 50), .scale(sx: 2, sy: 2)])
    }

    @Test
    func noneStretches() throws {
        #expect(try transform("none") == [.scale(sx: 2, sy: 4)])
    }

    @Test
    func meetAlignments() throws {
        #expect(try transform("xMinYMin") == [.scale(sx: 2, sy: 2)])
        #expect(try transform("xMaxYMax meet") == [.translate(tx: 0, ty: 100), .scale(sx: 2, sy: 2)])
        #expect(try transform("xMidYMid", viewBox: "0 0 50 100") == [.translate(tx: 50, ty: 0), .scale(sx: 2, sy: 2)])
        #expect(try transform("xMaxYMin", viewBox: "0 0 50 100") == [.translate(tx: 100, ty: 0), .scale(sx: 2, sy: 2)])
    }

    @Test
    func sliceFillsViewport() throws {
        // 100x50 into 200x200: scale 4 (covers), 400 wide, overflow of 200 shared by the alignment
        #expect(try transform("xMinYMin slice") == [.scale(sx: 4, sy: 4)])
        #expect(try transform("xMidYMid slice") == [.translate(tx: -100, ty: 0), .scale(sx: 4, sy: 4)])
        #expect(try transform("xMaxYMax slice") == [.translate(tx: -200, ty: 0), .scale(sx: 4, sy: 4)])
    }

    @Test
    func viewBoxOriginIsKept() throws {
        #expect(try transform("xMinYMin", viewBox: "10 20 100 50") == [.scale(sx: 2, sy: 2), .translate(tx: -10, ty: -20)])
    }

    @Test
    func matchingAspectIsUnchanged() throws {
        #expect(try transform(nil, viewBox: "0 0 100 100") == [.scale(sx: 2, sy: 2)])
        #expect(try transform("xMaxYMax slice", viewBox: "0 0 100 100") == [.scale(sx: 2, sy: 2)])
    }

    @Test
    func emptyViewBoxFallsBackToViewport() throws {
        #expect(try transform(nil, viewBox: "0 0 0 10") == [])
    }

    // MARK: nested svg

    @Test
    func nestedSVGTransformAndClip() throws {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
        <svg x="10" y="20" width="40" height="20" viewBox="0 0 10 10" preserveAspectRatio="xMinYMin slice"><rect width="10" height="10"/></svg>
        <svg x="0" y="0" width="40" height="20" viewBox="0 0 10 10"><rect width="10" height="10"/></svg>
        </svg>
        """)
        let root = LayerTree.Builder(svg: svg).makeLayer()
        let layers: [LayerTree.Layer] = root.contents.compactMap {
            if case .layer(let l) = $0 { return l }
            return nil
        }
        try #require(layers.count == 2)

        // slice: scale 4 so the 10x10 box covers 40x20; the viewport is the top 5 units of it
        #expect(layers[0].transform == [.translate(tx: 10, ty: 20), .scale(sx: 4, sy: 4)])
        #expect(layers[0].clip.first?.shape == .rect(within: .init(x: 0, y: 0, width: 10, height: 5), radii: .zero))

        // meet (default): scale 2, centred horizontally; the viewport is wider than the viewBox
        #expect(layers[1].transform == [.translate(tx: 10, ty: 0), .scale(sx: 2, sy: 2)])
        #expect(layers[1].clip.first?.shape == .rect(within: .init(x: -5, y: 0, width: 20, height: 10), radii: .zero))
    }

    // MARK: image

    private func placement(_ par: PAR, width: Float? = 100, height: Float? = 100, bitmap: LayerTree.Size = .init(50, 100)) -> (dest: LayerTree.Rect, clip: LayerTree.Rect?) {
        var image = LayerTree.Image(bitmap: .png(Data([1])))
        image.origin = .init(10, 20)
        image.width = width
        image.height = height
        image.preserveAspectRatio = par
        let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(), size: .zero, options: .default)
        return generator.makeImagePlacement(for: image, bitmapSize: bitmap)
    }

    @Test
    func imageMeetCentresInFrame() {
        let p = placement(PAR())
        #expect(p.dest == .init(x: 35, y: 20, width: 50, height: 100))
        #expect(p.clip == nil)
        #expect(placement(PAR(align: .xMinYMid)).dest == .init(x: 10, y: 20, width: 50, height: 100))
        #expect(placement(PAR(align: .xMaxYMid)).dest == .init(x: 60, y: 20, width: 50, height: 100))
    }

    @Test
    func imageSliceCoversAndClipsToFrame() {
        let p = placement(PAR(align: .xMidYMid, meetOrSlice: .slice))
        #expect(p.dest == .init(x: 10, y: -30, width: 100, height: 200))
        #expect(p.clip == .init(x: 10, y: 20, width: 100, height: 100))
        #expect(placement(PAR(align: .xMinYMin, meetOrSlice: .slice)).dest == .init(x: 10, y: 20, width: 100, height: 200))
        #expect(placement(PAR(align: .xMaxYMax, meetOrSlice: .slice)).dest == .init(x: 10, y: -80, width: 100, height: 200))
    }

    @Test
    func imageNoneStretches() {
        let p = placement(PAR(align: .none))
        #expect(p.dest == .init(x: 10, y: 20, width: 100, height: 100))
        #expect(p.clip == nil)
    }

    @Test
    func imageWithOneDimensionKeepsItsAspectRatio() {
        #expect(placement(PAR(), width: 100, height: nil).dest == .init(x: 10, y: 20, width: 100, height: 200))
        #expect(placement(PAR(), width: nil, height: nil).dest == .init(x: 10, y: 20, width: 50, height: 100))
    }

    @Test
    func imageWithPreserveAspectRatioStillDraws() throws {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
        <image width="100" height="50" preserveAspectRatio="xMidYMid slice" href="data:image/png;base64,iVBORw0KGgo="/>
        </svg>
        """)
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(), size: .zero, options: .default)
        let commands = generator.renderCommands(for: layer, colorConverter: .default)
        // LayerTreeProvider reports the frame as the bitmap size, so the fit is the identity here
        #expect(commands.contains { if case .draw = $0 { return true }; return false })
    }

    // MARK: ViewBoxFit

    @Test
    func fitIsUniformUnlessNone() {
        let meet = PAR().fit(contentWidth: 10, contentHeight: 20, viewportWidth: 100, viewportHeight: 100)
        #expect(meet.sx == 5)
        #expect(meet.sy == 5)
        let none = PAR(align: .none).fit(contentWidth: 10, contentHeight: 20, viewportWidth: 100, viewportHeight: 100)
        #expect(none.sx == 10)
        #expect(none.sy == 5)
    }

    // MARK: table over alignments

    @Test(arguments: alignNames, ["meet", "slice"])
    func everyAlignmentAndModeOnBothAxes(name: String, mode: String) throws {
        let fractions: [String: (x: Float, y: Float)] = [
            "xMinYMin": (0, 0), "xMidYMin": (0.5, 0), "xMaxYMin": (1, 0),
            "xMinYMid": (0, 0.5), "xMidYMid": (0.5, 0.5), "xMaxYMid": (1, 0.5),
            "xMinYMax": (0, 1), "xMidYMax": (0.5, 1), "xMaxYMax": (1, 1)
        ]
        let f = try #require(fractions[name])
        let par = try #require(parse("\(name) \(mode)"))
        // content 40x10 and 10x40 into 100x100: the wide one is limited by x, the tall one by y
        for (content, size) in [("wide", (w: Float(40), h: Float(10))), ("tall", (w: Float(10), h: Float(40)))] {
            let fit = par.fit(contentWidth: size.w, contentHeight: size.h, viewportWidth: 100, viewportHeight: 100)
            // meet is limited by the long side (100 / 40), slice by the short side (100 / 10)
            let expected: Float = mode == "meet" ? 2.5 : 10
            #expect(fit.sx == expected, "\(content)")
            #expect(fit.sy == expected, "\(content)")
            #expect(abs(fit.tx - (100 - size.w * expected) * f.x) < 1e-4, "\(content)")
            #expect(abs(fit.ty - (100 - size.h * expected) * f.y) < 1e-4, "\(content)")
        }
    }

    @Test
    func noneSliceStillStretches() throws {
        let par = try #require(parse("none slice"))
        #expect(par.align == .none)
        let fit = par.fit(contentWidth: 10, contentHeight: 20, viewportWidth: 100, viewportHeight: 100)
        #expect(fit.sx == 10)
        #expect(fit.sy == 5)
        #expect(fit.tx == 0)
        #expect(fit.ty == 0)
    }

    @Test
    func bareDeferAndWhitespaceVariants() {
        #expect(parse("defer") == nil)
        #expect(parse("\t xMaxYMin\n\r slice ") == PAR(align: .xMaxYMin, meetOrSlice: .slice))
        #expect(parse("defer\txMinYMax") == PAR(align: .xMinYMax, meetOrSlice: .meet))
    }

    // MARK: degenerate sizes

    private func isFinite(_ rect: LayerTree.Rect) -> Bool {
        [rect.x, rect.y, rect.width, rect.height].allSatisfy(\.isFinite)
    }

    @Test(arguments: [(0, 100), (100, 0), (-10, 100), (100, -10), (0, 0)])
    func degenerateViewportsFallBackToIdentity(width: Int, height: Int) {
        let box = DOM.SVG.ViewBox(x: 0, y: 0, width: 100, height: 50)
        let fit = LayerTree.Builder.makeViewBoxFit(viewBox: box, width: width, height: height, preserveAspectRatio: nil)
        #expect([fit.sx, fit.sy, fit.tx, fit.ty] == [1, 1, 0, 0])
        let clip = LayerTree.Builder.makeViewportClip(viewBox: box, width: width, height: height, preserveAspectRatio: nil)
        #expect(isFinite(clip))
    }

    @Test(arguments: [
        (Float(0), Float(0), Float.infinity, Float(10)),
        (Float.infinity, Float(0), Float(10), Float(10)),
        (Float(0), Float(0), Float.nan, Float(10)),
        // tiny box: the scale overflows to infinity
        (Float(0), Float(0), Float.leastNonzeroMagnitude, Float(10))
    ])
    func nonFiniteViewBoxFallsBackToViewport(x: Float, y: Float, width: Float, height: Float) {
        let box = DOM.SVG.ViewBox(x: x, y: y, width: width, height: height)
        let fit = LayerTree.Builder.makeViewBoxFit(viewBox: box, width: 100, height: 100, preserveAspectRatio: nil)
        let isFiniteFit = [fit.sx, fit.sy, fit.tx, fit.ty].allSatisfy(\.isFinite)
        #expect(isFiniteFit)
        #expect(fit.sx > 0)
        let clip = LayerTree.Builder.makeViewportClip(viewBox: box, width: 100, height: 100, preserveAspectRatio: nil)
        #expect(isFinite(clip))
    }

    // MARK: root slice

    @Test
    func rootSliceGetsAClipInViewBoxSpace() throws {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="200" height="100" viewBox="0 0 100 100" preserveAspectRatio="xMinYMin slice"/>
        """)
        let root = LayerTree.Builder(svg: svg).makeLayer()
        #expect(root.transform == [.scale(sx: 2, sy: 2)])
        #expect(root.clip.first?.shape == .rect(within: .init(x: 0, y: 0, width: 100, height: 50), radii: .zero))
    }

    @Test(arguments: ["xMidYMid meet", "none", "xMinYMin meet"])
    func rootMeetAndNoneAreNotClipped(par: String) throws {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="200" height="100" viewBox="0 0 100 100" preserveAspectRatio="\(par)"/>
        """)
        #expect(LayerTree.Builder(svg: svg).makeLayer().clip.isEmpty)
    }

    // MARK: nested svg with a viewBox origin

    @Test
    func nestedSVGWithViewBoxOrigin() throws {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
        <svg x="10" y="20" width="40" height="20" viewBox="5 5 10 10" preserveAspectRatio="xMidYMid meet"><rect width="10" height="10"/></svg>
        </svg>
        """)
        let root = LayerTree.Builder(svg: svg).makeLayer()
        guard case .layer(let nested)? = root.contents.first else {
            Issue.record("no nested layer")
            return
        }
        // scale 2, centred horizontally: (40 - 20) / 2 = 10
        #expect(nested.transform == [.translate(tx: 20, ty: 20), .scale(sx: 2, sy: 2), .translate(tx: -5, ty: -5)])
        // the viewport in viewBox space: x from 5 - 10 / 2 = 0, 20 wide, 10 tall
        #expect(nested.clip.first?.shape == .rect(within: .init(x: 0, y: 5, width: 20, height: 10), radii: .zero))
    }

    // MARK: image epsilon

    @Test
    func imageMeetAndEqualAspectDoNotClip() {
        #expect(placement(PAR(), bitmap: .init(100, 100)).clip == nil)
        #expect(placement(PAR(align: .xMinYMin, meetOrSlice: .slice), bitmap: .init(100, 100)).clip == nil)
        // a bitmap whose ratio matches up to rounding noise
        #expect(placement(PAR(align: .xMidYMid, meetOrSlice: .slice), bitmap: .init(333.3333, 333.33334)).clip == nil)
        #expect(placement(PAR(align: .xMidYMid, meetOrSlice: .slice), bitmap: .init(50, 100)).clip != nil)
    }

    // MARK: pattern

    @Test
    func patternViewBoxHonoursPreserveAspectRatio() throws {
        typealias Generator = LayerTree.CommandGenerator<LayerTreeProvider>
        func content(_ par: PAR) throws -> LayerTree.Transform.Matrix {
            let pattern = LayerTree.Pattern(frame: .init(x: 5, y: 0, width: 40, height: 20))
            pattern.viewBox = .init(x: 10, y: 10, width: 10, height: 10)
            pattern.preserveAspectRatio = par
            return try #require(Generator.resolvePattern(pattern, in: .init(x: 0, y: 0, width: 100, height: 100))).1
        }
        // meet: scale 2, free space 20 in x
        #expect(try content(PAR(align: .xMinYMin)) == .init(a: 2, b: 0, c: 0, d: 2, tx: 5 - 20, ty: -20))
        #expect(try content(PAR(align: .xMaxYMax)) == .init(a: 2, b: 0, c: 0, d: 2, tx: 5 + 20 - 20, ty: -20))
        // slice: scale 4, 20 of overflow in y
        #expect(try content(PAR(align: .xMinYMid, meetOrSlice: .slice)) == .init(a: 4, b: 0, c: 0, d: 4, tx: 5 - 40, ty: -10 - 40))
        // none: stretched
        #expect(try content(PAR(align: .none)) == .init(a: 4, b: 0, c: 0, d: 2, tx: 5 - 40, ty: -20))
    }

    @Test
    func patternFitOverflowIsDropped() {
        typealias Generator = LayerTree.CommandGenerator<LayerTreeProvider>
        let pattern = LayerTree.Pattern(frame: .init(x: 0, y: 0, width: 1e30, height: 1e30))
        pattern.viewBox = .init(x: 0, y: 0, width: 1e-30, height: 1e-30)
        #expect(Generator.resolvePattern(pattern, in: .init(x: 0, y: 0, width: 100, height: 100)) == nil)
    }

    @Test
    func rootClipPathIntersectsTheSliceViewport() throws {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="200" height="100" viewBox="0 0 100 100" preserveAspectRatio="xMidYMid slice" clip-path="url(#c)">
        <clipPath id="c"><rect width="50" height="50"/></clipPath>
        <rect width="100" height="100"/></svg>
        """)
        let root = LayerTree.Builder(svg: svg).makeLayer()
        // the viewport clips the outer layer, the root's own clip-path stays on the inner one
        #expect(!root.clip.isEmpty)
        guard case .layer(let inner)? = root.contents.first else {
            Issue.record("no inner layer")
            return
        }
        #expect(!inner.clip.isEmpty)
        #expect(root.clip != inner.clip)
        #expect(inner.transform.isEmpty)
        #expect(!root.transform.isEmpty)
    }

    @Test
    func patternParsesAndInheritsPreserveAspectRatio() throws {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="100" height="100">
        <defs>
        <pattern id="a" width="40" height="20" patternUnits="userSpaceOnUse" viewBox="0 0 10 10" preserveAspectRatio="xMaxYMax slice"><rect width="10" height="10"/></pattern>
        <pattern id="b" xlink:href="#a"/>
        </defs>
        <rect width="100" height="100" fill="url(#b)"/></svg>
        """)
        #expect(svg.defs.patterns.first?.preserveAspectRatio == PAR(align: .xMaxYMax, meetOrSlice: .slice))
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(), size: .zero, options: .default)
        _ = generator.renderCommands(for: layer, colorConverter: .default)
        // "b" has no preserveAspectRatio of its own: it inherits "a" (the resolved pattern only keeps the fit)
        #expect(svg.defs.patterns.last?.preserveAspectRatio == nil)
        let b = try #require(svg.defs.patterns.last)
        let pattern = LayerTree.Builder(svg: svg).makePattern(for: b)
        #expect(pattern.preserveAspectRatio == PAR(align: .xMaxYMax, meetOrSlice: .slice))
    }
}
