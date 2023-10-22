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

public struct SFSymbolRenderer {

    private let options: SVG.Options
    private let insets: CommandLine.Insets
    private let insetsUltralight: CommandLine.Insets
    private let insetsBlack: CommandLine.Insets
    private let formatter: CoordinateFormatter

    public init(options: SVG.Options,
                insets: CommandLine.Insets,
                insetsUltralight: CommandLine.Insets,
                insetsBlack: CommandLine.Insets,
                precision: Int) {
        self.options = options
        self.insets = insets
        self.insetsUltralight = insetsUltralight
        self.insetsBlack = insetsBlack
        self.formatter = CoordinateFormatter(delimeter: .comma,
                                             precision: .capped(max: precision))
    }

    public func render(regular: URL, ultralight: URL?, black: URL?) throws -> String {
        let regular = try DOM.SVG.parse(fileURL: regular)
        let ultralight = try ultralight.map { try DOM.SVG.parse(fileURL: $0) }
        let black = try black.map { try DOM.SVG.parse(fileURL: $0) }
        return try render(default: regular, ultralight: ultralight, black: black)
    }

    func render(default image: DOM.SVG, ultralight: DOM.SVG?, black: DOM.SVG?) throws -> String {
        guard let pathsRegular = Self.getPaths(for: image) else {
            throw Error("No valid content found.")
        }
        var template = try SFSymbolTemplate.make()

        template.svg.styles = image.styles.map(makeSymbolStyleSheet)

        let boundsRegular = try makeBounds(svg: image, auto: Self.makeBounds(for: pathsRegular), for: .regular)
        template.regular.appendPaths(pathsRegular, from: boundsRegular)

        if let ultralight = ultralight,
           let paths = Self.getPaths(for: ultralight) {
            let bounds = try makeBounds(svg: ultralight, auto: Self.makeBounds(for: paths), for: .ultralight)
            template.ultralight.appendPaths(paths, from: bounds)
        } else {
            let bounds = try makeBounds(svg: image, auto: Self.makeBounds(for: pathsRegular), for: .ultralight)
            template.ultralight.appendPaths(pathsRegular, from: bounds)
        }

        if let black = black,
           let paths = Self.getPaths(for: black) {
            let bounds = try makeBounds(svg: black, auto: Self.makeBounds(for: paths), for: .black)
            template.black.appendPaths(paths, from: bounds)
        } else {
            let bounds = try makeBounds(svg: image, auto: Self.makeBounds(for: pathsRegular), for: .black)
            template.black.appendPaths(pathsRegular, from: bounds)
        }

        let element = try XML.Formatter.SVG(formatter: formatter).makeElement(from: template.svg)
        let formatter = XML.Formatter(spaces: 4)
        let result = formatter.encodeRootElement(element)
        return result
    }

    func makeSymbolStyleSheet(from stylesheet: DOM.StyleSheet) -> DOM.StyleSheet {
        var copy = stylesheet
        for selector in stylesheet.attributes.keys {
            switch selector {
            case .class(let name):
                if SFSymbolRenderer.containsAcceptedName(name) {
                    copy.attributes[selector] = stylesheet.attributes[selector]
                }
            case .id, .element:
                ()
            }
        }
        return copy
    }

    static func containsAcceptedName(_ string: String?) -> Bool {
        guard let string = string else { return false }
        return string.contains("hierarchical-") ||
        string.contains("monochrome-") ||
        string.contains("multicolor-") ||
        string.contains("SFSymbolsPreview")
    }
}

extension SFSymbolRenderer {

    enum Variant: String {
        case regular
        case ultralight
        case black
    }

    func getInsets(for variant: Variant) -> CommandLine.Insets {
        switch variant {
        case .regular:
            return insets
        case .ultralight:
            return insetsUltralight
        case .black:
            return insetsBlack
        }
    }

    func makeBounds(svg: DOM.SVG, auto: LayerTree.Rect, for variant: Variant) throws -> LayerTree.Rect {
        let insets = getInsets(for: variant)
        let width = LayerTree.Float(svg.width)
        let height = LayerTree.Float(svg.height)
        let top = insets.top ?? Double(auto.minY)
        let left = insets.left ?? Double(auto.minX)
        let bottom = insets.bottom ?? Double(height - auto.maxY)
        let right = insets.right ?? Double(width - auto.maxX)

        Self.printInsets(top: top, left: left, bottom: bottom, right: right, variant: variant)
        guard !insets.isEmpty else {
            return auto
        }
        let bounds = LayerTree.Rect(
            x: LayerTree.Float(left),
            y: LayerTree.Float(top),
            width: width - LayerTree.Float(left + right),
            height: height - LayerTree.Float(top + bottom)
        )
        guard bounds.width > 0 && bounds.height > 0 else {
            throw Error("Invalid insets")
        }
        return bounds
    }

    static func getPaths(for svg: DOM.SVG) -> [SymbolPath]? {
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let paths = getSymbolPaths(for: layer)
        return paths.isEmpty ? nil : paths
    }

    struct SymbolPath {
        var `class`: String?
        var path: LayerTree.Path
    }

    static func getSymbolPaths(for layer: LayerTree.Layer,
                               ctm: LayerTree.Transform.Matrix = .identity) -> [SymbolPath] {

        let isSFSymbolLayer = containsAcceptedName(layer.class)
        guard isSFSymbolLayer || layer.opacity > 0 else { return [] }
        guard layer.clip.isEmpty else {
            print("Warning:", "clip-path unsupported in SF Symbols.", to: &.standardError)
            return []
        }
        guard layer.mask == nil else {
            print("Warning:", "mask unsupported in SF Symbols.", to: &.standardError)
            return []
        }

        let ctm = ctm.concatenated(layer.transform.toMatrix())
        var paths = [SymbolPath]()

        let symbolClass = isSFSymbolLayer ? layer.class : nil

        for c in layer.contents {
            switch c {
            case let .shape(shape, stroke, fill):

                if let fillPath = makeFillPath(for: shape, fill: fill, preserve: isSFSymbolLayer) {
                    if fill.rule == .evenodd {
                        paths.append(SymbolPath(class: symbolClass, path: fillPath.applying(matrix: ctm).makeNonZero()))
                    } else {
                        paths.append(SymbolPath(class: symbolClass, path: fillPath.applying(matrix: ctm)))
                    }
                } else if let strokePath = makeStrokePath(for: shape, stroke: stroke, preserve: isSFSymbolLayer) {
                    paths.append(SymbolPath(class: symbolClass, path: strokePath.applying(matrix: ctm)))
                }

            case let .text(text, point, attributes):
                if let path = makePath(for: text, at: point, with: attributes) {
                    paths.append(SymbolPath(class: symbolClass, path: path.applying(matrix: ctm)))
                }
            case .layer(let l):
                paths.append(contentsOf: getSymbolPaths(for: l, ctm: ctm))
            default:
                ()
            }
        }

        return paths
    }

    static func makeFillPath(for shape: LayerTree.Shape,
                             fill: LayerTree.FillAttributes,
                             preserve: Bool) -> LayerTree.Path? {
        if preserve || (fill.fill != .none && fill.opacity > 0) {
            return shape.path
        }
        return nil
    }

    static func makeStrokePath(for shape: LayerTree.Shape,
                               stroke: LayerTree.StrokeAttributes,
                               preserve: Bool) -> LayerTree.Path? {
        if preserve || (stroke.color != .none && stroke.width > 0) {
#if canImport(CoreGraphics)
            return expandOutlines(for: shape.path, stroke: stroke)
#else
            print("Warning:", "expanding stroke outlines requires macOS.", to: &.standardError)
            return nil
#endif
        }

        return nil
    }

    static func makePath(for text: String,
                         at point: LayerTree.Point,
                         with attributes: LayerTree.TextAttributes) -> LayerTree.Path? {
#if canImport(CoreGraphics)
        let cgPath = CGProvider().createPath(from: text, at: point, with: attributes)
        return cgPath?.makePath()
#else
        print("Warning:", "expanding text outlines requires macOS.", to: &.standardError)
        return nil
#endif
    }

    static func makeBounds(for paths: [SymbolPath]) -> LayerTree.Rect {
        var min = LayerTree.Point.maximum
        var max = LayerTree.Point.minimum
        for p in paths {
            let bounds = p.path.bounds
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

    static func makeTransformation(from source: LayerTree.Rect,
                                   to destination: LayerTree.Rect) -> LayerTree.Transform.Matrix {
        let scale = min(destination.width / source.width, destination.height / source.height)
        let scaleMidX = source.midX * scale
        let scaleMidY = source.midY * scale
        let tx = destination.midX - scaleMidX
        let ty =  destination.midY - scaleMidY
        let t = LayerTree.Transform
            .translate(tx: tx, ty: ty)
        return LayerTree.Transform
            .scale(sx: scale, sy: scale)
            .toMatrix()
            .concatenated(t.toMatrix())
    }

    static func convertPaths(_ paths: [LayerTree.Path],
                             from source: LayerTree.Rect,
                             to destination: LayerTree.Rect) -> [DOM.Path] {
        let matrix = makeTransformation(from: source, to: destination)
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

    static func printInsets(top: Double, left: Double, bottom: Double, right: Double, variant: Variant) {
        let formatter = NumberFormatter()
        formatter.locale = .init(identifier: "en_US")
        formatter.maximumFractionDigits = 4
        let top = formatter.string(from: top as NSNumber)!
        let left = formatter.string(from: left as NSNumber)!
        let bottom = formatter.string(from: bottom as NSNumber)!
        let right = formatter.string(from: right as NSNumber)!

        switch variant {
        case .regular:
            print("Alignment: --insets \(top),\(left),\(bottom),\(right)")
        case .ultralight:
            print("Alignment: --ultralightInsets \(top),\(left),\(bottom),\(right)")
        case .black:
            print("Alignment: --blackInsets \(top),\(left),\(bottom),\(right)")
        }
    }

    struct Error: LocalizedError {
        var errorDescription: String?

        init(_ message: String) {
            self.errorDescription = message
        }
    }
}

struct SFSymbolTemplate {

    let svg: DOM.SVG

    var ultralight: Variant
    var regular: Variant
    var black: Variant

    init(svg: DOM.SVG) throws {
        self.svg = svg
        self.ultralight = try Variant(svg: svg, kind: "Ultralight")
        self.regular = try Variant(svg: svg, kind: "Regular")
        self.black = try Variant(svg: svg, kind: "Black")
    }

    struct Variant {
        var left: Guide
        var contents: Contents
        var right: Guide

        init(svg: DOM.SVG, kind: String) throws {
            let guides = try svg.group(id: "Guides")
            let symbols = try svg.group(id: "Symbols")
            self.left = try Guide(guides.path(id: "left-margin-\(kind)-S"))
            self.contents = try Contents(symbols.group(id: "\(kind)-S"))
            self.right = try Guide(guides.path(id: "right-margin-\(kind)-S"))
        }

        var bounds: LayerTree.Rect {
            let minX = left.x
            let maxX = right.x
            return .init(x: minX, y: 76, width: maxX - minX, height: 70)
        }
    }

    struct Guide {
        private let path: DOM.Path

        init(_ path: DOM.Path) {
            self.path = path
        }

        var x: DOM.Float {
            get {
                guard case let .move(x, _, _) = path.segments[0] else {
                    fatalError()
                }
                return x
            }
            set {
                guard case let .move(_, y, space) = path.segments[0] else {
                    fatalError()
                }
                path.segments[0] = .move(x: newValue, y: y, space: space)
            }
        }
    }

    struct Contents {
        private let group: DOM.Group

        init(_ group: DOM.Group) {
            self.group = group
        }

        var paths: [DOM.Path] {
            get {
                group.childElements as! [DOM.Path]
            }
            set {
                group.childElements = newValue
            }
        }
    }
}

extension SFSymbolTemplate {

    static func parse(_ text: String) throws -> Self {
        let element = try XML.SAXParser.parse(data: text.data(using: .utf8)!)
        let parser = XMLParser(options: [], filename: "template.svg")
        let svg = try parser.parseSVG(element)
        return try SFSymbolTemplate(svg: svg)
    }

    static func make() throws -> Self {
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
                 <text id="template-version" fill="#505050" x="785.0" y="575.0" text-anchor="end">Template v.3.0</text>
                 <a href="https://github.com/swhitty/SwiftDraw">
                    <text fill="#505050" x="785.0" y="590.0" text-anchor="end">https://github.com/swhitty/SwiftDraw</text>
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
        return try .parse(svg)
    }
}

private extension ContainerElement {

    func group(id: String) throws -> DOM.Group {
        try child(id: id, of: DOM.Group.self)
    }

    func path(id: String) throws -> DOM.Path {
        try child(id: id, of: DOM.Path.self)
    }

    private func child<T>(id: String, of type: T.Type) throws -> T {
        for e in childElements {
            if e.id == id, let match = e as? T {
                return match
            }
        }
        throw ContainerError.missingElement(String(describing: T.self))
    }
}

private extension SFSymbolTemplate.Variant {

    mutating func appendPaths(_ paths: [SFSymbolRenderer.SymbolPath], from source: LayerTree.Rect) {
        let matrix = SFSymbolRenderer.makeTransformation(from: source, to: bounds)
        contents.paths = paths
            .map {
                let transformed = $0.path.applying(matrix: matrix)
                let dom = SFSymbolRenderer.makeDOMPath(for: transformed)
                dom.class = $0.class
                return dom
            }

        let midX = bounds.midX
        let newWidth = ((source.width * matrix.a) / 2) + 10
        left.x = min(left.x, midX - newWidth)
        right.x = max(right.x, midX + newWidth)
    }
}

private enum ContainerError: Error {
    case missingElement(String)
}

private extension DOM.Path {
    var x: DOM.Float {
        get {
            guard case let .move(x, _, _) = segments[0] else {
                fatalError()
            }
            return x
        }
        set {
            guard case let .move(_, y, space) = segments[0] else {
                fatalError()
            }
            segments[0] = .move(x: newValue, y: y, space: space)
        }
    }
}
