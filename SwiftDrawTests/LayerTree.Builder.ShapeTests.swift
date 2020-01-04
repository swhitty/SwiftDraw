//
//  LayerTree.Builder.ShapeTests.swift
//  SwiftDraw
//
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
//

import XCTest
@testable import SwiftDraw

final class LayerTreeBuilderShapeTests: XCTestCase {

    func testDOMRectMakesRectWithDefaultOrigin() {
        let dom = DOM.Rect(width: 10, height: 20)
        let rect = LayerTree.Builder.makeRect(from: dom)
        XCTAssertEqual(rect, LayerTree.Rect(x: 0, y: 0, width: 10, height: 20))
    }

    func testDOMRectMakesRect() {
        let dom = DOM.Rect(x: 10, y: 20, width: 30, height: 40)
        let rect = LayerTree.Builder.makeRect(from: dom)
        XCTAssertEqual(rect, LayerTree.Rect(x: 10, y: 20, width: 30, height: 40))
    }
}
