//
//  Renderer.SVGTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 7/03/22.
//  Copyright 2022 Simon Whitty
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

final class SVGRendererTests: XCTestCase {

    func testPathExpands_WithTranslate() throws {
        let path = try SVGRenderer.makeExpanded(
            path: "M0,50 L 50,50 C 100,0 150,0 200,50",
            transform: "translate(10, 10)",
            precision: 0
        )

        XCTAssertEqual(
            path,
            "M10,60 L60,60 C110,10 160,10 210,60"
        )
    }

    func testPathExpands_WithRotate() throws {
        let path = try SVGRenderer.makeExpanded(
            path: "M100,0 L 300,0 L 300,100 L 100,100 Z",
            transform: "rotate(90 100 0)",
            precision: 0
        )

        XCTAssertEqual(
            path,
            "M100,0 L100,200 L0,200 L0,0 Z"
        )
    }

}
