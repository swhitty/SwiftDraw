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

        let element = try XML.Formatter.SVG().makeElement(from: svg)
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

        let element = try XML.Formatter.SVG().makeElement(from: svg)
        let formatter = XML.Formatter(spaces: 2)

        XCTAssertEqual(
            formatter.encodeRootElement(element),
            """
            <?xml version="1.0" encoding="UTF-8"?>
            <svg viewBox="0,0,550,550" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
              <defs>
                <path id="A" d="M0,69.75 L2.68,69.75 L28.37,3.29 L29.052,3.29 L29.052,0 L27.15,0 L0,69.75 Z M10.69,45.54 L46,45.54 L45.26,43.31 L11.47,43.31 L10.69,45.54 Z M54.15,69.75 L56.79,69.75 L29.64,0 L28.47,0 L28.47,3.29 L54.15,69.75 Z" fill="rgb(39, 170, 225)" />
              </defs>
              <g id="Notes" font-family="LucidaGrande, 'Lucida Grande', sans-serif" font-size="13">
                <text x="18.0" y="126.0">Small</text>
                <text x="18.0" y="320.0">Medium</text>
                <text x="18.0" y="517.0">Large</text>
              </g>
              <g id="Guides" stroke="rgb(39, 170, 225)" stroke-width="0.5">
                <path id="Capline-S" d="M18,26 l500,0" />
                <use x="95.0" xlink:href="#A" y="26.0" />
                <path id="Baseline-S" d="M18,96 l500,0" />
                <path id="Capline-M" d="M18,220 l500,0" />
                <use x="95.0" xlink:href="#A" y="220.0" />
                <path id="Baseline-M" d="M18,290 l500,0" />
                <path id="Capline-L" d="M18,417 l500,0" />
                <use x="95.0" xlink:href="#A" y="417.0" />
                <path id="Baseline-L" d="M18,487 l500,0" />
                <path id="left-margin-Regular-M" d="M256,195 l0,120" />
                <path id="right-margin-Regular-M" d="M373,195 l0,120" />
              </g>
              <g id="Regular-M">
                <path d="M285.85,236.97 L285.85,257.059 C285.85,276.55 301.65,292.35 321.14,292.35 M301.019,252.017 L285.89,236.89 L270.77,252.017 M346.43,272.14 L346.43,252.058 C346.43,232.57 330.63,216.77 311.14,216.77 M331.27,257.059 L346.39,272.18 L361.52,257.059" style="fill: none; stroke-linecap: round; stroke-linejoin: round; stroke-width: 10; stroke: rgb(33, 33, 33)" />
              </g>
            </svg>
            """
        )
    }
}

private extension XML.Formatter.SVG {

    init(places: Int = 2) {
        self.init(formatter: .init(delimeter: .comma, precision: .capped(max: places)))
    }
}

extension LayerTree.Point {
    var stringValue: String {
        "\(x), \(y)"
    }
}
