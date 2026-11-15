//
//  Renderer.SFSymbolLayerClassTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 20/8/22.
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

import Foundation
import SwiftDrawDOM
import Testing
@testable import SwiftDraw

struct RendererSFSymbolLayerClassTests {

    // SD10: `.hierarchical-0:secondary` is one class name, not a class plus a pseudo-class
    @Test(arguments: [
        ("sun-horizon.svg", [".monochrome-0 {", ".monochrome-1 {",
                             ".multicolor-0:systemYellowColor {", ".multicolor-1:emerald {",
                             ".hierarchical-0:secondary {", ".hierarchical-1:primary {"]),
        ("checkmark.svg", [".multicolor-0:custom {"])
    ])
    func exportKeepsLayerClassRules(file: String, rules: [String]) throws {
        let url = try Bundle.test.url(forResource: file)
        let renderer = SFSymbolRenderer(
            size: .small,
            options: [],
            insets: .init(),
            insetsUltralight: .init(),
            insetsBlack: .init(),
            precision: 3,
            isLegacyInsets: false
        )
        let output = try renderer.render(default: DOM.SVG.parse(fileURL: url), ultralight: nil, black: nil)
        for rule in rules {
            #expect(output.contains(rule), "\(file) lost \(rule)")
        }
    }
}
