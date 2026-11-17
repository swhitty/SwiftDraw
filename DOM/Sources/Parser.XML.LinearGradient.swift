//
//  Parser.XML.LinearGradient.swift
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

extension XMLParser {

    /// `ancestors` are the elements above `e`, for the `color` a stop's `currentColor` inherits.
    func parseLinearGradients(_ e: XML.Element, ancestors: [XML.Element] = []) throws -> [DOM.LinearGradient] {
        var gradients = [DOM.LinearGradient]()
        let ancestors = ancestors + [e]

        for n in e.children {
            if n.name == "linearGradient" {
                try appendSkippingInvalid(&gradients, n) { try parseLinearGradient($0, ancestors: ancestors) }
            } else if n.name == "svg" {
                let pushed = pushViewport(of: n)
                defer { if pushed { popViewport() } }
                gradients.append(contentsOf: try parseLinearGradients(n, ancestors: ancestors))
            } else {
                gradients.append(contentsOf: try parseLinearGradients(n, ancestors: ancestors))
            }
        }
        return gradients
    }

    func parseLinearGradient(_ e: XML.Element, ancestors: [XML.Element] = []) throws -> DOM.LinearGradient {
        guard e.name == "linearGradient" else {
            throw Error.invalid
        }

        let nodeAtt: any AttributeParser = try parseAttributes(e)
        let node = DOM.LinearGradient(id: try nodeAtt.parseString("id"))
        node.x1 = try nodeAtt.parseCoordinateOrPercentage("x1")
        node.y1 = try nodeAtt.parseCoordinateOrPercentage("y1")
        node.x2 = try nodeAtt.parseCoordinateOrPercentage("x2")
        node.y2 = try nodeAtt.parseCoordinateOrPercentage("y2")
        node.percentageAttributes = percentageAttributes(nodeAtt, ["x1", "y1", "x2", "y2"])

        for n in e.children where n.name == "stop" {
            let att: any AttributeParser = try parseAttributes(n)
            var stop = try parseLinearGradientStop(att)
            let cascaded = cascadedStop(n)
            stop.color = resolveStopColor(n, att, cascaded: cascaded?.color, gradient: e, ancestors: ancestors)
            stop.opacity = cascaded?.opacity ?? stop.opacity
            node.stops.append(stop)
        }

        // an unreadable value is dropped like the other attributes, the gradient is kept (SVG 1.1 §13.2.2)
        node.gradientUnits = (try? nodeAtt.parseRaw("gradientUnits")) ?? nil
        node.href = try? nodeAtt.parseHref()
        node.viewport = lengthContext.viewports.last

        // an empty value is the identity and overrides an inherited transform; an invalid one is dropped
        if let val = try? nodeAtt.parseString("gradientTransform"),
            let t = try? parseTransform(val)
        {
            node.gradientTransform = t
            node.hasGradientTransform = true
        }
        node.colorInterpolation = inheritedColorInterpolation(ancestors + [e])
        node.transformOrigin = (try? nodeAtt.parseString("transform-origin")).flatMap(parseTransformOrigin)
        node.spreadMethod = try? nodeAtt.parseRaw("spreadMethod")

        return node
    }

    func parseLinearGradientStop(_ att: any AttributeParser) throws -> DOM.LinearGradient.Stop {
        let offset: DOM.Float? = parseClampedFraction(att, "offset")
        let color: DOM.Color? = try? att.parseFill("stop-color").getColor()
        let opacity: DOM.Float? = parseClampedFraction(att, "stop-opacity")
        return DOM.LinearGradient.Stop(offset: offset ?? 0, color: color ?? .keyword(.black), opacity: opacity ?? 1.0)
    }
}

extension XMLParser {

    /// The keys whose value is written as a percentage.
    func percentageAttributes(_ att: any AttributeParser, _ keys: [String]) -> Set<String> {
        Set(
            keys.filter { key in
                guard let raw: String = try? att.parseString(key) else { return false }
                return raw.trimmingCharacters(in: .whitespaces).hasSuffix("%")
            }
        )
    }

    /// The `color-interpolation` in effect on the last element of `chain`, a path from the document root,
    /// through the cascade; `auto` is sRGB.
    func inheritedColorInterpolation(_ chain: [XML.Element]) -> DOM.ColorInterpolation? {
        let value = chain.lazy.reversed().compactMap { self.cascadedAttributes($0).colorInterpolation }.first
        return value == .auto ? .sRGB : value
    }

    /// A number or percentage clamped to 0...1 (SVG 1.1 §13.2.4 stop offset and stop-opacity);
    /// nil when missing or unreadable, so the caller uses the initial value.
    func parseClampedFraction(_ att: any AttributeParser, _ key: String) -> DOM.Float? {
        guard var text = try? att.parseString(key).trimmingCharacters(in: .whitespaces) else { return nil }
        var scale: DOM.Float = 1
        if text.hasSuffix("%") {
            text.removeLast()
            scale = 100
        }
        guard let value = DOM.Float(text), value.isFinite else { return nil }
        return min(1, max(0, value / scale))
    }
}
