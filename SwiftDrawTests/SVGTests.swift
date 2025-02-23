//
//  SVGTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 19/11/18.
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

#if canImport(CoreGraphics)
final class SVGTests: XCTestCase {

    func testValidSVGLoads() {
        XCTAssertNotNil(SVG(named: "lines.svg", in: .test))
    }

    func testInvalidSVGReturnsNil() {
        XCTAssertNil(SVG(named: "invalids.svg", in: .test))
    }

    func testMissingSVGReturnsNil() {
        XCTAssertNil(SVG(named: "missing.svg", in: .test))
    }

    func testImageRasterizes() {
        let image = SVG.makeLines()
        let rendered = image.rasterize(scale: 1)
        XCTAssertEqual(rendered.size, image.size)
        XCTAssertNoThrow(try image.pngData())
        XCTAssertNoThrow(try image.jpegData())
        XCTAssertNoThrow(try image.pdfData())
    }

    func testImageRasterizeAndScales() {
        let image = SVG.makeLines()
        let doubleSize = CGSize(width: 200, height: 200)
        let rendered = image.rasterize(with: doubleSize, scale: 1)
        XCTAssertEqual(rendered.size, doubleSize)
        XCTAssertNoThrow(try image.pngData(size: doubleSize))
        XCTAssertNoThrow(try image.jpegData(size: doubleSize))
    }

    func testShapesImageRasterizes() throws {
        let image = try XCTUnwrap(SVG(named: "shapes.svg", in: .test))
        XCTAssertNoThrow(try image.pngData())
        XCTAssertNoThrow(try image.jpegData())
        XCTAssertNoThrow(try image.pdfData())
    }

#if canImport(UIKit)
    func testRasterize() {
        let svg = SVG(named: "gradient-apple.svg", in: .test)!
        let image = svg.rasterize(with: CGSize(width: 100, height: 100), scale: 3)
        XCTAssertEqual(image.size, CGSize(width: 100, height: 100))
        XCTAssertEqual(image.scale, 3)

        let data = image.pngData()!
        let reloaded = UIImage(data: data)!
        XCTAssertEqual(reloaded.size, CGSize(width: 300, height: 300))
        XCTAssertEqual(reloaded.scale, 1)
    }
#endif

    func testScale() {
        let image = SVG.makeLines()

        XCTAssertEqual(image.size, CGSize(width: 100, height: 100))
        XCTAssertEqual(image.scale(2).size, CGSize(width: 200, height: 200))
        XCTAssertEqual(image.scale(0.5).size, CGSize(width: 50, height: 50))
        XCTAssertEqual(image.scale(x: 2, y: 3).size, CGSize(width: 200, height: 300))

        var copy = image
        copy.scaled(5)
        XCTAssertEqual(copy.size, CGSize(width: 500, height: 500))
    }
}

private extension SVG {

    static func makeLines() -> SVG {
        let svg = DOM.SVG(width: 100, height: 100)
        svg.childElements.append(DOM.Line(x1: 0, y1: 0, x2: 100, y2: 100))
        svg.childElements.append(DOM.Line(x1: 100, y1: 0, x2: 0, y2: 100))
        return SVG(dom: svg, options: .default)
    }
}
#endif
