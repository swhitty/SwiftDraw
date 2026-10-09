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

    /// The `clip` of every layer that has one, in tree order.
    private func clipShapes(_ body: String) throws -> [[LayerTree.ClipShape]] {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">\(body)</svg>
        """)
        func collect(_ layer: LayerTree.Layer) -> [[LayerTree.ClipShape]] {
            var result = layer.clip.isEmpty ? [] : [layer.clip]
            for case .layer(let child) in layer.contents {
                result += collect(child)
            }
            return result
        }
        return collect(LayerTree.Builder(svg: svg).makeLayer())
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
        XCTAssertEqual(try fillCount(##"<defs><rect id="r" width="10" height="10"/></defs><use href="#r"/>"##), 1)
    }

    func testDisplayNoneRootDoesNotCrash() throws {
        let svg = try DOM.SVG.parse(xml: #"<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10" display="none"><rect width="5" height="5"/></svg>"#)
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        XCTAssertTrue(layer.contents.isEmpty)
    }

    func testDisplayNoneChildOfClipPathDoesNotContribute() throws {
        let body = #"""
        <clipPath id="c"><rect width="5" height="5"/><rect width="5" height="5" display="none"/></clipPath>
        <rect width="10" height="10" clip-path="url(#c)"/>
        """#
        let clips = try commands(body).filter { if case .setClip = $0 { return true } else { return false } }
        XCTAssertEqual(clips.count, 1)
        // the hidden child is not part of the clip itself
        let clip = try XCTUnwrap(clipShapes(body).first)
        XCTAssertEqual(clip.count, 1)
        XCTAssertEqual(clip[0].shape, .rect(within: .init(x: 0, y: 0, width: 5, height: 5), radii: .zero))
    }

    func testClipPathWithOnlyHiddenChildrenClipsEverything() throws {
        let body = #"""
        <clipPath id="c"><rect width="5" height="5" display="none"/><rect width="5" height="5" visibility="hidden"/></clipPath>
        <rect width="10" height="10" clip-path="url(#c)"/>
        """#
        let clip = try XCTUnwrap(clipShapes(body).first)
        XCTAssertEqual(clip.map(\.shape), [.rect(within: .zero, radii: .zero)])
    }

    func testDisplayDoesNotApplyToMask() throws {
        let body = #"""
        <mask id="m" display="none"><rect width="10" height="10" fill="white"/></mask>
        <rect width="10" height="10" mask="url(#m)"/>
        """#
        XCTAssertEqual(try fillCount(body), 2)
    }

    func testDisplayNoneOnChildOfMaskStillHidesIt() throws {
        let body = #"""
        <mask id="m"><rect width="10" height="10" fill="white"/><rect width="10" height="10" display="none"/></mask>
        <rect width="10" height="10" mask="url(#m)"/>
        """#
        XCTAssertEqual(try fillCount(body), 2)
    }

    func testDisplayNoneOnClipPathElementStillClips() throws {
        let body = #"""
        <clipPath id="c" display="none"><rect width="5" height="5"/></clipPath>
        <rect width="10" height="10" clip-path="url(#c)"/>
        """#
        XCTAssertEqual(try clipShapes(body).first?.count, 1)
        XCTAssertEqual(try fillCount(body), 1)
    }

    func testDefinitionsInsideDisplayNoneGroupAreStillUsed() throws {
        let body = #"""
        <g display="none">
          <clipPath id="c"><rect width="5" height="5"/></clipPath>
          <linearGradient id="g"><stop offset="0" stop-color="red"/><stop offset="1" stop-color="blue"/></linearGradient>
          <pattern id="p" width="4" height="4" patternUnits="userSpaceOnUse"><rect width="2" height="2"/></pattern>
        </g>
        <rect width="10" height="10" clip-path="url(#c)"/>
        <rect width="10" height="10" fill="url(#g)"/>
        <rect width="10" height="10" fill="url(#p)"/>
        """#
        let cmds = try commands(body)
        XCTAssertEqual(try XCTUnwrap(clipShapes(body).first).count, 1)
        XCTAssertTrue(cmds.contains { if case .drawLinearGradient = $0 { return true } else { return false } })
        XCTAssertTrue(cmds.contains { if case .setFillPattern = $0 { return true } else { return false } })
    }

    func testDisplayAndVisibilityFromClassAndStyleSheet() throws {
        let body = #"""
        <style>.gone { display: none } .ghost { visibility: hidden } #shown { visibility: visible }</style>
        <rect class="gone" width="10" height="10"/>
        <rect class="ghost" width="10" height="10"/>
        <g class="ghost"><rect id="shown" width="10" height="10"/></g>
        <rect width="10" height="10"/>
        """#
        XCTAssertEqual(try fillCount(body), 2)
    }

    func testHiddenTextAndImageDrawNothing() throws {
        // the layer tree, not the commands: LayerTreeProvider draws no path for text, visible or not
        let png = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
        func contents(_ attribute: String) throws -> (text: Int, image: Int) {
            let svg = try DOM.SVG.parse(xml: """
            <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
            <text x="0" y="10" \(attribute)>hi</text><image width="1" height="1" \(attribute) href="\(png)"/>
            </svg>
            """)
            func count(_ layer: LayerTree.Layer) -> (text: Int, image: Int) {
                layer.contents.reduce(into: (0, 0)) { total, content in
                    switch content {
                    case .text: total.text += 1
                    case .image: total.image += 1
                    case .layer(let child):
                        let c = count(child)
                        total.text += c.text
                        total.image += c.image
                    case .shape: break
                    }
                }
            }
            return count(LayerTree.Builder(svg: svg).makeLayer())
        }
        let visible = try contents("")
        XCTAssertEqual(visible.text, 1)
        XCTAssertEqual(visible.image, 1)
        for attribute in [#"visibility="hidden""#, #"display="none""#] {
            let hidden = try contents(attribute)
            XCTAssertEqual(hidden.text, 0, attribute)
            XCTAssertEqual(hidden.image, 0, attribute)
        }
    }

    func testUseOfDisplayNoneElementWithOpacityAndMaskDrawsNothing() throws {
        let body = #"""
        <defs>
          <mask id="m"><rect width="10" height="10" fill="white"/></mask>
          <rect id="h" width="10" height="10" display="none" opacity="0.5" mask="url(#m)" transform="translate(5 5)"/>
        </defs>
        <use href="#h"/>
        """#
        XCTAssertEqual(try commands(body).count, 0)
    }

    func testDisplayNoneElementBuildsNoLayerState() throws {
        let cmds = try commands(#"<rect width="10" height="10" display="none" opacity="0.5" stroke="red"/>"#)
        XCTAssertEqual(cmds.count, 0)
    }

    func testForeignObjectWithSVGNamespaceChild() throws {
        // <foreignObject> is not rendered, so an SVG-namespace child inside it goes with it; the sibling draws
        let body = #"""
        <foreignObject width="10" height="10"><rect xmlns="http://www.w3.org/2000/svg" width="5" height="5"/></foreignObject>
        <rect width="1" height="1"/>
        """#
        XCTAssertEqual(try fillCount(body), 1)
    }

    func testDisplayDoesNotApplyToGradientPatternOrFilter() throws {
        // SVG 1.1 §11.5: display does not apply to gradients, <pattern> or <filter>
        let body = #"""
        <linearGradient id="g" display="none"><stop offset="0" stop-color="red"/><stop offset="1" stop-color="blue"/></linearGradient>
        <pattern id="p" display="none" width="4" height="4" patternUnits="userSpaceOnUse"><rect width="2" height="2"/></pattern>
        <filter id="f" display="none"><feGaussianBlur stdDeviation="2"/></filter>
        <rect width="10" height="10" fill="url(#g)"/>
        <rect width="10" height="10" fill="url(#p)"/>
        <rect width="10" height="10" filter="url(#f)"/>
        """#
        let cmds = try commands(body)
        XCTAssertTrue(cmds.contains { if case .drawLinearGradient = $0 { return true } else { return false } })
        XCTAssertTrue(cmds.contains { if case .setFillPattern = $0 { return true } else { return false } })
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">\(body)</svg>
        """)
        func hasFilter(_ layer: LayerTree.Layer) -> Bool {
            !layer.filters.isEmpty || layer.contents.contains {
                if case .layer(let child) = $0 { return hasFilter(child) } else { return false }
            }
        }
        XCTAssertTrue(hasFilter(LayerTree.Builder(svg: svg).makeLayer()))
    }

    func testClipPathWithOnlyAUseChildStillDraws() throws {
        // a child this builder cannot clip with is not a hidden one: the element must not vanish
        let body = #"""
        <defs><rect id="r" width="5" height="5"/></defs>
        <clipPath id="c"><use href="#r"/></clipPath>
        <rect width="10" height="10" clip-path="url(#c)"/>
        """#
        XCTAssertEqual(try fillCount(body), 1)
        XCTAssertFalse(try clipShapes(body).contains { $0 == [LayerTree.ClipShape(shape: .rect(within: .zero, radii: .zero), transform: .identity)] })
    }

    func testVisibilityParsesInDOM() throws {
        let svg = try DOM.SVG.parse(xml: #"""
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">
          <rect width="1" height="1" visibility="hidden"/>
          <rect width="1" height="1" style="visibility: collapse"/>
          <rect width="1" height="1" visibility="bogus"/>
          <rect width="1" height="1"/>
        </svg>
        """#)
        let values = svg.childElements.map { DOM.presentationAttributes(for: $0, styles: svg.styles).visibility }
        XCTAssertEqual(values, [.hidden, .collapse, nil, nil])
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
        let body = ##"<defs><rect id="r" width="10" height="10"/></defs><g visibility="hidden"><use href="#r"/><use href="#r" visibility="visible"/></g>"##
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
