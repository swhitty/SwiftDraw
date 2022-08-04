//
//  XML.FormatterTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 27/02/22.
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

@testable import SwiftDraw
import XCTest

final class XMLFormatterTests: XCTestCase {

    func testAA() {
        let formatter = XML.Formatter(spaces: 2)

        let element = XML.Element(
            name: "draw",
            attributes: ["zlevel": "2", "color": "Red&Back"]
        )

        element.children.append(.init(name: "circle"))

        XCTAssertEqual(
            formatter.encodeElement(element),
            """
            <draw color="Red&amp;Back" zlevel="2">
              <circle />
            </draw>
            """
        )
    }

    func testBB() throws {
        let url = try Bundle.test.url(forResource: "gradient-gratification.svg")
        let svg = try DOM.SVG.parse(fileURL: url)

        let element = XML.Formatter.SVG.makeElement(from: svg)
        let formatter = XML.Formatter(spaces: 2)

        XCTAssertEqual(
            formatter.encodeRootElement(element),
            """
            <?xml version="1.0" encoding="UTF-8"?>
            <svg height="352" width="480" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
              <defs>
                <linearGradient id="violet" x1="0.0" x2="1.0" y1="1.0" y2="1.0" />
                <linearGradient id="magenta" x1="0.0" x2="1.0" y1="1.0" y2="1.0" />
                <linearGradient id="spread" x1="0.0" x2="0.0" y1="0.0" y2="1.0" />
                <rect id="frame" height="256.0" width="256.0" x="112.0" y="48.0" />
              </defs>
              <rect fill="url(#checkerboard)" height="352.0" width="480.0" x="0.0" y="0.0" />
              <use fill="url(#magenta)" xlink:href="#frame" />
              <use fill="url(#violet)" mask="url(#fade)" xlink:href="#frame" />
            </svg>
            """
        )
    }

    func testSymbol() throws {
        let url = try Bundle.test.url(forResource: "symbol-test.svg")
        let svg = try DOM.SVG.parse(fileURL: url)

        let element = XML.Formatter.SVG.makeElement(from: svg)
        let formatter = XML.Formatter(spaces: 2)

        XCTAssertEqual(
            formatter.encodeRootElement(element),
            """
            <?xml version="1.0" encoding="UTF-8"?>
            <svg viewBox="0.0 0.0 550.0 550.0" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
              <defs>
                <path id="A" d="M0.0,69.755 L2.685,69.755 L28.369,3.287 L29.052,3.287 L29.052,0.0 L27.148,0.0 L0.0,69.755 Z M10.693,45.536 L45.996,45.536 L45.263,43.313 L11.474,43.313 L10.693,45.536 Z M54.15,69.755 L56.787,69.755 L29.638,0.0 L28.466,0.0 L28.466,3.287 L54.15,69.755 Z" fill="rgb(39, 170, 225)" />
              </defs>
              <g id="Notes" font-family="LucidaGrande, 'Lucida Grande', sans-serif" font-size="13.0">
                <text x="18.0" y="126.0">Small</text>
                <text x="18.0" y="320.0">Medium</text>
                <text x="18.0" y="517.0">Large</text>
              </g>
              <g id="Guides" stroke="rgb(39, 170, 225)" stroke-width="0.5">
                <path id="Capline-S" d="M18.0,26.0 l500.0,0.0" />
                <use x="95.0" xlink:href="#A" y="26.0" />
                <path id="Baseline-S" d="M18.0,96.0 l500.0,0.0" />
                <path id="Capline-M" d="M18.0,220.0 l500.0,0.0" />
                <use x="95.0" xlink:href="#A" y="220.0" />
                <path id="Baseline-M" d="M18.0,290.0 l500.0,0.0" />
                <path id="Capline-L" d="M18.0,417.0 l500.0,0.0" />
                <use x="95.0" xlink:href="#A" y="417.0" />
                <path id="Baseline-L" d="M18.0,487.0 l500.0,0.0" />
                <path id="left-margin-Regular-M" d="M256.0,195.0 l0.0,120.0" />
                <path id="right-margin-Regular-M" d="M373.0,195.0 l0.0,120.0" />
              </g>
              <g id="Regular-M">
                <path d="M285.854,236.968 L285.854,257.0591 C285.854,276.55 301.654,292.351 321.145,292.351 M301.019,252.0174 L285.894,236.892 L270.769,252.0174 M346.434,272.144 L346.434,252.0577 C346.434,232.567 330.634,216.766 311.143,216.766 M331.269,257.0591 L346.394,272.184 L361.519,257.0591" fill="none" stroke="rgb(33, 33, 33)" stroke-linecap="round" stroke-linejoin="round" stroke-width="10.0" />
              </g>
            </svg>
            """
        )
    }
}
