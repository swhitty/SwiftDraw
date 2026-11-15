//
//  LayerTree.MaskTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 15/11/26.
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

@testable import SwiftDraw
import SwiftDrawDOM
import Foundation
import Testing

struct LayerTreeMaskTests {

    typealias Command = RendererCommand<LayerTreeTypes>

    @Test
    func maskClipsBeforeContentsAreDrawn() throws {
        let commands = try makeCommands(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <mask id="m">
                <rect width="100" height="100" fill="white" />
                <rect width="50" height="100" fill="black" opacity="0.5" />
            </mask>
            <rect width="100" height="100" fill="green" mask="url(#m)" />
        </svg>
        """#)

        let mask = try #require(commands.firstIndex { $0.maskContents != nil })
        let push = try #require(commands.firstIndex { $0.isPushTransparencyLayer })
        let fill = try #require(commands.firstIndex { $0.isFill })
        let pop = try #require(commands.lastIndex { $0.isPopTransparencyLayer })
        #expect(mask < push)
        #expect(push < fill)
        #expect(fill < pop)
        #expect(commands.filter { $0.maskContents != nil }.count == 1)
    }

    @Test
    func maskContentsAreDrawnWithNormalCompositing() throws {
        let commands = try makeCommands(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <mask id="m">
                <rect width="100" height="100" fill="white" />
                <rect width="50" height="100" fill="black" opacity="0.5" />
            </mask>
            <rect width="100" height="100" fill="green" mask="url(#m)" />
        </svg>
        """#)

        let contents = try #require(commands.compactMap(\.maskContents).first)
        #expect(!contents.contains { $0.isSetBlend })
        #expect(!commands.contains { $0.isSetBlend })
        // the translucent child is still grouped with its own opacity
        #expect(contents.contains { $0.isPushTransparencyLayer })
    }

    @Test
    func maskContentColoursAreLuminanceGrey() throws {
        let commands = try makeCommands(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <mask id="m">
                <rect width="100" height="100" fill="red" fill-opacity="0.5" />
            </mask>
            <rect width="100" height="100" fill="green" mask="url(#m)" />
        </svg>
        """#)

        let contents = try #require(commands.compactMap(\.maskContents).first)
        let fills = contents.compactMap(\.fillColor)
        #expect(fills == [.gray(white: 0.2126, a: 0.5)])
    }

    @Test(arguments: [
        (LayerTree.Color.white, LayerTree.Color.gray(white: 1.0, a: 1.0)),
        (.black, .gray(white: 0.0, a: 1.0)),
        (.srgb(r: 1, g: 0, b: 0, a: 1), .gray(white: 0.2126, a: 1.0)),
        (.srgb(r: 0, g: 1, b: 0, a: 0.5), .gray(white: 0.7152, a: 0.5)),
        (.srgb(r: 0, g: 0, b: 1, a: 1), .gray(white: 0.0722, a: 1.0)),
        (.gray(white: 0.3, a: 0.4), .gray(white: 0.3, a: 0.4)),
        (.none, .none)
    ])
    func luminanceConverter(color: LayerTree.Color, expected: LayerTree.Color) {
        #expect(LuminanceColorConverter().createColor(from: color) == expected)
    }

    func makeCommands(_ xml: String) throws -> [Command] {
        let svg = try DOM.SVG.parse(xml: xml)
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(), size: .zero, options: .default)
        return generator.renderCommands(for: layer, colorConverter: .default)
    }
}

private extension RendererCommand<LayerTreeTypes> {

    var maskContents: [Self]? {
        if case .clipToMask(let contents) = self { return contents }
        return nil
    }

    var fillColor: LayerTree.Color? {
        if case .setFill(color: let color) = self { return color }
        return nil
    }

    var isFill: Bool {
        if case .fill = self { return true }
        return false
    }

    var isSetBlend: Bool {
        if case .setBlend = self { return true }
        return false
    }

    var isPushTransparencyLayer: Bool {
        if case .pushTransparencyLayer = self { return true }
        return false
    }

    var isPopTransparencyLayer: Bool {
        if case .popTransparencyLayer = self { return true }
        return false
    }
}
