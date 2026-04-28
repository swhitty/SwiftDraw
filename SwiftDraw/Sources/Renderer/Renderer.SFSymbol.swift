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

import SwiftDrawDOM
public import Foundation

public struct SFSymbolRenderer {

    private let size: SizeCategory
    private let options: SVG.Options
    private let insets: CommandLine.Insets
    private let insetsUltralight: CommandLine.Insets
    private let insetsBlack: CommandLine.Insets
    private let formatter: CoordinateFormatter
    private let isLegacyInsets: Bool

    public enum SizeCategory {
        case small
        case medium
        case large
    }

    public init(
        size: SizeCategory,
        options: SVG.Options,
        insets: CommandLine.Insets,
        insetsUltralight: CommandLine.Insets,
        insetsBlack: CommandLine.Insets,
        precision: Int,
        isLegacyInsets: Bool
    ) {
        self.size = size
        self.options = options
        self.insets = insets
        self.insetsUltralight = insetsUltralight
        self.insetsBlack = insetsBlack
        self.formatter = CoordinateFormatter(
            delimeter: .comma,
            precision: .capped(max: precision)
        )
        self.isLegacyInsets = isLegacyInsets
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

        let boundsRegular = try makeBounds(svg: image, auto: Self.makeAutoBounds(for: pathsRegular, isLegacy: isLegacyInsets), for: .regular)
        template.regular.appendPaths(pathsRegular, from: boundsRegular, isLegacy: isLegacyInsets)

        if let ultralight = ultralight,
           let paths = Self.getPaths(for: ultralight) {
            let bounds = try makeBounds(svg: ultralight, isRegularSVG: false, auto: Self.makeAutoBounds(for: paths, isLegacy: isLegacyInsets), for: .ultralight)
            template.ultralight.appendPaths(paths, from: bounds, isLegacy: isLegacyInsets)
        } else {
            let bounds = try makeBounds(svg: image, auto: Self.makeAutoBounds(for: pathsRegular, isLegacy: isLegacyInsets), for: .ultralight)
            template.ultralight.appendPaths(pathsRegular, from: bounds, isLegacy: isLegacyInsets)
        }

        if let black = black,
           let paths = Self.getPaths(for: black) {
            let bounds = try makeBounds(svg: black, isRegularSVG: false, auto: Self.makeAutoBounds(for: paths, isLegacy: isLegacyInsets), for: .black)
            template.black.appendPaths(paths, from: bounds, isLegacy: isLegacyInsets)
        } else {
            let bounds = try makeBounds(svg: image, auto: Self.makeAutoBounds(for: pathsRegular, isLegacy: isLegacyInsets), for: .black)
            template.black.appendPaths(pathsRegular, from: bounds, isLegacy: isLegacyInsets)
        }

        template.normalizeVariants()
        template.setSize(size)

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

    func makeBounds(svg: DOM.SVG, isRegularSVG: Bool = true, auto: LayerTree.Rect, for variant: Variant) throws -> LayerTree.Rect {
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

        if !layer.clip.isEmpty {
            paths = applyClip(to: paths,
                              clipShapes: layer.clip,
                              clipRule: layer.clipRule,
                              clipUnits: layer.clipUnits,
                              ctm: ctm)
        }

        return paths
    }

    static func applyClip(to paths: [SymbolPath],
                          clipShapes: [LayerTree.ClipShape],
                          clipRule: LayerTree.FillRule?,
                          clipUnits: LayerTree.ClipUnits,
                          ctm: LayerTree.Transform.Matrix) -> [SymbolPath] {
#if canImport(CoreGraphics)
        var result = [SymbolPath]()
        result.reserveCapacity(paths.count)
        for symbolPath in paths {
            if let clipped = intersect(path: symbolPath.path,
                                       with: clipShapes,
                                       clipRule: clipRule,
                                       clipUnits: clipUnits,
                                       clipCTM: ctm) {
                result.append(SymbolPath(class: symbolPath.class, path: clipped))
            }
        }
        return result
#else
        print("Warning:", "clip-path requires CoreGraphics.", to: &.standardError)
        return paths
#endif
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

    static func makeAutoBounds(for paths: [SymbolPath], isLegacy: Bool = false) -> LayerTree.Rect {
        var min = LayerTree.Point.maximum
        var max = LayerTree.Point.minimum
        for p in paths {
            let bounds = p.path.bounds
            min = min.minimum(combining: .init(bounds.minX, bounds.minY))
            max = max.maximum(combining: .init(bounds.maxX, bounds.maxY))
        }

        if !isLegacy {
            min.x -= 10
            max.x += 10
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
            print("Alignment: --ultralight-insets \(top),\(left),\(bottom),\(right)")
        case .black:
            print("Alignment: --black-insets \(top),\(left),\(bottom),\(right)")
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

    var typeReference: DOM.Path
    var ultralight: Variant
    var regular: Variant
    var black: Variant

    init(svg: DOM.SVG) throws {
        self.svg = svg
        self.typeReference = try svg.group(id: "Guides").path(id: "H-reference")
        self.ultralight = try Variant(svg: svg, kind: "Ultralight")
        self.regular = try Variant(svg: svg, kind: "Regular")
        self.black = try Variant(svg: svg, kind: "Black")
    }

    /// Normalizes path segments across all three weight variants so they are interpolatable.
    /// Handles two cases:
    /// 1. Different segment counts: inserts degenerate cubics to align paths
    /// 2. Same count but different types: promotes lines to degenerate cubics
    mutating func normalizeVariants() {
        let pathCount = min(ultralight.contents.paths.count,
                            regular.contents.paths.count,
                            black.contents.paths.count)
        for i in 0..<pathCount {
            Self.normalizeSegments(
                &ultralight.contents.paths[i].segments,
                &regular.contents.paths[i].segments,
                &black.contents.paths[i].segments
            )
        }
    }

    static func normalizeSegments(
        _ a: inout [DOM.Path.Segment],
        _ b: inout [DOM.Path.Segment],
        _ c: inout [DOM.Path.Segment]
    ) {
        // Phase 1: Align segment counts by inserting degenerate segments
        alignSegmentCounts(&a, &b, &c)

        // Phase 2: Promote lines to cubics where types differ
        guard a.count == b.count && b.count == c.count else { return }
        promoteLinesToCubics(&a, &b, &c)
    }

    /// Walks through three segment arrays simultaneously, inserting degenerate cubic
    /// segments where one variant has an extra segment the others don't.
    private static func alignSegmentCounts(
        _ a: inout [DOM.Path.Segment],
        _ b: inout [DOM.Path.Segment],
        _ c: inout [DOM.Path.Segment]
    ) {
        var ia = 0, ib = 0, ic = 0
        var curA = (x: DOM.Coordinate(0), y: DOM.Coordinate(0))
        var curB = (x: DOM.Coordinate(0), y: DOM.Coordinate(0))
        var curC = (x: DOM.Coordinate(0), y: DOM.Coordinate(0))

        while ia < a.count && ib < b.count && ic < c.count {
            let ta = a[ia].commandType
            let tb = b[ib].commandType
            let tc = c[ic].commandType

            if ta == tb && tb == tc {
                curA = a[ia].endPoint ?? curA
                curB = b[ib].endPoint ?? curB
                curC = c[ic].endPoint ?? curC
                ia += 1; ib += 1; ic += 1
                continue
            }

            // Check if one variant has an extra segment. Try skipping each one
            // to see if it restores alignment with the other two.
            if tb == tc, ia + 1 < a.count, a[ia + 1].commandType == tb {
                // a has extra segment at ia; insert degenerate in b and c
                b.insert(degenerateCubic(at: curB), at: ib)
                c.insert(degenerateCubic(at: curC), at: ic)
                curA = a[ia].endPoint ?? curA
                ia += 1; ib += 1; ic += 1
                continue
            }
            if ta == tc, ib + 1 < b.count, b[ib + 1].commandType == ta {
                a.insert(degenerateCubic(at: curA), at: ia)
                c.insert(degenerateCubic(at: curC), at: ic)
                curB = b[ib].endPoint ?? curB
                ia += 1; ib += 1; ic += 1
                continue
            }
            if ta == tb, ic + 1 < c.count, c[ic + 1].commandType == ta {
                a.insert(degenerateCubic(at: curA), at: ia)
                b.insert(degenerateCubic(at: curB), at: ib)
                curC = c[ic].endPoint ?? curC
                ia += 1; ib += 1; ic += 1
                continue
            }

            // No simple alignment found, just advance all
            curA = a[ia].endPoint ?? curA
            curB = b[ib].endPoint ?? curB
            curC = c[ic].endPoint ?? curC
            ia += 1; ib += 1; ic += 1
        }
    }

    /// Promotes line segments to degenerate cubics where variants disagree on type.
    private static func promoteLinesToCubics(
        _ a: inout [DOM.Path.Segment],
        _ b: inout [DOM.Path.Segment],
        _ c: inout [DOM.Path.Segment]
    ) {
        var curA = (x: DOM.Coordinate(0), y: DOM.Coordinate(0))
        var curB = (x: DOM.Coordinate(0), y: DOM.Coordinate(0))
        var curC = (x: DOM.Coordinate(0), y: DOM.Coordinate(0))

        for i in 0..<a.count {
            let sa = a[i], sb = b[i], sc = c[i]

            if sa.commandType != sb.commandType || sb.commandType != sc.commandType {
                let hasCubic = sa.isCubic || sb.isCubic || sc.isCubic
                let allLineOrCubic = (sa.isLine || sa.isCubic) && (sb.isLine || sb.isCubic) && (sc.isLine || sc.isCubic)

                if hasCubic && allLineOrCubic {
                    if sa.isLine { a[i] = sa.promoteToCubic(from: curA) }
                    if sb.isLine { b[i] = sb.promoteToCubic(from: curB) }
                    if sc.isLine { c[i] = sc.promoteToCubic(from: curC) }
                }
            }

            curA = a[i].endPoint ?? curA
            curB = b[i].endPoint ?? curB
            curC = c[i].endPoint ?? curC
        }
    }

    private static func degenerateCubic(at point: (x: DOM.Coordinate, y: DOM.Coordinate)) -> DOM.Path.Segment {
        .cubic(x1: point.x, y1: point.y, x2: point.x, y2: point.y, x: point.x, y: point.y, space: .absolute)
    }

    mutating func setSize(_ size: SFSymbolRenderer.SizeCategory) {
        typeReference.attributes.transform = [.translate(tx: 0, ty: size.yOffset)]
        ultralight.setSize(size)
        regular.setSize(size)
        black.setSize(size)
    }

    struct Variant {
        var left: Guide
        var contents: Contents
        var right: Guide
        private var kind: String

        init(svg: DOM.SVG, kind: String) throws {
            let guides = try svg.group(id: "Guides")
            let symbols = try svg.group(id: "Symbols")
            self.kind = kind
            self.left = try Guide(guides.path(id: "left-margin-\(kind)-S"))
            self.contents = try Contents(symbols.group(id: "\(kind)-S"))
            self.right = try Guide(guides.path(id: "right-margin-\(kind)-S"))
        }

        var bounds: LayerTree.Rect {
            let minX = left.x
            let maxX = right.x
            return .init(x: minX, y: 76, width: maxX - minX, height: 70)
        }

        mutating func setSize(_ size: SFSymbolRenderer.SizeCategory) {
            left.setID("left-margin-\(kind)-\(size.name)")
            left.y += size.yOffset
            contents.setID("\(kind)-\(size.name)")
            contents.setTransform(.translate(tx: 0, ty: size.yOffset))
            right.setID("right-margin-\(kind)-\(size.name)")
            right.y += size.yOffset
        }
    }

    struct Guide {
        private let path: DOM.Path

        init(_ path: DOM.Path) {
            self.path = path
        }

        func setID(_ id: String) {
            path.id = id
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

        var y: DOM.Float {
            get {
                guard case let .move(_, y, _) = path.segments[0] else {
                    fatalError()
                }
                return y
            }
            set {
                guard case let .move(x, _, space) = path.segments[0] else {
                    fatalError()
                }
                path.segments[0] = .move(x: x, y: newValue, space: space)
            }
        }
    }

    struct Contents {
        private let group: DOM.Group

        init(_ group: DOM.Group) {
            self.group = group
        }

        func setID(_ id: String) {
            group.id = id
        }

        var paths: [DOM.Path] {
            get {
                group.childElements as! [DOM.Path]
            }
            set {
                group.childElements = newValue
            }
        }

        func setTransform(_ transform: DOM.Transform) {
            group.attributes.transform = [transform]
        }
    }
}

extension SFSymbolRenderer.SizeCategory {

    var name: String {
        switch self {
        case .small: 
            return "S"
        case .medium:
            return "M"
        case .large:
            return "L"
        }
    }

    var yOffset: Float {
        switch self {
        case .small:
            return 0
        case .medium:
            return 200
        case .large:
            return 400
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

    mutating func appendPaths(_ paths: [SFSymbolRenderer.SymbolPath], from source: LayerTree.Rect, isLegacy: Bool = false) {
        let matrix = SFSymbolRenderer.makeTransformation(from: source, to: bounds)
        contents.paths = paths
            .map {
                let transformed = $0.path.applying(matrix: matrix)
                let dom = SFSymbolRenderer.makeDOMPath(for: transformed)
                dom.class = $0.class
                return dom
            }

        let midX = bounds.midX
        if isLegacy {
            // preserve behaviour from earlier SwiftDraw versions with --legacy option
            let newWidth = ((source.width * matrix.a) / 2) + 10
            left.x = min(left.x, midX - newWidth)
            right.x = max(right.x, midX + newWidth)
        } else {
            let newWidth = ((source.width * matrix.a) / 2)
            left.x = midX - newWidth
            right.x = midX + newWidth
        }
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

extension DOM.Path.Segment {

    enum CommandType: Equatable {
        case move, line, cubic, close, other
    }

    var commandType: CommandType {
        switch self {
        case .move: return .move
        case .line, .horizontal, .vertical: return .line
        case .cubic, .cubicSmooth: return .cubic
        case .close: return .close
        default: return .other
        }
    }

    var isLine: Bool { commandType == .line }
    var isCubic: Bool { commandType == .cubic }

    var endPoint: (x: DOM.Coordinate, y: DOM.Coordinate)? {
        switch self {
        case .move(let x, let y, _), .line(let x, let y, _):
            return (x, y)
        case .cubic(_, _, _, _, let x, let y, _):
            return (x, y)
        case .horizontal(let x, _):
            return (x, 0) // y stays same, caller tracks
        case .vertical(let y, _):
            return (0, y) // x stays same, caller tracks
        default:
            return nil
        }
    }

    /// Promotes a line segment to a degenerate cubic curve.
    /// The control points are placed at the start and end to create a straight line.
    func promoteToCubic(from current: (x: DOM.Coordinate, y: DOM.Coordinate)) -> DOM.Path.Segment {
        guard let end = endPoint else { return self }
        return .cubic(x1: current.x, y1: current.y, x2: end.x, y2: end.y, x: end.x, y: end.y, space: .absolute)
    }
}
