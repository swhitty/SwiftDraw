//
//  Parser.XML.SVG.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright 2020 Simon Whitty
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

package extension XMLParser {

    func parseSVG(_ e: XML.Element) throws -> DOM.SVG {
        guard e.name == "svg" else {
            throw Error.invalid
        }

        let att = try parseAttributes(e)
        let widthRaw = try? att.parseString("width")
        let heightRaw = try? att.parseString("height")
        let viewBox: DOM.SVG.ViewBox? = try parseViewBox(try att.parseString("viewBox"))

        let isRoot = lengthContext.viewports.isEmpty
        let styles = parseStyleSheetElements(within: e)
        if isRoot {
            // selectors are matched against the whole document tree before its elements are parsed
            styleContext.matcher = DOM.StyleSheet.Matcher(sheets: styles, root: e)
            lengthContext.fontSize = rootFontSize(e)
            lengthContext.symbolViewports = makeSymbolUseSizes(within: e)
            referenceContext.firstWithID = Self.firstElementsWithID(within: e)
        }
        defer {
            if isRoot {
                styleContext.matcher = nil
                lengthContext.symbolViewports = [:]
                referenceContext.firstWithID = []
                referenceContext.elements = [:]
            }
        }

        let svg: DOM.SVG
        if let parent = lengthContext.viewports.last {
            // SVG 1.1 §7.9: a nested <svg> resolves its percentages against the enclosing viewport,
            // and a missing (or invalid) width or height is 100%
            let (width, height) = nestedSize(widthRaw: widthRaw, heightRaw: heightRaw, parent: parent)
            svg = DOM.SVG(width: width, height: height)
            svg.x = parseDefaultedLength(att, "x", .horizontal)
            svg.y = parseDefaultedLength(att, "y", .vertical)
        } else {
            var width = try resolveRootDimension(widthRaw, viewport: defaultViewport?.width, attribute: "width")
            var height = try resolveRootDimension(heightRaw, viewport: defaultViewport?.height, attribute: "height")

            // only one side given: the other follows the viewBox's aspect ratio (SVG 2 §8.2, CSS
            // replaced elements with an intrinsic ratio), as in Chrome and Safari
            if let viewBox, viewBox.width > 0, viewBox.height > 0 {
                if let w = width, height == nil {
                    height = w * viewBox.height / viewBox.width
                } else if let h = height, width == nil {
                    width = h * viewBox.width / viewBox.height
                }
            }

            width = width ?? viewBox?.width ?? defaultViewport?.width
            height = height ?? viewBox?.height ?? defaultViewport?.height

            guard let w = width else {
                throw XMLParser.Error.unresolvableDimension(
                    reason: makeUnresolvedReason(attribute: "width", raw: widthRaw, hasViewBox: viewBox != nil)
                )
            }
            guard let h = height else {
                throw XMLParser.Error.unresolvableDimension(
                    reason: makeUnresolvedReason(attribute: "height", raw: heightRaw, hasViewBox: viewBox != nil)
                )
            }

            // fractional sizes are kept, but a size past Int (or infinite or NaN) is rejected:
            // callers make pixel buffers from it, and Int(size) traps
            guard DOM.Length(exactly: w.rounded(.towardZero)) != nil else {
                throw Error.invalidAttribute(name: "width", value: widthRaw ?? "\(w)")
            }
            guard DOM.Length(exactly: h.rounded(.towardZero)) != nil else {
                throw Error.invalidAttribute(name: "height", value: heightRaw ?? "\(h)")
            }

            svg = DOM.SVG(width: w, height: h)
            svg.x = try att.parseCoordinate("x")
            svg.y = try att.parseCoordinate("y")
        }

        lengthContext.viewports.append(Self.contentViewport(viewBox: viewBox, width: svg.width, height: svg.height))
        defer { lengthContext.viewports.removeLast() }

        svg.childElements = try parseGraphicsElements(e.children)
        svg.viewBox = viewBox
        svg.preserveAspectRatio = parsePreserveAspectRatio(try? att.parseString("preserveAspectRatio"))

        svg.defs = try parseSVGDefs(e)
        svg.styles = styles

        // attributes and style="" stay separate so stylesheet rules fall between them
        svg.attributes = try parsePresentationAttributes(e)
        applyStyle(of: e, to: svg)
        parseConditionalAttributes(att, into: svg)

        if isRoot {
            try parseUnreachedElements(within: e)
            svg.elementsByID = referenceContext.elements
        }

        return svg
    }

    /// The XML elements that are the first in the document with their id: as `getElementById`,
    /// a `<use>` references only the first, whatever its kind.
    static func firstElementsWithID(within root: XML.Element) -> Set<ObjectIdentifier> {
        var seen = Set<String>()
        var first = Set<ObjectIdentifier>()
        var stack = [root]
        while let element = stack.popLast() {
            if let id = element.attributes["id"], seen.insert(id).inserted {
                first.insert(ObjectIdentifier(element))
            }
            stack.append(contentsOf: element.children.reversed())
        }
        return first
    }

    /// Parses the graphics elements no other walk reaches, so a `<use>` can still reference them:
    /// those inside elements that are not rendered and are not containers, such as an unknown
    /// element (as Chrome and resvg). Each element is parsed at most once more.
    func parseUnreachedElements(within root: XML.Element) throws {
        // elements whose children are parsed as graphics elements by the other walks
        let walked: Set<String> = [
            "svg", "g", "a", "switch", "symbol", "defs", "clipPath", "mask", "pattern", "marker",
        ]
        var stack: [(element: XML.Element, reached: Bool)] = root.children.reversed().map { ($0, true) }
        while let (element, reached) = stack.popLast() {
            try Task.checkCancellation()
            if reached {
                // text holds no graphics elements, and leaves no children
                if walked.contains(element.name) {
                    stack.append(contentsOf: element.children.reversed().map { ($0, true) })
                } else if !Self.graphicsElementNames.contains(element.name) {
                    stack.append(contentsOf: element.children.reversed().map { ($0, false) })
                }
            } else if walked.contains(element.name) && !Self.graphicsElementNames.contains(element.name) {
                // <defs>, <clipPath>, <mask>, <pattern> and <marker> are found anywhere in the document
                stack.append(contentsOf: element.children.reversed().map { ($0, true) })
            } else if Self.graphicsElementNames.contains(element.name),
                referenceContext.firstWithID.contains(ObjectIdentifier(element))
            {
                // parses (and registers) its subtree too
                _ = try parseGraphicsElements([element])
            } else if element.name != "text" {
                stack.append(contentsOf: element.children.reversed().map { ($0, false) })
            }
        }
    }

    /// The elements `parseGraphicsElement(_:)` parses.
    static let graphicsElementNames: Set<String> = [
        "g", "line", "circle", "ellipse", "rect", "polyline", "polygon", "path", "text",
        "a", "use", "switch", "image", "svg", "symbol",
    ]

    func parseViewBox(_ data: String?) throws -> DOM.SVG.ViewBox? {
        guard let data = data else { return nil }
        var scanner = XMLParser.Scanner(text: data)

        let x = try scanner.scanViewBoxCoordinate()
        let y = try scanner.scanViewBoxCoordinate()
        let width = try scanner.scanViewBoxCoordinate()
        let height = try scanner.scanCoordinate()

        guard scanner.isEOF else {
            throw Error.invalid
        }

        return DOM.SVG.ViewBox(x: x, y: y, width: width, height: height)
    }

    // Returns nil when raw is missing, or when a percent value has no viewport to resolve against
    func resolveRootDimension(_ raw: String?, viewport: DOM.Coordinate?, attribute: String) throws -> DOM.Coordinate? {
        guard let raw, !raw.isEmpty else { return nil }
        var scanner = XMLParser.Scanner(text: raw)
        scanner.scanner.currentIndex = scanner.currentIndex
        guard let number = scanner.scanner.scanDoubleCompatibly() else {
            throw Error.invalidAttribute(name: attribute, value: raw)
        }
        scanner.currentIndex = scanner.scanner.currentIndex

        if scanner.scanStringIfPossible("%") {
            guard let viewport else { return nil }
            return DOM.Coordinate(number / 100) * viewport
        }
        if let unit = scanner.scanUnit() {
            guard scanner.isEOF else {
                throw Error.invalidAttribute(name: attribute, value: raw)
            }
            switch unit {
            case .em:
                return DOM.Coordinate(number) * lengthContext.fontSize
            case .ex:
                return DOM.Coordinate(number) * lengthContext.fontSize / 2
            default:
                return DOM.Coordinate(number.apply(unit: unit))
            }
        }
        guard scanner.isEOF else {
            throw Error.invalidAttribute(name: attribute, value: raw)
        }
        return DOM.Coordinate(number)
    }

    // the font-size of the root <svg> for its own `em` sizes and those of its contents
    func rootFontSize(_ e: XML.Element) -> DOM.Float {
        fontSize(
            attributes: (try? parsePresentationAttributes(e)) ?? DOM.PresentationAttributes(),
            style: parseStyleDeclarations(e),
            matched: styleContext.matcher?.match(e),
            inheriting: DOM.FontSize.initial
        )
    }

    private func finite(_ value: DOM.Coordinate) -> DOM.Coordinate? {
        value.isFinite ? value : nil
    }

    /// The size of a nested `<svg>` (SVG 1.1 §7.9): percentages resolve against the enclosing
    /// viewport, and a missing (or invalid) width or height is 100%.
    private func nestedSize(widthRaw: String?, heightRaw: String?, parent: Viewport) -> (DOM.Coordinate, DOM.Coordinate)
    {
        let width = widthRaw.flatMap { try? resolveLength($0, .horizontal) }.flatMap(finite) ?? parent.width
        let height = heightRaw.flatMap { try? resolveLength($0, .vertical) }.flatMap(finite) ?? parent.height
        return (width, height)
    }

    /// The viewport that percentages of an `<svg>`'s contents resolve against, in their user units.
    static func contentViewport(viewBox: DOM.SVG.ViewBox?, width: DOM.Coordinate, height: DOM.Coordinate) -> Viewport {
        if let viewBox, viewBox.width > 0, viewBox.height > 0 {
            return Viewport(width: viewBox.width, height: viewBox.height)
        }
        return Viewport(width: width, height: height)
    }

    /// Pushes the viewport `e` establishes when it is a nested `<svg>`, so that definitions
    /// collected from inside it (`parseSVGDefs` walks the whole document) see the viewport they
    /// are defined in. Returns whether one was pushed; the caller pops it. Not a closure-taking
    /// wrapper: the defs walks recurse once per nesting level and must keep their frames small.
    func pushViewport(of e: XML.Element) -> Bool {
        guard e.name == "svg", let parent = lengthContext.viewports.last,
            let att = try? parseAttributes(e)
        else {
            return false
        }
        let (width, height) = nestedSize(
            widthRaw: try? att.parseString("width"),
            heightRaw: try? att.parseString("height"),
            parent: parent
        )
        let viewBox = (try? att.parseString("viewBox")).flatMap { try? parseViewBox($0) }
        lengthContext.viewports.append(Self.contentViewport(viewBox: viewBox, width: width, height: height))
        return true
    }

    func popViewport() {
        lengthContext.viewports.removeLast()
    }

    func makeUnresolvedReason(attribute: String, raw: String?, hasViewBox: Bool) -> String {
        if let raw, raw.contains("%") {
            return
                "<svg> \(attribute)=\"\(raw)\" cannot be resolved without a viewBox or an explicit viewport (--size on the command line)"
        }
        if raw == nil {
            if hasViewBox {
                return "<svg> \(attribute) attribute is missing"
            }
            return
                "<svg> \(attribute) attribute is missing and no viewBox or explicit viewport (--size on the command line) was provided"
        }
        return "<svg> \(attribute)=\"\(raw ?? "")\" cannot be resolved"
    }

    // search all nodes within document for any defs
    // not just the <defs> node
    func parseSVGDefs(_ e: XML.Element) throws -> DOM.SVG.Defs {
        var defs = DOM.SVG.Defs()
        defs.clipPaths = try parseClipPaths(e)
        defs.linearGradients = try parseLinearGradients(e)
        defs.radialGradients = try parseRadialGradients(e)
        var containers = ReferencedContainers()
        try parseReferencedContainers(e, ancestry: Ancestry(element: e, parent: nil), into: &containers)
        defs.masks = containers.masks
        defs.patterns = containers.patterns
        defs.markers = containers.markers
        defs.documentOrder = containers.documentOrder
        defs.filters = try parseFilters(e)

        defs.elements = try findDefElements(within: e).reduce(into: [String: DOM.GraphicsElement]()) {
            let defs = try parseDefsElements($1)
            $0.merge(defs, uniquingKeysWith: { lhs, _ in lhs })
        }

        return defs
    }

    func findDefElements(within element: XML.Element) -> [XML.Element] {
        return element.children.reduce(into: [XML.Element]()) {
            if $1.name == "defs" {
                $0.append($1)
            } else {
                $0.append(contentsOf: findDefElements(within: $1))
            }
        }
    }

    func parseDefsElements(_ e: XML.Element) throws -> [String: DOM.GraphicsElement] {
        guard e.name == "defs" else {
            throw Error.invalid
        }

        var defs = Dictionary<String, DOM.GraphicsElement>()
        let elements = try parseGraphicsElements(e.children)

        for e in elements {
            // an element without an id can never be referenced; skip it rather than fail
            guard let id = e.id, defs[id] == nil else { continue }
            defs[id] = e
        }

        return defs
    }

    func parseClipPaths(_ e: XML.Element) throws -> [DOM.ClipPath] {
        var clipPaths = [DOM.ClipPath]()

        for n in e.children {
            if n.name == "clipPath" {
                try appendSkippingInvalid(&clipPaths, n, parseClipPath)
            } else {
                clipPaths.append(contentsOf: try parseClipPaths(n))
            }
        }
        return clipPaths
    }

    func parseClipPath(_ e: XML.Element) throws -> DOM.ClipPath {
        guard e.name == "clipPath" else { throw Error.invalid }

        let att = try parseAttributes(e)
        let id: String = try att.parseString("id")
        // an unknown value falls back to userSpaceOnUse rather than failing the document
        let units: DOM.ClipPath.Units? = (try? att.parseRaw("clipPathUnits")) ?? nil

        let children = try parseGraphicsElements(e.children)
        var clip = DOM.ClipPath(id: id, childElements: children)
        clip.clipPathUnits = units
        clip.class = e.attributes["class"]
        clip.attributes = (try? parsePresentationAttributes(e)) ?? DOM.PresentationAttributes()
        let style = parseStyleDeclarations(e)
        clip.style = style.normal
        clip.importantStyle = style.important
        clip.matchedStyle = styleContext.matcher?.match(e)
        return clip
    }

    func parseMask(_ e: XML.Element) throws -> DOM.Mask {
        guard e.name == "mask" else { throw Error.invalid }

        let att = try parseAttributes(e)
        let id: String = try att.parseString("id")

        let mask = DOM.Mask(id: id)
        mask.class = try att.parseString("class")
        mask.attributes = try parsePresentationAttributes(e)
        applyStyle(of: e, to: mask)
        mask.childElements = try parseGraphicsElements(e.children)
        // an unknown unit or an unparseable length is ignored and the spec default applies
        mask.maskUnits = (try? att.parseRaw("maskUnits")) ?? nil
        mask.maskContentUnits = (try? att.parseRaw("maskContentUnits")) ?? nil
        mask.x = e.attributes["x"].flatMap(XMLParser.parseDashLength)
        mask.y = e.attributes["y"].flatMap(XMLParser.parseDashLength)
        mask.width = e.attributes["width"].flatMap(XMLParser.parseDashLength)
        mask.height = e.attributes["height"].flatMap(XMLParser.parseDashLength)
        return mask
    }

    func parsePattern(_ e: XML.Element) throws -> DOM.Pattern {
        guard e.name == "pattern" else { throw Error.invalid }

        let att = try parseAttributes(e)
        var pattern = try parsePattern(att)
        pattern.viewport = lengthContext.viewports.last
        pattern.childElements = try parseGraphicsElements(e.children)
        return pattern
    }
}

private extension XMLParser.Scanner {

    mutating func scanViewBoxCoordinate() throws -> DOM.Coordinate {
        let coordinate = try scanCoordinate()
        _ = try? scanCharacter(matchingAny: .viewBoxSeparator)
        return coordinate
    }
}

private extension Foundation.CharacterSet {

    static let viewBoxSeparator = Foundation.CharacterSet(charactersIn: ",")
}

package extension XMLParser {

    /// `[defer] <align> [meet|slice]`. Never throws: an invalid value is dropped so the
    /// element uses the initial value `xMidYMid meet`, rather than failing the document.
    func parsePreserveAspectRatio(_ data: String?) -> DOM.PreserveAspectRatio? {
        guard let data else { return nil }
        var tokens = data.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" || $0 == "\r" }).map(
            String.init
        )
        if tokens.first == "defer" { tokens.removeFirst() }
        guard (1...2).contains(tokens.count) else { return nil }

        let align: DOM.PreserveAspectRatio.Align
        switch tokens[0] {
        case "none": align = .none
        case "xMinYMin": align = .xMinYMin
        case "xMidYMin": align = .xMidYMin
        case "xMaxYMin": align = .xMaxYMin
        case "xMinYMid": align = .xMinYMid
        case "xMidYMid": align = .xMidYMid
        case "xMaxYMid": align = .xMaxYMid
        case "xMinYMax": align = .xMinYMax
        case "xMidYMax": align = .xMidYMax
        case "xMaxYMax": align = .xMaxYMax
        default: return nil
        }

        var meetOrSlice = DOM.PreserveAspectRatio.MeetOrSlice.meet
        if tokens.count == 2 {
            switch tokens[1] {
            case "meet": meetOrSlice = .meet
            case "slice": meetOrSlice = .slice
            default: return nil
            }
        }
        return DOM.PreserveAspectRatio(align: align, meetOrSlice: meetOrSlice)
    }
}
