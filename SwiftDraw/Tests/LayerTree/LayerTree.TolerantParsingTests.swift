//
//  LayerTree.TolerantParsingTests.swift
//  SwiftDraw
//
//  Created by Misoservices on 08/10/26.
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

import SwiftDrawDOM
import XCTest
@testable import SwiftDraw
import Foundation

final class LayerTreeTolerantParsingTests: XCTestCase {

    private func fillColors(_ svg: String) throws -> [LayerTree.Color] {
        let dom = try DOM.SVG.parse(data: Data(svg.utf8))
        let layer = LayerTree.Builder(svg: dom).makeLayer()
        let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(), size: .zero, options: .default)
        return generator.renderCommands(for: layer, colorConverter: .default).compactMap {
            if case let .setFill(color: color) = $0 { return color }
            return nil
        }
    }

    private func alphas(_ colors: [LayerTree.Color]) -> [Float] {
        colors.compactMap {
            if case let .rgba(_, _, _, a, _) = $0 { return a }
            return nil
        }
    }

    func testHSLAAndHexAlphaReachCommandStream() throws {
        let colors = try fillColors("""
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">
          <rect width="5" height="5" fill="hsla(0, 100%, 50%, 0.25)"/>
          <rect width="5" height="5" fill="#00ff0080"/>
        </svg>
        """)
        let a = alphas(colors)
        XCTAssertEqual(a.count, 2)
        XCTAssertEqual(a[0], 0.25, accuracy: 0.001)
        XCTAssertEqual(a[1], 128.0 / 255, accuracy: 0.001)
    }
}
