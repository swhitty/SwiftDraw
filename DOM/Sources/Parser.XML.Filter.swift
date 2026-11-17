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
        node.href = try? nodeAtt.parseHref()

        let context = PrimitiveContext(
            primitiveUnits: node.primitiveUnits ?? .userSpaceOnUse,
            colorInterpolation: parseColorInterpolation(e) ?? colorInterpolation,
            color: try? nodeAtt.parseColor("color"),
            floodColor: parseFloodColor(nodeAtt),
            floodOpacity: parseClampedFraction(nodeAtt, "flood-opacity") ?? 1,
            isPixelated: parseImageRendering(e) ?? false
        )
        node.primitives = try parsePrimitives(e.children[...], context: context, skippingPrelude: true)
        if node.primitives.isEmpty {
            // a lone prelude is still a filter: keep it so the element is drawn, not hidden as by an empty filter
            node.primitives = try parsePrimitives(e.children[...], context: context, skippingPrelude: false)
        }
        return node
    }

    func parsePrimitives(
        _ children: ArraySlice<XML.Element>,
        context: PrimitiveContext,
        skippingPrelude: Bool
    ) throws -> [DOM.Filter.Primitive] {
        var children = children
        // the source graphic stands in for the blend's result until a later primitive reuses its name
        var sourceAlias: String?
        if skippingPrelude && hasNoOpSourcePrelude(children) {
            sourceAlias = children[children.startIndex + 1].attributes["result"]?.trimmingCharacters(in: .whitespaces)
            children = children.dropFirst(2)
        }
        var primitives = [DOM.Filter.Primitive]()
        for n in children {
            if var primitive = try parsePrimitive(n, context: context) {
                if let alias = sourceAlias {
                    primitive.inputs = primitive.inputs.map { $0 == .result(alias) ? .sourceGraphic : $0 }
                    if primitive.result == alias {
                        sourceAlias = nil
                    }
                }
                primitives.append(primitive)
            }
        }
        return primitives
    }

    /// Figma and Sketch start a layer blur with a transparent `feFlood` and the source graphic blended over
    /// it in `normal` mode. The source over transparency is the source, so the pair is a no-op and the
    /// chain is just the primitives after it. Only that exact pair matches: an opaque flood, another blend
    /// mode or input, or a blend subregion (which clips) is left as it is.
    func hasNoOpSourcePrelude(_ primitives: ArraySlice<XML.Element>) -> Bool {
        guard primitives.count >= 2 else { return false }
        let flood = primitives[primitives.startIndex]
        let blend = primitives[primitives.startIndex + 1]
        guard flood.name == "feFlood", blend.name == "feBlend",
            let floodResult = flood.attributes["result"],
            let floodAtt = try? parseAttributes(flood),
            let opacity = try? floodAtt.parsePercentage("flood-opacity") as DOM.Float?,
            opacity == 0,
            blend.attributes["in"] == "SourceGraphic",
            blend.attributes["in2"] == floodResult,
            (blend.attributes["mode"] ?? "normal") == "normal",
            ["x", "y", "width", "height"].allSatisfy({ blend.attributes[$0] == nil })
        else {
            return false
        }
        // the flood is dropped with the blend, so nothing after them may read it
        return !primitives.dropFirst(2).contains { referencesResult(floodResult, in: $0) }
    }

    func referencesResult(_ result: String, in e: XML.Element) -> Bool {
        let inputs = [e.attributes["in"], e.attributes["in2"]] + e.children.map { $0.attributes["in"] }
        return inputs.contains { $0?.trimmingCharacters(in: .whitespaces) == result }
    }

    // what a primitive inherits from its <filter>
    struct PrimitiveContext {
        var primitiveUnits: DOM.Filter.Units
        var colorInterpolation: DOM.Filter.ColorInterpolation
        // the <filter>'s `color`, for flood-color="currentColor"
        var color: DOM.Color?
        // the <filter>'s flood-color and flood-opacity, for `inherit`
        var floodColor: DOM.Color = .keyword(.black)
        var floodOpacity: DOM.Float = 1
        // the <filter>'s image-rendering, inherited by <feImage>
        var isPixelated = false
    }

    func parsePrimitive(_ e: XML.Element, context: PrimitiveContext) throws -> DOM.Filter.Primitive? {
        guard let effect = try parseEffect(e) else { return nil }
        let att: any AttributeParser = try parseAttributes(e)

        var primitive = DOM.Filter.Primitive(effect: inheritingFlood(effect, att, context: context))
        switch primitive.effect {
        case .merge:
            primitive.inputs = e.children
                .filter { $0.name == "feMergeNode" }
                .map { Self.parseFilterInput($0.attributes["in"]) }
        case .composite, .blend:
            primitive.inputs = [Self.parseFilterInput(e.attributes["in"]), Self.parseFilterInput(e.attributes["in2"])]
        case .flood(.currentColor, let opacity):
            primitive.effect = .flood(color: resolveCurrentColor(att, context: context), opacity: opacity)
        case .flood, .turbulence:
            break
        case .image(var image):
            image.isPixelated = parseImageRendering(e) ?? context.isPixelated
            primitive.effect = .image(image)
        case .dropShadow(var shadow):
            primitive.inputs = [Self.parseFilterInput(e.attributes["in"])]
            if shadow.color == .currentColor {
                shadow.color = resolveCurrentColor(att, context: context)
                primitive.effect = .dropShadow(shadow)
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

    // flood-color and flood-opacity are not inherited, but an explicit `inherit` takes the <filter>'s
    func inheritingFlood(
        _ effect: DOM.Filter.Effect,
        _ att: any AttributeParser,
        context: PrimitiveContext
    ) -> DOM.Filter.Effect {
        func isInherit(_ key: String) -> Bool {
            (try? att.parseString(key))?.trimmingCharacters(in: .whitespaces) == "inherit"
        }
        switch effect {
        case .flood(var color, var opacity):
            if isInherit("flood-color") { color = context.floodColor }
            if isInherit("flood-opacity") { opacity = context.floodOpacity }
            return .flood(color: color, opacity: opacity)
        case .dropShadow(var shadow):
            if isInherit("flood-color") { shadow.color = context.floodColor }
            if isInherit("flood-opacity") { shadow.opacity = context.floodOpacity }
            return .dropShadow(shadow)
        default:
            return effect
        }
    }

    // flood-color="currentColor" takes the `color` of the primitive, else of the <filter>
    func resolveCurrentColor(_ att: any AttributeParser, context: PrimitiveContext) -> DOM.Color {
        let color = (try? att.parseColor("color")) ?? context.color ?? .keyword(.black)
        return color == .currentColor ? .keyword(.black) : color
    }

    // flood-color is a <color>: anything else, `none` included, keeps the initial black
    func parseFloodColor(_ att: any AttributeParser) -> DOM.Color {
        let color = (try? att.parseColor("flood-color")) ?? .keyword(.black)
        return color == .none ? .keyword(.black) : color
    }

    func parseEffect(_ e: XML.Element) throws -> DOM.Filter.Effect? {
        switch e.name {
        case "feGaussianBlur":
            let att: any AttributeParser = try parseAttributes(e)
            // SVG 1.1 §15.17: one or two numbers; missing, invalid or negative values disable the blur,
            // and so do more than two (as resvg and WebKit)
            var values: [DOM.Float] = (try? att.parseFloats("stdDeviation")) ?? []
            if values.count > 2 {
                values = []
            }
            let x = values.first ?? 0
            let y = values.count > 1 ? values[1] : nil
            return .gaussianBlur(stdDeviation: x, stdDeviationY: y)
        case "feOffset":
            let att: any AttributeParser = try parseAttributes(e)
            return .offset(
                dx: parseFiniteFloat(att, "dx") ?? 0,
                dy: parseFiniteFloat(att, "dy") ?? 0
            )
        case "feFlood":
            let att: any AttributeParser = try parseAttributes(e)
            return .flood(color: parseFloodColor(att), opacity: parseClampedFraction(att, "flood-opacity") ?? 1)
        case "feDropShadow":
            let att: any AttributeParser = try parseAttributes(e)
            // Filter Effects 1 §9.12: dx, dy and stdDeviation default to 2; an unreadable value takes the default
            let values: [DOM.Float]? = (try? att.parseFloats("stdDeviation")).flatMap { values in
                values.isEmpty || values.count > 2 || !values.allSatisfy(\.isFinite) ? nil : values
            }
            return .dropShadow(
                DOM.Filter.DropShadow(
                    dx: parseFiniteFloat(att, "dx") ?? 2,
                    dy: parseFiniteFloat(att, "dy") ?? 2,
                    stdDeviation: values?[0] ?? 2,
                    stdDeviationY: values.flatMap { $0.count > 1 ? $0[1] : nil },
                    color: parseFloodColor(att),
                    opacity: parseClampedFraction(att, "flood-opacity") ?? 1
                )
            )
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
        case "feComponentTransfer":
            return .componentTransfer(try parseComponentTransfer(e))
        case "feMorphology":
            let att: any AttributeParser = try parseAttributes(e)
            // Filter Effects 1 §9.17: one or two numbers, initially 0; an unreadable list takes the initial value
            var values: [DOM.Float] = (try? att.parseFloats("radius")) ?? []
            if values.count > 2 || !values.allSatisfy(\.isFinite) {
                values = []
            }
            let op: DOM.Filter.MorphologyOperator? = try? att.parseRaw("operator")
            return .morphology(
                op ?? .erode,
                radius: values.first ?? 0,
                radiusY: values.count > 1 ? values[1] : nil
            )
        case "feTurbulence":
            return .turbulence(try parseTurbulence(e))
        case "feConvolveMatrix":
            return .convolveMatrix(try parseConvolveMatrix(e))
        case "feImage":
            let att: any AttributeParser = try parseAttributes(e)
            // SVG 2 href, falling back to xlink:href; image-rendering is inherited, so set by parsePrimitive
            return .image(
                DOM.Filter.Image(
                    href: try? att.parseHref(),
                    preserveAspectRatio: parsePreserveAspectRatio(try? att.parseString("preserveAspectRatio"))
                        ?? .default
                )
            )
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
            return .arithmetic(
                k1: parseFiniteFloat(att, "k1") ?? 0,
                k2: parseFiniteFloat(att, "k2") ?? 0,
                k3: parseFiniteFloat(att, "k3") ?? 0,
                k4: parseFiniteFloat(att, "k4") ?? 0
            )
        default:
            return .over
        }
    }

    // Filter Effects 1 §9.6: missing values take the type's default; a wrong number of values is a pass through.
    // An unknown type is the initial `matrix`, so its values still apply, as in resvg and WebKit.
    func parseColorMatrix(_ att: any AttributeParser) -> DOM.Filter.ColorMatrix {
        let identity: [DOM.Float] = [
            1, 0, 0, 0, 0,
            0, 1, 0, 0, 0,
            0, 0, 1, 0, 0,
            0, 0, 0, 1, 0,
        ]
        let type = (try? att.parseString("type"))?.trimmingCharacters(in: .whitespaces) ?? "matrix"
        let values: [DOM.Float]? = (try? att.parseFloats("values")).flatMap { values in
            values.allSatisfy(\.isFinite) ? values : []
        }
        switch type {
        case "saturate":
            guard let values else { return .saturate(1) }
            return values.count == 1 ? .saturate(values[0]) : .saturate(1)
        case "hueRotate":
            guard let values else { return .hueRotate(0) }
            return values.count == 1 ? .hueRotate(values[0]) : .hueRotate(0)
        case "luminanceToAlpha":
            return .luminanceToAlpha
        default:
            // `matrix`, or an unknown type
            guard let values else { return .matrix(identity) }
            return .matrix(values.count == 20 ? values : identity)
        }
    }

    // Filter Effects 1 §9.7: a repeated feFuncX replaces the earlier one, as in resvg and WebKit
    func parseComponentTransfer(_ e: XML.Element) throws -> DOM.Filter.ComponentTransfer {
        var transfer = DOM.Filter.ComponentTransfer()
        for n in e.children {
            switch n.name {
            case "feFuncR":
                transfer.r = try parseTransferFunction(n)
            case "feFuncG":
                transfer.g = try parseTransferFunction(n)
            case "feFuncB":
                transfer.b = try parseTransferFunction(n)
            case "feFuncA":
                transfer.a = try parseTransferFunction(n)
            default:
                break
            }
        }
        return transfer
    }

    // An unknown type is the identity. Numbers are plain <number>s: a unit or percentage makes the value
    // unreadable, which takes the initial value (resvg), and an unreadable tableValues is empty.
    func parseTransferFunction(_ e: XML.Element) throws -> DOM.Filter.TransferFunction {
        let att: any AttributeParser = try parseAttributes(e)
        func number(_ key: String, _ initial: DOM.Float) -> DOM.Float {
            guard let values = try? att.parseFloats(key), values.count == 1, values[0].isFinite else { return initial }
            return values[0]
        }
        func table() -> [DOM.Float] {
            guard let values = try? att.parseFloats("tableValues"), values.allSatisfy(\.isFinite) else { return [] }
            return values
        }
        switch (try? att.parseString("type"))?.trimmingCharacters(in: .whitespaces) {
        case "table":
            return .table(table())
        case "discrete":
            return .discrete(table())
        case "linear":
            return .linear(slope: number("slope", 1), intercept: number("intercept", 0))
        case "gamma":
            return .gamma(
                amplitude: number("amplitude", 1),
                exponent: number("exponent", 1),
                offset: number("offset", 0)
            )
        default:
            return .identity
        }
    }

    // Filter Effects 1 §9.21: baseFrequency is one or two numbers, initially 0; an unreadable list takes the
    // initial value, as in resvg. numOctaves is an integer, initially 1; negative is 0 octaves (no noise).
    // An unknown type or stitchTiles keeps the initial turbulence and noStitch.
    func parseTurbulence(_ e: XML.Element) throws -> DOM.Filter.Turbulence {
        let att: any AttributeParser = try parseAttributes(e)
        var frequency: [DOM.Float] = (try? att.parseFloats("baseFrequency")) ?? []
        if frequency.isEmpty || frequency.count > 2 || !frequency.allSatisfy(\.isFinite) {
            frequency = [0]
        }
        var octaves = 1
        if let value = parseFiniteFloat(att, "numOctaves") {
            octaves = Int(min(max(value, 0), 1_000_000))
        }
        let type: DOM.Filter.TurbulenceType? = try? att.parseRaw("type")
        let stitch = (try? att.parseString("stitchTiles"))?.trimmingCharacters(in: .whitespaces) == "stitch"
        return DOM.Filter.Turbulence(
            baseFrequencyX: frequency[0],
            baseFrequencyY: frequency.count > 1 ? frequency[1] : frequency[0],
            numOctaves: octaves,
            seed: parseFiniteFloat(att, "seed") ?? 0,
            type: type ?? .turbulence,
            stitchTiles: stitch
        )
    }

    // Filter Effects 1 §9.9: order is one or two positive integers, initially 3; anything else is an error
    // (order 0). kernelUnitLength is not read: the kernel is in pixels of the bitmap, as in resvg (Safari spaces
    // its values a user unit apart).
    func parseConvolveMatrix(_ e: XML.Element) throws -> DOM.Filter.ConvolveMatrix {
        let att: any AttributeParser = try parseAttributes(e)
        var matrix = DOM.Filter.ConvolveMatrix()
        if let order = try? att.parseString("order") {
            let values = (try? att.parser.parseFloats(order)) ?? []
            let isValid =
                (1...2).contains(values.count) && values.allSatisfy { $0 >= 1 && $0 <= 1_000_000 && $0 == $0.rounded() }
            matrix.orderX = isValid ? Int(values[0]) : 0
            matrix.orderY = isValid ? Int(values.count > 1 ? values[1] : values[0]) : 0
        }
        if let values = try? att.parseFloats("kernelMatrix") {
            matrix.kernelMatrix = values.allSatisfy(\.isFinite) ? values : []
        }
        matrix.divisor = parseFiniteFloat(att, "divisor")
        matrix.bias = parseFiniteFloat(att, "bias") ?? 0
        // a target that is not an integer is out of range
        func target(_ key: String) -> Int? {
            guard let value = try? att.parseFloat(key) else { return nil }
            guard value.isFinite, value == value.rounded(), abs(value) <= 1_000_000 else { return -1 }
            return Int(value)
        }
        matrix.targetX = target("targetX")
        matrix.targetY = target("targetY")
        let edgeMode: DOM.Filter.EdgeMode? = try? att.parseRaw("edgeMode")
        matrix.edgeMode = edgeMode ?? .duplicate
        matrix.preserveAlpha = (try? att.parseString("preserveAlpha"))?.trimmingCharacters(in: .whitespaces) == "true"
        return matrix
    }

    // Filter Effects 1 §10: `auto` and the two spaces; anything else is dropped so the inherited value applies.
    // Read from the attribute or style="" only: the whole document is walked, so no stylesheet match.
    func parseColorInterpolation(_ e: XML.Element) -> DOM.Filter.ColorInterpolation? {
        let key = "color-interpolation-filters"
        var value = e.attributes[key]
        if let style = e.attributes["style"], style.contains(key),
            let declared = try? parseStyleAttributes(style)[key]
        {
            value = declared
        }
        guard let value else { return nil }
        return DOM.Filter.ColorInterpolation(
            rawValue: Attributes.removingImportant(from: value).trimmingCharacters(in: .whitespaces)
        )
    }

    // image-rendering (CSS Images 3 §5.3, SVG 1.1 §15.16): true for the keywords that sample the nearest pixel,
    // false for the smooth ones; nil when missing or unknown so the inherited value applies.
    // Read from the attribute or style="" only, as color-interpolation-filters.
    func parseImageRendering(_ e: XML.Element) -> Bool? {
        let key = "image-rendering"
        var value = e.attributes[key]
        if let style = e.attributes["style"], style.contains(key),
            let declared = try? parseStyleAttributes(style)[key]
        {
            value = declared
        }
        guard let value else { return nil }
        switch Attributes.removingImportant(from: value).trimmingCharacters(in: .whitespaces) {
        case "optimizeSpeed", "pixelated", "crisp-edges":
            return true
        case "auto", "optimizeQuality", "smooth", "high-quality":
            return false
        default:
            return nil
        }
    }

    func parseFiniteFloat(_ att: any AttributeParser, _ key: String) -> DOM.Float? {
        guard let value = try? att.parseFloat(key), value.isFinite else { return nil }
        return value
    }
}
