//
//  LayerTree.CommandGeneratorTests.swift
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

final class LayerTreeCommandGeneratorTests: XCTestCase {

    func testShapes() throws {
        let svg = try DOM.SVG.parse(fileNamed: "shapes.svg", in: .test)
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(), size: .zero, options: .default)
        let commands = generator.renderCommands(for: layer, colorConverter: .default)

        XCTAssertEqual(
            commands.count,
            165
        )
    }

    func testClip() {
        let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(), size: .zero, options: .default)
        let circle = LayerTree.Shape.ellipse(within: .init(x: 0, y: 0, width: 10, height: 10))
        let rect = LayerTree.Shape.rect(within: .init(x: 20, y: 0, width: 10, height: 10), radii: .zero)

        let commands = generator.renderCommands(forClip: [circle, rect], using: nil)
        XCTAssertEqual(commands.count, 1)

        if case .setClip(path: let path, rule: let rule) = commands[0] {
            XCTAssertEqual(path, [circle, rect])
            XCTAssertEqual(rule, .nonzero)
        } else {
            XCTFail("expected clip command")
        }
    }

    func testTransforms() {
        let matrix = LayerTree.Transform.matrix(.init(a: 10, b: 20, c: 30, d: 40, tx: 50, ty: 60))
        let scale = LayerTree.Transform.scale(sx: 10, sy: 20)
        let translate = LayerTree.Transform.translate(tx: 10, ty: 20)
        let rotate = LayerTree.Transform.rotate(radians: 10)

        let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(), size: .zero, options: .default)
        let commands = generator.renderCommands(forTransforms: [matrix, scale, translate, rotate])
        XCTAssertEqual(commands.count, 4)
    }

    // MARK: - Patterns (SVG 1.1 §13.3)

    typealias Generator = LayerTree.CommandGenerator<LayerTreeProvider>

    func testPatternUserSpaceTileIsOffsetByXY() throws {
        let pattern = LayerTree.Pattern(frame: .init(x: 3, y: 4, width: 10, height: 20))
        let (resolved, content) = try XCTUnwrap(Generator.resolvePattern(pattern, in: .init(x: 50, y: 50, width: 100, height: 100)))
        XCTAssertEqual(resolved.frame, .init(x: 3, y: 4, width: 10, height: 20))
        XCTAssertEqual(resolved.transform, .identity)
        // contents are drawn relative to the tile origin
        XCTAssertEqual(content, .init(a: 1, b: 0, c: 0, d: 1, tx: 3, ty: 4))
    }

    func testPatternObjectBoundingBoxTile() throws {
        let pattern = LayerTree.Pattern(frame: .init(x: 0.1, y: 0, width: 0.25, height: 0.5), units: .objectBoundingBox)
        let (resolved, content) = try XCTUnwrap(Generator.resolvePattern(pattern, in: .init(x: 20, y: 40, width: 200, height: 100)))
        XCTAssertEqual(resolved.frame, .init(x: 40, y: 40, width: 50, height: 50))
        XCTAssertEqual(content, .init(a: 1, b: 0, c: 0, d: 1, tx: 40, ty: 40))
    }

    func testPatternObjectBoundingBoxContentUnits() throws {
        let pattern = LayerTree.Pattern(frame: .init(x: 0, y: 0, width: 10, height: 10), contentUnits: .objectBoundingBox)
        let (_, content) = try XCTUnwrap(Generator.resolvePattern(pattern, in: .init(x: 20, y: 40, width: 200, height: 100)))
        // content scaled by the bounding box size, origin at the tile (not the bounding box)
        XCTAssertEqual(content, .init(a: 200, b: 0, c: 0, d: 100, tx: 0, ty: 0))
    }

    func testPatternViewBoxMeetsAndOverridesContentUnits() throws {
        let pattern = LayerTree.Pattern(frame: .init(x: 5, y: 0, width: 40, height: 20), contentUnits: .objectBoundingBox)
        pattern.viewBox = .init(x: 10, y: 10, width: 10, height: 10)
        let (_, content) = try XCTUnwrap(Generator.resolvePattern(pattern, in: .init(x: 0, y: 0, width: 100, height: 100)))
        // xMidYMid meet: scale 2, centred horizontally (40 - 20) / 2 = 10, viewBox origin -20
        XCTAssertEqual(content, .init(a: 2, b: 0, c: 0, d: 2, tx: 5 + 10 - 20, ty: -20))
    }

    func testPatternTransformIsCarried() throws {
        let pattern = LayerTree.Pattern(frame: .init(x: 0, y: 0, width: 10, height: 10))
        pattern.transform = .init(a: 0, b: 1, c: -1, d: 0, tx: 7, ty: 8)
        let (resolved, _) = try XCTUnwrap(Generator.resolvePattern(pattern, in: .zero))
        XCTAssertEqual(resolved.transform, pattern.transform)
    }

    func testPatternWithEmptyTilePaintsNothing() {
        let bounds = LayerTree.Rect(x: 0, y: 0, width: 10, height: 10)
        XCTAssertNil(Generator.resolvePattern(LayerTree.Pattern(frame: .zero), in: bounds))
        XCTAssertNil(Generator.resolvePattern(LayerTree.Pattern(frame: .init(x: 0, y: 0, width: -1, height: 5)), in: bounds))
        XCTAssertNil(Generator.resolvePattern(LayerTree.Pattern(frame: .init(x: 0, y: 0, width: 1, height: 1), units: .objectBoundingBox), in: .zero))

        let emptyViewBox = LayerTree.Pattern(frame: .init(x: 0, y: 0, width: 5, height: 5))
        emptyViewBox.viewBox = .init(x: 0, y: 0, width: 0, height: 5)
        XCTAssertNil(Generator.resolvePattern(emptyViewBox, in: bounds))
    }

    func testPatternWithDegenerateTransformPaintsNothing() {
        let bounds = LayerTree.Rect(x: 0, y: 0, width: 10, height: 10)
        let scaledToZero = LayerTree.Pattern(frame: .init(x: 0, y: 0, width: 5, height: 5))
        scaledToZero.transform = .init(a: 0, b: 0, c: 0, d: 0, tx: 0, ty: 0)
        XCTAssertNil(Generator.resolvePattern(scaledToZero, in: bounds))

        let collapsed = LayerTree.Pattern(frame: .init(x: 0, y: 0, width: 5, height: 5))
        collapsed.transform = .init(a: 1, b: 2, c: 2, d: 4, tx: 0, ty: 0)
        XCTAssertNil(Generator.resolvePattern(collapsed, in: bounds))

        let infinite = LayerTree.Pattern(frame: .init(x: 0, y: 0, width: 5, height: 5))
        infinite.transform = .init(a: .infinity, b: 0, c: 0, d: 1, tx: 0, ty: 0)
        XCTAssertNil(Generator.resolvePattern(infinite, in: bounds))

        let nanTile = LayerTree.Pattern(frame: .init(x: .nan, y: 0, width: 5, height: 5))
        XCTAssertNil(Generator.resolvePattern(nanTile, in: bounds))
    }

    func testPatternBoundsOnlyEvaluatedWhenNeeded() {
        var evaluated = 0
        func bounds() -> LayerTree.Rect {
            evaluated += 1
            return .init(x: 0, y: 0, width: 10, height: 10)
        }

        let userSpace = LayerTree.Pattern(frame: .init(x: 0, y: 0, width: 5, height: 5))
        _ = Generator.resolvePattern(userSpace, in: bounds())
        XCTAssertEqual(evaluated, 0)

        let viewBoxOverridesContentUnits = LayerTree.Pattern(frame: .init(x: 0, y: 0, width: 5, height: 5), contentUnits: .objectBoundingBox)
        viewBoxOverridesContentUnits.viewBox = .init(x: 0, y: 0, width: 1, height: 1)
        _ = Generator.resolvePattern(viewBoxOverridesContentUnits, in: bounds())
        XCTAssertEqual(evaluated, 0)

        _ = Generator.resolvePattern(LayerTree.Pattern(frame: .init(x: 0, y: 0, width: 5, height: 5), contentUnits: .objectBoundingBox), in: bounds())
        XCTAssertEqual(evaluated, 1)

        _ = Generator.resolvePattern(LayerTree.Pattern(frame: .init(x: 0, y: 0, width: 1, height: 1), units: .objectBoundingBox), in: bounds())
        XCTAssertEqual(evaluated, 2)
    }

    func testPatternCommandsFromInkscapeStyleDocument() throws {
        let svg = try DOM.SVG.parse(xml: #"""
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="64" height="64">
            <defs>
                <pattern id="base" x="2" y="3" width="8" height="8" patternUnits="userSpaceOnUse">
                    <rect width="4" height="4" fill="red" />
                </pattern>
                <pattern id="derived" xlink:href="#base" patternTransform="translate(10, 0)" />
                <pattern id="empty" />
            </defs>
            <rect width="64" height="64" fill="url(#derived)" />
            <rect width="64" height="64" fill="url(#empty)" />
        </svg>
        """#)
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(), size: .zero, options: .default)
        let commands = generator.renderCommands(for: layer, colorConverter: .default)

        let patterns = commands.compactMap { command -> LayerTree.Pattern? in
            if case .setFillPattern(let p) = command { return p }
            return nil
        }
        // the pattern without width/height paints nothing, and the document still renders
        XCTAssertEqual(patterns.count, 1)
        XCTAssertEqual(patterns.first?.frame, .init(x: 2, y: 3, width: 8, height: 8))
        XCTAssertEqual(patterns.first?.transform, .init(a: 1, b: 0, c: 0, d: 1, tx: 10, ty: 0))
        XCTAssertEqual(patterns.first?.contents.count, 1)
        XCTAssertEqual(commands.filter { if case .fill = $0 { return true } else { return false } }.count, 1)
    }
}

private extension LayerTree.CommandGenerator {

    func renderCommands(forClip shapes: [LayerTree.Shape], using rule: LayerTree.FillRule?) -> [RendererCommand<P.Types>] {
        renderCommands(forClip: shapes.map { LayerTree.ClipShape(shape: $0, transform: .identity) }, using: rule)
    }
}

extension DOM.SVG {

    static func parse(fileNamed name: String, in bundle: Bundle = .test) throws -> DOM.SVG {
        guard let url = bundle.url(forResource: name, withExtension: nil) else {
            throw Error.missing
        }

        let parser = XMLParser(options: [.skipInvalidElements], filename: url.lastPathComponent)
        let element = try XML.SAXParser.parse(contentsOf: url)
        return try parser.parseSVG(element)
    }

    static func parse(
        xml: String,
        options: DOMXMLParser.Options = [.skipInvalidElements]
    ) throws -> DOM.SVG {
        let element = try XML.SAXParser.parse(data: xml.data(using: .utf8)!)
        let parser = XMLParser(options: options)
        return try parser.parseSVG(element)
    }

    enum Error: Swift.Error {
        case missing
    }
}
