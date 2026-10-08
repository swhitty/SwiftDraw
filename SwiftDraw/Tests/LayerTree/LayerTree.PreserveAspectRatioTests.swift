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

import XCTest
@testable import SwiftDraw
@testable import SwiftDrawDOM
import Foundation

final class LayerTreePreserveAspectRatioTests: XCTestCase {

    private typealias PAR = DOM.PreserveAspectRatio

    // MARK: parsing

    private func parse(_ value: String?) -> PAR? {
        XMLParser().parsePreserveAspectRatio(value)
    }

    func testParsesAllAlignments() {
        let names = ["xMinYMin", "xMidYMin", "xMaxYMin", "xMinYMid", "xMidYMid", "xMaxYMid", "xMinYMax", "xMidYMax", "xMaxYMax"]
        let aligns: [PAR.Align] = [.xMinYMin, .xMidYMin, .xMaxYMin, .xMinYMid, .xMidYMid, .xMaxYMid, .xMinYMax, .xMidYMax, .xMaxYMax]
        for (name, align) in zip(names, aligns) {
            XCTAssertEqual(parse(name), PAR(align: align, meetOrSlice: .meet))
            XCTAssertEqual(parse("\(name) slice"), PAR(align: align, meetOrSlice: .slice))
            XCTAssertEqual(parse("  \(name)   meet "), PAR(align: align, meetOrSlice: .meet))
        }
        XCTAssertEqual(parse("none"), PAR(align: .none, meetOrSlice: .meet))
        XCTAssertEqual(parse("defer xMinYMax slice"), PAR(align: .xMinYMax, meetOrSlice: .slice))
    }

    func testInvalidValueIsIgnored() {
        XCTAssertNil(parse(nil))
        XCTAssertNil(parse(""))
        XCTAssertNil(parse("xMidYMid crop"))
        XCTAssertNil(parse("middle"))
        XCTAssertNil(parse("xMidYMid meet slice"))
        // the document still parses
        XCTAssertNoThrow(try DOM.SVG.parse(xml: #"<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10" viewBox="0 0 5 5" preserveAspectRatio="bogus"/>"#))
    }

    func testParsedOnSVGAndImage() throws {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10" viewBox="0 0 5 5" preserveAspectRatio="xMinYMax slice">
        <svg width="4" height="4" preserveAspectRatio="none"/>
        <image width="4" height="4" preserveAspectRatio="xMaxYMin" href="data:image/png;base64,iVBORw0KGgo="/>
        </svg>
        """)
        XCTAssertEqual(svg.preserveAspectRatio, PAR(align: .xMinYMax, meetOrSlice: .slice))
        XCTAssertEqual((svg.childElements[0] as? DOM.SVG)?.preserveAspectRatio, PAR(align: .none))
        XCTAssertEqual((svg.childElements[1] as? DOM.Image)?.preserveAspectRatio, PAR(align: .xMaxYMin))
    }

    // MARK: viewBox transform of the root

    private func transform(_ par: String?, viewBox: String = "0 0 100 50", width: Int = 200, height: Int = 200) throws -> [LayerTree.Transform] {
        let attribute = par.map { #"preserveAspectRatio="\#($0)""# } ?? ""
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="\(width)" height="\(height)" viewBox="\(viewBox)" \(attribute)/>
        """)
        return LayerTree.Builder(svg: svg).makeLayer().transform
    }

    func testDefaultIsMeetMidMid() throws {
        // 100x50 into 200x200: scale 2, centred vertically ((200 - 100) / 2)
        XCTAssertEqual(try transform(nil), [.translate(tx: 0, ty: 50), .scale(sx: 2, sy: 2)])
    }

    func testNoneStretches() throws {
        XCTAssertEqual(try transform("none"), [.scale(sx: 2, sy: 4)])
    }

    func testMeetAlignments() throws {
        XCTAssertEqual(try transform("xMinYMin"), [.scale(sx: 2, sy: 2)])
        XCTAssertEqual(try transform("xMaxYMax meet"), [.translate(tx: 0, ty: 100), .scale(sx: 2, sy: 2)])
        XCTAssertEqual(try transform("xMidYMid", viewBox: "0 0 50 100"), [.translate(tx: 50, ty: 0), .scale(sx: 2, sy: 2)])
        XCTAssertEqual(try transform("xMaxYMin", viewBox: "0 0 50 100"), [.translate(tx: 100, ty: 0), .scale(sx: 2, sy: 2)])
    }

    func testSliceFillsViewport() throws {
        // 100x50 into 200x200: scale 4 (covers), 400 wide, overflow of 200 shared by the alignment
        XCTAssertEqual(try transform("xMinYMin slice"), [.scale(sx: 4, sy: 4)])
        XCTAssertEqual(try transform("xMidYMid slice"), [.translate(tx: -100, ty: 0), .scale(sx: 4, sy: 4)])
        XCTAssertEqual(try transform("xMaxYMax slice"), [.translate(tx: -200, ty: 0), .scale(sx: 4, sy: 4)])
    }

    func testViewBoxOriginIsKept() throws {
        XCTAssertEqual(try transform("xMinYMin", viewBox: "10 20 100 50"),
                       [.scale(sx: 2, sy: 2), .translate(tx: -10, ty: -20)])
    }

    func testMatchingAspectIsUnchanged() throws {
        XCTAssertEqual(try transform(nil, viewBox: "0 0 100 100"), [.scale(sx: 2, sy: 2)])
        XCTAssertEqual(try transform("xMaxYMax slice", viewBox: "0 0 100 100"), [.scale(sx: 2, sy: 2)])
    }

    func testEmptyViewBoxFallsBackToViewport() throws {
        XCTAssertEqual(try transform(nil, viewBox: "0 0 0 10"), [])
    }

    // MARK: nested svg

    func testNestedSVGTransformAndClip() throws {
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
        XCTAssertEqual(layers.count, 2)

        // slice: scale 4 so the 10x10 box covers 40x20; the viewport is the top 5 units of it
        XCTAssertEqual(layers[0].transform, [.translate(tx: 10, ty: 20), .scale(sx: 4, sy: 4)])
        XCTAssertEqual(layers[0].clip.first?.shape, .rect(within: .init(x: 0, y: 0, width: 10, height: 5), radii: .zero))

        // meet (default): scale 2, centred horizontally; the viewport is wider than the viewBox
        XCTAssertEqual(layers[1].transform, [.translate(tx: 10, ty: 0), .scale(sx: 2, sy: 2)])
        XCTAssertEqual(layers[1].clip.first?.shape, .rect(within: .init(x: -5, y: 0, width: 20, height: 10), radii: .zero))
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

    func testImageMeetCentresInFrame() {
        let p = placement(PAR())
        XCTAssertEqual(p.dest, .init(x: 35, y: 20, width: 50, height: 100))
        XCTAssertNil(p.clip)
        XCTAssertEqual(placement(PAR(align: .xMinYMid)).dest, .init(x: 10, y: 20, width: 50, height: 100))
        XCTAssertEqual(placement(PAR(align: .xMaxYMid)).dest, .init(x: 60, y: 20, width: 50, height: 100))
    }

    func testImageSliceCoversAndClipsToFrame() {
        let p = placement(PAR(align: .xMidYMid, meetOrSlice: .slice))
        XCTAssertEqual(p.dest, .init(x: 10, y: -30, width: 100, height: 200))
        XCTAssertEqual(p.clip, .init(x: 10, y: 20, width: 100, height: 100))
        XCTAssertEqual(placement(PAR(align: .xMinYMin, meetOrSlice: .slice)).dest, .init(x: 10, y: 20, width: 100, height: 200))
        XCTAssertEqual(placement(PAR(align: .xMaxYMax, meetOrSlice: .slice)).dest, .init(x: 10, y: -80, width: 100, height: 200))
    }

    func testImageNoneStretches() {
        let p = placement(PAR(align: .none))
        XCTAssertEqual(p.dest, .init(x: 10, y: 20, width: 100, height: 100))
        XCTAssertNil(p.clip)
    }

    func testImageWithOneDimensionKeepsItsAspectRatio() {
        XCTAssertEqual(placement(PAR(), width: 100, height: nil).dest, .init(x: 10, y: 20, width: 100, height: 200))
        XCTAssertEqual(placement(PAR(), width: nil, height: nil).dest, .init(x: 10, y: 20, width: 50, height: 100))
    }

    func testImageWithPreserveAspectRatioStillDraws() throws {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
        <image width="100" height="50" preserveAspectRatio="xMidYMid slice" href="data:image/png;base64,iVBORw0KGgo="/>
        </svg>
        """)
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(), size: .zero, options: .default)
        let commands = generator.renderCommands(for: layer, colorConverter: .default)
        // LayerTreeProvider reports the frame as the bitmap size, so the fit is the identity here
        XCTAssertTrue(commands.contains { if case .draw = $0 { return true }; return false })
    }

    // MARK: ViewBoxFit

    func testFitIsUniformUnlessNone() {
        let meet = PAR().fit(contentWidth: 10, contentHeight: 20, viewportWidth: 100, viewportHeight: 100)
        XCTAssertEqual(meet.sx, 5)
        XCTAssertEqual(meet.sy, 5)
        let none = PAR(align: .none).fit(contentWidth: 10, contentHeight: 20, viewportWidth: 100, viewportHeight: 100)
        XCTAssertEqual(none.sx, 10)
        XCTAssertEqual(none.sy, 5)
    }
}
