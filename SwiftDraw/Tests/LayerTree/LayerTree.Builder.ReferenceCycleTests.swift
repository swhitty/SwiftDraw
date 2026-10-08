//
//  LayerTree.Builder.ReferenceCycleTests.swift
//  SwiftDraw
//  Created by Simon Whitty on 21/11/18.
//  Copyright 2020 WhileLoop Pty Ltd. All rights reserved.
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

import SwiftDrawDOM
import XCTest
@testable import SwiftDraw

final class LayerTreeBuilderReferenceCycleTests: XCTestCase {

    private func makeLayer(_ body: String) throws -> LayerTree.Layer {
        let svg = try DOM.SVG.parse("""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
        \(body)
        </svg>
        """)
        return LayerTree.Builder(svg: svg).makeLayer()
    }

    func testUseReferencingItsOwnParentDoesNotRecurse() throws {
        _ = try makeLayer(#"<g id="a"><use xlink:href="#a"/></g><use xlink:href="#a"/>"#)
    }

    func testUseSelfReferenceDoesNotRecurse() throws {
        _ = try makeLayer(#"<use id="a" xlink:href="#a"/>"#)
    }

    func testMutualUseCycleDoesNotRecurse() throws {
        _ = try makeLayer(#"""
        <g id="a"><use xlink:href="#b"/></g>
        <g id="b"><use xlink:href="#a"/></g>
        <use xlink:href="#a"/>
        """#)
    }

    func testValidSiblingUsesStillDrawn() throws {
        let layer = try makeLayer(#"""
        <defs><rect id="r" width="10" height="10"/></defs>
        <use xlink:href="#r"/><use xlink:href="#r"/>
        """#)
        XCTAssertEqual(layer.contents.count, 2)
    }

    func testMaskReferencingItselfDoesNotRecurse() throws {
        _ = try makeLayer(#"""
        <mask id="m"><rect width="10" height="10" mask="url(#m)"/></mask>
        <rect width="10" height="10" mask="url(#m)"/>
        """#)
    }

    func testPatternPaintedWithItselfDoesNotRecurse() throws {
        _ = try makeLayer(#"""
        <pattern id="p" width="10" height="10" patternUnits="userSpaceOnUse">
          <rect width="5" height="5" fill="url(#p)"/>
        </pattern>
        <rect width="10" height="10" fill="url(#p)"/>
        """#)
    }

    func testGradientHrefCycleDoesNotRecurse() throws {
        _ = try makeLayer(#"""
        <linearGradient id="a" xlink:href="#b"/>
        <linearGradient id="b" xlink:href="#a"/>
        <rect width="10" height="10" fill="url(#a)"/>
        """#)
    }
}
