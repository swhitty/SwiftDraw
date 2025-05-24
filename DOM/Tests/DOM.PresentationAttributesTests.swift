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
@testable import DOM

final class PresentationAttributesTests: XCTestCase {

    typealias Attributes = DOM.PresentationAttributes
    typealias StyleSheet = DOM.StyleSheet

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

    func testSelectors() {
        XCTAssertEqual(
            DOM.makeSelectors(for: .circle()),
            [.element("circle")]
        )

        XCTAssertEqual(
            DOM.makeSelectors(for: .circle(id: "c1")),
            [.element("circle"),
             .id("c1")]
        )

        XCTAssertEqual(
            DOM.makeSelectors(for: .circle(class: "c")),
            [.element("circle"),
             .class("c")]
        )

        XCTAssertEqual(
            DOM.makeSelectors(for: .circle(id: "c1 ", class: "a  b c")),
            [.element("circle"),
             .class("a"),
             .class("b"),
             .class("c"),
             .id("c1")]
        )
    }

    func testLastSheetAttributesAreUsed() {
        var sheet = StyleSheet()
        sheet[.id("b")].opacity = 0
        sheet[.id("a")].opacity = 1

        var another = StyleSheet()
        another[.id("b")].opacity = 0.1
        another[.id("a")].opacity = 0.5

        XCTAssertEqual(
            DOM.makeAttributes(for: .id("a"), styles: [sheet])
                .opacity,
            1
        )

        XCTAssertEqual(
            DOM.makeAttributes(for: .id("a"), styles: [sheet, another])
                .opacity,
            0.5
        )
    }

    func testSelectorPrecedence() {
        var sheet = StyleSheet()
        sheet[.element("circle")].opacity = 1
        sheet[.id("c1")].opacity = 0.5
        sheet[.class("b")].opacity = 0.1
        sheet[.class("c")].opacity = 0.2

        XCTAssertEqual(
            DOM.presentationAttributes(for: .circle(id: "c1", class: "b c"),
                                       styles: [sheet])
                .opacity,
            0.5
        )

        XCTAssertEqual(
            DOM.presentationAttributes(for: .circle(id: "c2", class: "b c"),
                                       styles: [sheet])
                .opacity,
            0.2
        )

        XCTAssertEqual(
            DOM.presentationAttributes(for: .circle(id: "c2", class: "z"),
                                       styles: [sheet])
                .opacity,
            1
        )
    }
}

private extension DOM.GraphicsElement {
    static func circle(id: String? = nil, class: String? = nil) -> DOM.Circle {
        let circle = DOM.Circle(cx: nil, cy: nil, r: 5)
        circle.id = id
        circle.class = `class`
        return circle
    }
}

private extension DOM.StyleSheet {
    subscript(_ selector: Selector) -> DOM.PresentationAttributes {
        get {
            attributes[selector] ?? .init()
        }
        set {
            attributes[selector] = newValue
        }
    }
}
