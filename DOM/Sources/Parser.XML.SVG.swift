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

package extension XMLParser {

    func parseSVG(_ e: XML.Element) throws -> DOM.SVG {
        guard e.name == "svg" else {
            throw Error.invalid
        }

        let att = try parseAttributes(e)
        let widthRaw = try? att.parseString("width")
        let heightRaw = try? att.parseString("height")
        let viewBox: DOM.SVG.ViewBox? = try parseViewBox(try att.parseString("viewBox"))

        var width = try resolveRootDimension(widthRaw, viewport: defaultViewport?.width, attribute: "width")
        var height = try resolveRootDimension(heightRaw, viewport: defaultViewport?.height, attribute: "height")

        width = width ?? viewBox?.width ?? defaultViewport?.width
        height = height ?? viewBox?.height ?? defaultViewport?.height

        guard let w = width else {
            throw XMLParser.Error.unresolvableDimension(reason: makeUnresolvedReason(attribute: "width", raw: widthRaw, hasViewBox: viewBox != nil))
        }
        guard let h = height else {
            throw XMLParser.Error.unresolvableDimension(reason: makeUnresolvedReason(attribute: "height", raw: heightRaw, hasViewBox: viewBox != nil))
        }

        let svg = DOM.SVG(width: DOM.Length(w), height: DOM.Length(h))
        svg.x = try att.parseCoordinate("x")
        svg.y = try att.parseCoordinate("y")
        svg.childElements = try parseGraphicsElements(e.children)
        svg.viewBox = viewBox

        svg.defs = try parseSVGDefs(e)
        svg.styles = parseStyleSheetElements(within: e)

        svg.attributes = try parsePresentationAttributes(att)

        return svg
    }

    func parseViewBox(_ data: String?) throws -> DOM.SVG.ViewBox? {
        guard let data = data else { return nil }
        var scanner = XMLParser.Scanner(text: data)

        let x = try scanner.scanCoordinate()
        let y = try scanner.scanCoordinate()
        let width = try scanner.scanCoordinate()
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
        let value = try scanner.scanCoordinate()
        if scanner.scanStringIfPossible("%") {
            guard let viewport else { return nil }
            return value / 100 * viewport
        }
        guard scanner.isEOF else {
            throw Error.invalidAttribute(name: attribute, value: raw)
        }
        return value
    }

    func makeUnresolvedReason(attribute: String, raw: String?, hasViewBox: Bool) -> String {
        if let raw, raw.contains("%") {
            return "<svg> \(attribute)=\"\(raw)\" cannot be resolved without a viewBox or an explicit viewport (--size on the command line)"
        }
        if raw == nil {
            if hasViewBox {
                return "<svg> \(attribute) attribute is missing"
            }
            return "<svg> \(attribute) attribute is missing and no viewBox or explicit viewport (--size on the command line) was provided"
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
        defs.masks = try parseMasks(e)
        defs.patterns = try parsePatterns(e)
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
            guard let id = e.id else {
                throw Error.invalid
            }
            defs[id] = e
        }

        return defs
    }


    func parseClipPaths(_ e: XML.Element) throws -> [DOM.ClipPath] {
        var clipPaths = [DOM.ClipPath]()

        for n in e.children {
            if n.name == "clipPath" {
                clipPaths.append(try parseClipPath(n))
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
        let units: DOM.ClipPath.Units? = try att.parseRaw("clipPathUnits")

        let children = try parseGraphicsElements(e.children)
        var clip = DOM.ClipPath(id: id, childElements: children)
        clip.clipPathUnits = units
        return clip
    }

    func parseMasks(_ e: XML.Element) throws -> [DOM.Mask] {
        var masks = [DOM.Mask]()

        for n in e.children {
            if n.name == "mask" {
                masks.append(try parseMask(n))
            } else {
                masks.append(contentsOf: try parseMasks(n))
            }
        }
        return masks
    }

    func parseMask(_ e: XML.Element) throws -> DOM.Mask {
        guard e.name == "mask" else { throw Error.invalid }

        let att = try parseAttributes(e)
        let id: String = try att.parseString("id")

        let mask = DOM.Mask(id: id)
        mask.class = try att.parseString("class")
        mask.attributes = try parsePresentationAttributes(e)
        mask.style = try parseStyleAttributes(e)
        mask.childElements = try parseGraphicsElements(e.children)
        return mask
    }

    func parsePatterns(_ e: XML.Element) throws -> [DOM.Pattern] {
        var patterns = [DOM.Pattern]()

        for n in e.children {
            if n.name == "pattern" {
                patterns.append(try parsePattern(n))
            } else {
                patterns.append(contentsOf: try parsePatterns(n))
            }
        }
        return patterns
    }

    func parsePattern(_ e: XML.Element) throws -> DOM.Pattern {
        guard e.name == "pattern" else { throw Error.invalid }

        let att = try parseAttributes(e)
        var pattern = try parsePattern(att)
        pattern.childElements = try parseGraphicsElements(e.children)
        return pattern
    }
}
