//
//  LayerTree.Builder.LayerTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 21/11/18.
//  Copyright © 2018 WhileLoop Pty Ltd. All rights reserved.
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

final class LayerTreeBuilderLayerTests: XCTestCase {

    func testMakeLayerFromUse() {
        let circle = DOM.Circle(cx: 5, cy: 5, r: 5)
        let svg = DOM.SVG(width: 10, height: 10)
        svg.defs.elements["circle"] = circle
        let builder = LayerTree.Builder(svg: svg)

        let use = DOM.Use(href: URL(string: "#circle")!)
        let contents = builder.makeUseLayerContents(from: use, with: .init())!

        guard case .layer(let l) = contents else { XCTFail(); return }
        XCTAssertEqual(l.contents.count, 1)
    }
}
