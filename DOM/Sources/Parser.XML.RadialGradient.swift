//
//  Parser.XML.RadialGradient.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 13/8/22.
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

    /// `ancestors` are the elements above `e`, for the `color` a stop's `currentColor` inherits.
    func parseRadialGradients(_ e: XML.Element, ancestors: [XML.Element] = []) throws -> [DOM.RadialGradient] {
        var gradients = [DOM.RadialGradient]()
        let ancestors = ancestors + [e]

        for n in e.children {
            if n.name == "radialGradient" {
                try appendSkippingInvalid(&gradients, n) { try parseRadialGradient($0, ancestors: ancestors) }
            } else if n.name == "svg" {
                let pushed = pushViewport(of: n)
                defer { if pushed { popViewport() } }
                gradients.append(contentsOf: try parseRadialGradients(n, ancestors: ancestors))
            } else {
                gradients.append(contentsOf: try parseRadialGradients(n, ancestors: ancestors))
            }
        }
        return gradients
    }

    func parseRadialGradient(_ e: XML.Element, ancestors: [XML.Element] = []) throws -> DOM.RadialGradient {
        guard e.name == "radialGradient" else {
            throw Error.invalid
        }

        let nodeAtt: any AttributeParser = try parseAttributes(e)
        let node = DOM.RadialGradient(id: try nodeAtt.parseString("id"))
        node.r = try? nodeAtt.parseCoordinateOrPercentage("r")
        node.cx = try? nodeAtt.parseCoordinateOrPercentage("cx")
        node.cy = try? nodeAtt.parseCoordinateOrPercentage("cy")
        // a negative fr is an error (SVG 2 §14.3.4): as in WebKit and resvg, the initial 0% is used
        node.fr = (try? nodeAtt.parseCoordinateOrPercentage("fr")).flatMap { $0 < 0 ? nil : $0 }
        node.fx = try? nodeAtt.parseCoordinateOrPercentage("fx")
        node.fy = try? nodeAtt.parseCoordinateOrPercentage("fy")
        node.percentageAttributes = percentageAttributes(nodeAtt, ["r", "cx", "cy", "fr", "fx", "fy"])

        for n in e.children where n.name == "stop" {
            let att: any AttributeParser = try parseAttributes(n)
            var stop = try parseRadialGradientStop(att)
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

    func parseRadialGradientStop(_ att: any AttributeParser) throws -> DOM.RadialGradient.Stop {
        let offset: DOM.Float? = parseClampedFraction(att, "offset")
        let color: DOM.Color? = try? att.parseFill("stop-color").getColor()
        let opacity: DOM.Float? = parseClampedFraction(att, "stop-opacity")
        return DOM.RadialGradient.Stop(offset: offset ?? 0, color: color ?? .keyword(.black), opacity: opacity ?? 1.0)
    }
}
