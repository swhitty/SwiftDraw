//
//  NSImage+ImageTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 27/11/18.
//  Copyright 2018 Simon Whitty
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

final class NSImageTests: XCTestCase {

    func testImageLoads() {
        let image = NSImage(svgNamed: "lines.svg", in: .test)
        XCTAssertNotNil(image)
    }

    func testMissingImageDoesNotLoad() {
        let image = NSImage(svgNamed: "missing.svg", in: .test)
        XCTAssertNil(image)
    }

    func testNSImageDraws() {
        let canvas = NSImage(size: CGSize(width: 100, height: 100))

        canvas.lockFocus()
        NSImage(svgNamed: "lines.svg", in: .test)?.draw(in: NSRect(x: 0, y: 0, width: 100, height: 100))
        canvas.unlockFocus()
    }

    func testImageDraws() {
        let canvas = NSImage(size: CGSize(width: 100, height: 100))

        let lines = Image.makeLines().rasterize(with: CGSize(width: 100, height: 100))
        canvas.lockFocus()
        lines.draw(in: NSRect(x: 0, y: 0, width: 100, height: 100))
        canvas.unlockFocus()
    }
}

private extension Image {

    static func makeLines() -> Image {
        let svg = DOM.SVG(width: 100, height: 100)
        svg.childElements.append(DOM.Line(x1: 0, y1: 0, x2: 100, y2: 100))
        svg.childElements.append(DOM.Line(x1: 100, y1: 0, x2: 0, y2: 100))
        return Image(svg: svg)
    }
}
