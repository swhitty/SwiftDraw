//
//  LayerTree.InvalidElementTests.swift
//  SwiftDraw
//
//  Created by Misoservices on 08/10/26.
//  Copyright 2026 Simon Whitty
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

import SwiftDrawDOM
import XCTest
@testable import SwiftDraw
import Foundation

// SD15: a document with invalid elements still draws the valid ones
final class LayerTreeInvalidElementTests: XCTestCase {

    func testValidSiblingsOfInvalidElementsStillProduceCommands() throws {
        let dom = try DOM.SVG.parse(data: Data("""
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">
          <path fill="red"/>
          <rect width="5" height="5" fill="#ff0000"/>
          <rect height="5"/>
          <rect width="2" height="2" x="" fill="#00ff00"/>
          <rect width="3" height="3" fill="#0000ff"/>
        </svg>
        """.utf8))
        let layer = LayerTree.Builder(svg: dom).makeLayer()
        let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(), size: .zero, options: .default)
        let commands = generator.renderCommands(for: layer, colorConverter: .default)
        let fills = commands.compactMap { command -> LayerTree.Color? in
            if case let .setFill(color: color) = command { return color }
            return nil
        }
        XCTAssertEqual(fills, [
            .rgba(r: 1, g: 0, b: 0, a: 1, space: .srgb),
            .rgba(r: 0, g: 0, b: 1, a: 1, space: .srgb)
        ])
    }
}
