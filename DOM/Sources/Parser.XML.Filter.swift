//
//  Parser.XML.Filter.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 16/8/22.
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

extension XMLParser {

    func parseFilters(_ e: XML.Element) throws -> [DOM.Filter] {
        try parseFilters(e, colorInterpolation: parseColorInterpolation(e) ?? .linearRGB)
    }

    // color-interpolation-filters is inherited (Filter Effects 1 §10): the <filter>'s ancestors pass it down
    func parseFilters(_ e: XML.Element, colorInterpolation: DOM.Filter.ColorInterpolation) throws -> [DOM.Filter] {
        var filters = [DOM.Filter]()

        for n in e.children {
            if n.name == "filter" {
                try appendSkippingInvalid(&filters, n) { try parseFilter($0, colorInterpolation: colorInterpolation) }
            } else {
                let inherited = parseColorInterpolation(n) ?? colorInterpolation
                filters.append(contentsOf: try parseFilters(n, colorInterpolation: inherited))
            }
        }
        return filters
    }

    func parseFilter(_ e: XML.Element) throws -> DOM.Filter {
        try parseFilter(e, colorInterpolation: .linearRGB)
    }

    func parseFilter(_ e: XML.Element, colorInterpolation: DOM.Filter.ColorInterpolation) throws -> DOM.Filter {
        guard e.name == "filter" else {
            throw Error.invalid
        }

        let nodeAtt: any AttributeParser = try parseAttributes(e)
        let node = DOM.Filter(id: try nodeAtt.parseString("id"))

        // invalid values fall back to the spec defaults rather than dropping the document
        node.x = try? nodeAtt.parseCoordinateOrPercentage("x")
        node.y = try? nodeAtt.parseCoordinateOrPercentage("y")
        node.width = try? nodeAtt.parseCoordinateOrPercentage("width")
        node.height = try? nodeAtt.parseCoordinateOrPercentage("height")
        node.filterUnits = try? nodeAtt.parseRaw("filterUnits")
        node.primitiveUnits = try? nodeAtt.parseRaw("primitiveUnits")

        let context = PrimitiveContext(
            primitiveUnits: node.primitiveUnits ?? .userSpaceOnUse,
            colorInterpolation: parseColorInterpolation(e) ?? colorInterpolation,
            color: try? nodeAtt.parseColor("color")
        )
        for n in e.children {
            if let primitive = try parsePrimitive(n, context: context) {
                node.primitives.append(primitive)
            }
        }

        return node
    }

    // what a primitive inherits from its <filter>
    struct PrimitiveContext {
        var primitiveUnits: DOM.Filter.Units
        var colorInterpolation: DOM.Filter.ColorInterpolation
        // the <filter>'s `color`, for flood-color="currentColor"
        var color: DOM.Color?
    }

    func parsePrimitive(_ e: XML.Element, context: PrimitiveContext) throws -> DOM.Filter.Primitive? {
        guard let effect = try parseEffect(e) else { return nil }
        let att: any AttributeParser = try parseAttributes(e)

        var primitive = DOM.Filter.Primitive(effect: effect)
        switch effect {
        case .merge:
            primitive.inputs = e.children
                .filter { $0.name == "feMergeNode" }
                .map { Self.parseFilterInput($0.attributes["in"]) }
        case .composite, .blend:
            primitive.inputs = [Self.parseFilterInput(e.attributes["in"]), Self.parseFilterInput(e.attributes["in2"])]
        case .flood:
            // flood-color="currentColor" takes the `color` of the primitive, else of the <filter>
            if case .flood(.currentColor, let opacity) = effect {
                let color = (try? att.parseColor("color")) ?? context.color ?? .keyword(.black)
                primitive.effect = .flood(color: color == .currentColor ? .keyword(.black) : color, opacity: opacity)
            }
        default:
            primitive.inputs = [Self.parseFilterInput(e.attributes["in"])]
        }

        let result = e.attributes["result"]?.trimmingCharacters(in: .whitespaces)
        primitive.result = result?.isEmpty == false ? result : nil

        // Filter Effects 1 §9.4: the subregion is in primitiveUnits; an unreadable value takes the default
        switch context.primitiveUnits {
        case .objectBoundingBox:
            primitive.x = try? att.parseCoordinateOrPercentage("x")
            primitive.y = try? att.parseCoordinateOrPercentage("y")
            primitive.width = try? att.parseCoordinateOrPercentage("width")
            primitive.height = try? att.parseCoordinateOrPercentage("height")
        case .userSpaceOnUse:
            primitive.x = try? parseLength(att, "x", .horizontal) as DOM.Coordinate
            primitive.y = try? parseLength(att, "y", .vertical) as DOM.Coordinate
            primitive.width = try? parseLength(att, "width", .horizontal) as DOM.Coordinate
            primitive.height = try? parseLength(att, "height", .vertical) as DOM.Coordinate
        }

        primitive.colorInterpolation = parseColorInterpolation(e) ?? context.colorInterpolation
        return primitive
    }

    func parseEffect(_ e: XML.Element) throws -> DOM.Filter.Effect? {
        switch e.name {
        case "feGaussianBlur":
            let att: any AttributeParser = try parseAttributes(e)
            // SVG 1.1 §15.17: one or two numbers; missing, invalid or negative values disable the blur
            let values: [DOM.Float] = (try? att.parseFloats("stdDeviation")) ?? []
            let x = values.first ?? 0
            let y = values.count > 1 ? values[1] : nil
            return .gaussianBlur(stdDeviation: x, stdDeviationY: y)
        case "feOffset":
            let att: any AttributeParser = try parseAttributes(e)
            return .offset(dx: parseFiniteFloat(att, "dx") ?? 0,
                           dy: parseFiniteFloat(att, "dy") ?? 0)
        case "feFlood":
            let att: any AttributeParser = try parseAttributes(e)
            // flood-color is a <color>: anything else, `none` included, keeps the initial black
            var color = (try? att.parseColor("flood-color")) ?? .keyword(.black)
            if color == .none {
                color = .keyword(.black)
            }
            return .flood(color: color, opacity: parseClampedFraction(att, "flood-opacity") ?? 1)
        case "feComposite":
            let att: any AttributeParser = try parseAttributes(e)
            return .composite(parseCompositeOperator(att))
        case "feMerge":
            return .merge
        case "feBlend":
            let att: any AttributeParser = try parseAttributes(e)
            let mode: DOM.Filter.BlendMode? = try? att.parseRaw("mode")
            return .blend(mode ?? .normal)
        case "feColorMatrix":
            let att: any AttributeParser = try parseAttributes(e)
            return .colorMatrix(parseColorMatrix(att))
        default:
            guard e.name.hasPrefix("fe") else { return nil }
            return .unsupported(name: e.name)
        }
    }

    // Filter Effects 1 §9.2: a keyword, else a reference to an earlier `result`; nil when missing
    static func parseFilterInput(_ value: String?) -> DOM.Filter.Input? {
        guard let value = value?.trimmingCharacters(in: .whitespaces), !value.isEmpty else { return nil }
        switch value {
        case "SourceGraphic":
            return .sourceGraphic
        case "SourceAlpha":
            return .sourceAlpha
        case "BackgroundImage":
            return .backgroundImage
        case "BackgroundAlpha":
            return .backgroundAlpha
        case "FillPaint":
            return .fillPaint
        case "StrokePaint":
            return .strokePaint
        default:
            return .result(value)
        }
    }

    // Filter Effects 1 §9.8: an unknown operator keeps the initial `over`; k1...k4 default to 0
    func parseCompositeOperator(_ att: any AttributeParser) -> DOM.Filter.CompositeOperator {
        switch (try? att.parseString("operator"))?.trimmingCharacters(in: .whitespaces) {
        case "in":
            return .in
        case "out":
            return .out
        case "atop":
            return .atop
        case "xor":
            return .xor
        case "lighter":
            return .lighter
        case "arithmetic":
            return .arithmetic(k1: parseFiniteFloat(att, "k1") ?? 0,
                               k2: parseFiniteFloat(att, "k2") ?? 0,
                               k3: parseFiniteFloat(att, "k3") ?? 0,
                               k4: parseFiniteFloat(att, "k4") ?? 0)
        default:
            return .over
        }
    }

    // Filter Effects 1 §9.6: missing values take the type's default; a wrong number of values is a pass through.
    // An unknown type is a pass through too, as in Chrome.
    func parseColorMatrix(_ att: any AttributeParser) -> DOM.Filter.ColorMatrix {
        let identity: [DOM.Float] = [1, 0, 0, 0, 0,
                                     0, 1, 0, 0, 0,
                                     0, 0, 1, 0, 0,
                                     0, 0, 0, 1, 0]
        let type = (try? att.parseString("type"))?.trimmingCharacters(in: .whitespaces) ?? "matrix"
        let values: [DOM.Float]? = (try? att.parseFloats("values")).flatMap { values in
            values.allSatisfy(\.isFinite) ? values : []
        }
        switch type {
        case "matrix":
            guard let values else { return .matrix(identity) }
            return .matrix(values.count == 20 ? values : identity)
        case "saturate":
            guard let values else { return .saturate(1) }
            return values.count == 1 ? .saturate(values[0]) : .saturate(1)
        case "hueRotate":
            guard let values else { return .hueRotate(0) }
            return values.count == 1 ? .hueRotate(values[0]) : .hueRotate(0)
        case "luminanceToAlpha":
            return .luminanceToAlpha
        default:
            return .matrix(identity)
        }
    }

    // Filter Effects 1 §10: `auto` and the two spaces; anything else is dropped so the inherited value applies.
    // Read from the attribute or style="" only: the whole document is walked, so no stylesheet match.
    func parseColorInterpolation(_ e: XML.Element) -> DOM.Filter.ColorInterpolation? {
        let key = "color-interpolation-filters"
        var value = e.attributes[key]
        if let style = e.attributes["style"], style.contains(key),
           let declared = try? parseStyleAttributes(style)[key] {
            value = declared
        }
        guard let value else { return nil }
        return DOM.Filter.ColorInterpolation(rawValue: Attributes.removingImportant(from: value).trimmingCharacters(in: .whitespaces))
    }

    func parseFiniteFloat(_ att: any AttributeParser, _ key: String) -> DOM.Float? {
        guard let value = try? att.parseFloat(key), value.isFinite else { return nil }
        return value
    }
}
