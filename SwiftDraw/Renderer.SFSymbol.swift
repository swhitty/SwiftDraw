//
//  Renderer.SFSymbol.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 18/8/22.
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

import Foundation

public final class SFSymbolRenderer { }

extension SFSymbolRenderer {

    static func getPaths(for layer: LayerTree.Layer) -> [LayerTree.Path] {
        guard layer.opacity > 0,
              layer.clip.isEmpty,
              layer.mask == nil else { return [] }

        var paths = [LayerTree.Path]()

        for c in layer.contents {
            switch c {
            case let .shape(shape, stroke, fill):
                if let path = makePath(for: shape, stoke: stroke, fill: fill) {
                    if fill.rule == .evenodd {
                        paths.append(path.makeNonZero())
                    } else {
                        paths.append(path)
                    }
                }
            case .layer(let l):
                paths.append(contentsOf: getPaths(for: l))
            default:
                ()
            }
        }

        return paths
    }

    static func makePath(for shape: LayerTree.Shape,
                         stoke: LayerTree.StrokeAttributes,
                         fill: LayerTree.FillAttributes) -> LayerTree.Path? {
        guard case .path(let p) = shape else { return nil }

        if fill.fill != .none && fill.opacity > 0 {
            return p
        }

        if stoke.color != .none && stoke.width > 0 {
        #if canImport(CoreGraphics)
            return expandOutlines(for: p, stroke: stoke)
        #else
            print("Warning:", "expanding stroke outlines requires macOS.", to: &.standardError)
            return nil
        #endif
        }

        return nil
    }

    static func makeBounds(for paths: [LayerTree.Path]) -> LayerTree.Rect {
        var min = LayerTree.Point.maximum
        var max = LayerTree.Point.minimum
        for p in paths {
            let bounds = p.bounds
            min = min.minimum(combining: .init(bounds.minX, bounds.minY))
            max = max.maximum(combining: .init(bounds.maxX, bounds.maxY))
        }
        return LayerTree.Rect(
            x: min.x,
            y: min.y,
            width: max.x - min.x,
            height: max.y - min.y
        )
    }

    static func makeTransformation(of source: LayerTree.Rect,
                                   to bounds: LayerTree.Rect) -> LayerTree.Transform.Matrix {
        let scale = bounds.height / source.height
        let scaleMidX = source.midX * scale
        let scaleMidY = source.midY * scale
        let tx = bounds.midX - scaleMidX
        let ty =  bounds.midY - scaleMidY
        let t = LayerTree.Transform
            .translate(tx: tx, ty: ty)
        return LayerTree.Transform
            .scale(sx: scale, sy: scale)
            .toMatrix()
            .concatenated(t.toMatrix())
    }

    static func convertPaths(_ paths: [LayerTree.Path],
                             into bounds: LayerTree.Rect) -> [DOM.Path] {
        let matrix = makeTransformation(
            of: makeBounds(for: paths),
            to: bounds
        )
        return paths.map { $0.applying(matrix: matrix) }
            .map(makeDOMPath)
    }

    static func makeDOMPath(for path: LayerTree.Path) -> DOM.Path {
        let dom = DOM.Path(x: 0, y: 0)
        dom.segments = path.segments.map {
            switch $0 {
            case let .move(to: p):
                return .move(x: p.x, y: p.y, space: .absolute)
            case let .line(to: p):
                return .line(x: p.x, y: p.y, space: .absolute)
            case let .cubic(to: p, control1: cp1, control2: cp2):
                return .cubic(x1: cp1.x, y1: cp1.y, x2: cp2.x, y2: cp2.y, x: p.x, y: p.y, space: .absolute)
            case .close:
                return .close
            }
        }
        return dom
    }

    struct Error: LocalizedError {
        var errorDescription: String?

        init(_ message: String) {
            self.errorDescription = message
        }
    }
}

public extension SFSymbolRenderer {

    static func render(fileURL: URL, options: Image.Options) throws -> String {
        let svg = try DOM.SVG.makeSFSymbolTemplate()

        let source = try DOM.SVG.parse(fileURL: fileURL)
        let layer = LayerTree.Builder(svg: source).makeLayer()

        let regular = try svg.group(id: "Symbols").group(id: "Regular-S")
        let ultralight = try svg.group(id: "Symbols").group(id: "Ultralight-S")
        let black = try svg.group(id: "Symbols").group(id: "Black-S")

        let sourcePaths = getPaths(for: layer)
        guard !sourcePaths.isEmpty else {
            throw Error("No valid content found.")
        }
        regular.childElements.append(
            contentsOf: convertPaths(sourcePaths, into: .regular)
        )
        ultralight.childElements.append(
            contentsOf: convertPaths(sourcePaths, into: .ultralight)
        )
        black.childElements.append(
            contentsOf: convertPaths(sourcePaths, into: .black)
        )

        let coordinate = XML.Formatter.CoordinateFormatter(delimeter: .comma,
                                                           precision: .capped(max: 3))
        let element = try XML.Formatter.SVG(formatter: coordinate).makeElement(from: svg)
        let formatter = XML.Formatter(spaces: 2)
        let result = formatter.encodeRootElement(element)
        return result
    }

    static func template() throws -> String {
        let svg = try DOM.SVG.makeSFSymbolTemplate()
        
        let coordinate = XML.Formatter.CoordinateFormatter(delimeter: .comma, precision: .capped(max: 5))
        let element = try XML.Formatter.SVG(formatter: coordinate).makeElement(from: svg)
        let formatter = XML.Formatter(spaces: 2)
        return formatter.encodeRootElement(element)
    }
}

extension DOM.SVG {

    static func makeSFSymbolTemplate() throws -> DOM.SVG {
        let svg = """
        <?xml version="1.0" encoding="UTF-8" standalone="no"?>
        <svg width="800" height="600" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
            <g id="Notes" font-family="'LucidaGrande', 'Lucida Grande', sans-serif" font-weight="500" font-size="13px">
                  <rect x="0" y="0" width="800" height="600" fill="white"/>
                <g font-weight="500" font-size="13px">
                    <text x="18px" y="176px">Small</text>
                    <text x="18px" y="376px">Medium</text>
                    <text x="18px" y="576px">Large</text>
                </g>
                <g font-weight="300" font-size="9px">
                    <text x="250px" y="30px">Ultralight</text>
                    <text x="450px" y="30px">Regular</text>
                 <text x="650px" y="30px">Black</text>
                 <text id="template-version" fill="#505050" x="730.0" y="575.0">Template v.3.0</text>
                 <a href="https://github.com/swhitty/SwiftDraw">
                   <text fill="#505050" x="627.0" y="590.0">https://github.com/swhitty/SwiftDraw</text>
                 </a>
                </g>
            </g>

            <g id="Guides" stroke="rgb(39,170,225)" stroke-width="0.5px">
                <path id="Capline-S" d="M18,76 l800,0" />
                <path id="H-reference"
                    d="M85,145.755 L87.685,145.755 L113.369,79.287 L114.052002,79.287
                       L114.052002,76 L112.148,76 L85,145.755 Z
                       M95.693,121.536 L130.996,121.536 L130.263,119.313 L96.474,119.313 L95.693,121.536 Z
                       M139.14999,145.755 L141.787,145.755 L114.638,76 L113.466,76 L113.466,79.287 L139.14999,145.755 Z" stroke="none" />
                <path id="Baseline-S" d="M18,146 l800,0" />

                <path id="left-margin-Ultralight-S" d="M221,56 l0,110" />
                <path id="right-margin-Ultralight-S" d="M309,56 l0,110" />

                <path id="left-margin-Regular-S" d="M421,56 l0,110" />
                <path id="right-margin-Regular-S" d="M509,56 l0,110" />

                <path id="left-margin-Black-S" d="M621,56 l0,110" />
                <path id="right-margin-Black-S" d="M709,56 l0,110" />

                <path id="Capline-M" d="M18,276 l800,0" />
                <path id="Baseline-M" d="M18,346 l800,0" />

                <path id="Capline-L" d="M18,476 l800,0" />
                <path id="Baseline-L" d="M18,546 l800,0" />
            </g>

            <g id="Symbols">
                <g id="Ultralight-S">
                    <!-- Insert Contents -->
                </g>
                <g id="Regular-S">
                    <!-- Insert Contents -->
                </g>
                <g id="Black-S">
                    <!-- Insert Contents -->
                </g>
            </g>
        </svg>
        """

        let element = try XML.SAXParser.parse(data: svg.data(using: .utf8)!)
        let parser = XMLParser(options: [], filename: "template.svg")
        return try parser.parseSVG(element)
    }
}

private extension LayerTree.Rect {
    static let ultralight = Self(x: 221, y: 76, width: 88, height: 70)
    static let regular = Self(x: 421, y: 76, width: 88, height: 70)
    static let black = Self(x: 621, y: 76, width: 88, height: 70)
}

private extension ContainerElement {

    func group(id: String) throws -> DOM.Group {
        for e in childElements {
            if e.id == id, let group = e as? DOM.Group {
                return group
            }
        }
        throw ContainerError.missingGroup
    }
}

enum ContainerError: Error {
    case missingGroup
}
