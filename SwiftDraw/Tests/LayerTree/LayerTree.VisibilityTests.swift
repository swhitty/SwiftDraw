//
//  LayerTree.VisibilityTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 13/12/18.
//  Copyright 2020 WhileLoop Pty Ltd. All rights reserved.
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

final class LayerTreeVisibilityTests: XCTestCase {

    private func commands(_ body: String) throws -> [RendererCommand<LayerTreeProvider.Types>] {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape" width="100" height="100">\(body)</svg>
        """)
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(), size: .zero, options: .default)
        return generator.renderCommands(for: layer, colorConverter: .default)
    }

    private func fillCount(_ body: String) throws -> Int {
        try commands(body).filter {
            if case .fill = $0 { return true }
            return false
        }.count
    }

    func testDisplayNoneDrawsNothing() throws {
        XCTAssertEqual(try fillCount(#"<rect width="10" height="10" display="none"/>"#), 0)
        XCTAssertEqual(try fillCount(#"<rect width="10" height="10" style="display:none"/>"#), 0)
    }

    func testDisplayNoneDropsSubtreeEvenIfChildSaysInline() throws {
        let body = #"<g display="none"><rect width="10" height="10" display="inline"/><rect width="5" height="5"/></g><rect width="1" height="1"/>"#
        XCTAssertEqual(try fillCount(body), 1)
    }

    func testDisplayNoneLeavesNoTransformClipOrOpacity() throws {
        let body = #"""
        <clipPath id="c"><rect width="5" height="5"/></clipPath>
        <rect width="10" height="10" display="none" transform="translate(50 50)" clip-path="url(#c)" opacity="0.5"/>
        """#
        let cmds = try commands(body)
        XCTAssertFalse(cmds.contains { if case .fill = $0 { return true } else { return false } })
        XCTAssertFalse(cmds.contains { if case .setClip = $0 { return true } else { return false } })
        XCTAssertFalse(cmds.contains { if case .setAlpha = $0 { return true } else { return false } })
        XCTAssertFalse(cmds.contains { if case .translate = $0 { return true } else { return false } })
    }

    func testDisplayNoneOnUseAndOnReferencedElement() throws {
        let body = #"""
        <defs><rect id="r" width="10" height="10"/><rect id="h" width="10" height="10" display="none"/></defs>
        <use href="#r" display="none"/><use href="#h"/>
        """#
        XCTAssertEqual(try fillCount(body), 0)
        XCTAssertEqual(try fillCount(#"<defs><rect id="r" width="10" height="10"/></defs><use href="#r"/>"#), 1)
    }

    func testDisplayNoneRootDoesNotCrash() throws {
        let svg = try DOM.SVG.parse(xml: #"<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10" display="none"><rect width="5" height="5"/></svg>"#)
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        XCTAssertNotNil(layer)
    }

    func testDisplayNoneChildOfClipPathDoesNotContribute() throws {
        let body = #"""
        <clipPath id="c"><rect width="5" height="5"/><rect width="5" height="5" display="none"/></clipPath>
        <rect width="10" height="10" clip-path="url(#c)"/>
        """#
        let clips = try commands(body).filter { if case .setClip = $0 { return true } else { return false } }
        XCTAssertEqual(clips.count, 1)
    }

    func testVisibilityHiddenDrawsNothing() throws {
        XCTAssertEqual(try fillCount(#"<rect width="10" height="10" visibility="hidden"/>"#), 0)
        XCTAssertEqual(try fillCount(#"<rect width="10" height="10" visibility="collapse"/>"#), 0)
        XCTAssertEqual(try fillCount(#"<rect width="10" height="10" style="visibility:hidden"/>"#), 0)
    }

    func testVisibilityInheritsAndChildMayShowAgain() throws {
        let body = #"""
        <g visibility="hidden">
          <rect width="10" height="10"/>
          <rect width="10" height="10" visibility="visible"/>
          <g visibility="visible"><rect width="10" height="10"/></g>
        </g>
        """#
        XCTAssertEqual(try fillCount(body), 2)
    }

    func testInvalidVisibilityIsIgnored() throws {
        XCTAssertEqual(try fillCount(#"<g visibility="hidden"><rect width="10" height="10" visibility="bogus"/></g>"#), 0)
        XCTAssertEqual(try fillCount(#"<rect width="10" height="10" visibility="bogus"/>"#), 1)
    }

    func testVisibilityHiddenGroupStillAppliesToUse() throws {
        let body = #"<defs><rect id="r" width="10" height="10"/></defs><g visibility="hidden"><use href="#r"/><use href="#r" visibility="visible"/></g>"#
        XCTAssertEqual(try fillCount(body), 1)
    }

    func testForeignNamespaceElementDropsSubtree() throws {
        let body = #"""
        <inkscape:foo><rect width="10" height="10"/><g><rect width="10" height="10"/></g></inkscape:foo>
        <rect width="1" height="1"/>
        """#
        XCTAssertEqual(try fillCount(body), 1)
    }

    func testForeignNamespaceDoesNotLeakIntoDOM() throws {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:sodipodi="http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd" width="10" height="10">
          <sodipodi:namedview><rect width="1" height="1"/></sodipodi:namedview>
          <rect width="2" height="2"/>
        </svg>
        """)
        XCTAssertEqual(svg.childElements.count, 1)
    }
}
