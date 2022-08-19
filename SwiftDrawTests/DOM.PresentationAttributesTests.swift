//
//  DOM.PresentationAttributesTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 19/8/22.
//  Copyright 2022 WhileLoop Pty Ltd. All rights reserved.
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

final class PresentationAttributesTests: XCTestCase {

    typealias Attributes = DOM.PresentationAttributes

    func testOpacityIsApplied() {
        XCTAssertNil(
            Attributes(opacity: nil)
                .applyingAttributes(Attributes(opacity: nil))
                .opacity
        )

        XCTAssertEqual(
            Attributes(opacity: 5)
                .applyingAttributes(Attributes(opacity: nil))
                .opacity,
            5
        )

        XCTAssertEqual(
            Attributes(opacity: 5)
                .applyingAttributes(Attributes(opacity: 10))
                .opacity,
            10
        )
    }

    func testDisplayIsApplied() {
        XCTAssertNil(
            Attributes(display: nil)
                .applyingAttributes(Attributes(display: nil))
                .display
        )

        XCTAssertEqual(
            Attributes(display: DOM.DisplayMode.none)
                .applyingAttributes(Attributes(display: nil))
                .display,
            DOM.DisplayMode.none
        )

        XCTAssertEqual(
            Attributes(display: DOM.DisplayMode.none)
                .applyingAttributes(Attributes(display: .inline))
                .display,
            .inline
        )
    }

    func testColorIsApplied() {
        XCTAssertNil(
            Attributes(color: nil)
                .applyingAttributes(Attributes(color: nil))
                .color
        )

        XCTAssertEqual(
            Attributes(color: .keyword(.green))
                .applyingAttributes(Attributes(color: nil))
                .color,
            .keyword(.green)
        )

        XCTAssertEqual(
            Attributes(color: .keyword(.green))
                .applyingAttributes(Attributes(color: .currentColor))
                .color,
            .currentColor
        )
    }
}