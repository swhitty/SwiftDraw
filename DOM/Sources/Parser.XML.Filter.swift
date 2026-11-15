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
        var filters = [DOM.Filter]()

        for n in e.children {
            if n.name == "filter" {
                try appendSkippingInvalid(&filters, n, parseFilter)
            } else {
                filters.append(contentsOf: try parseFilters(n))
            }
        }
        return filters
    }

    func parseFilter(_ e: XML.Element) throws -> DOM.Filter {
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

        var previousResult: String?
        var primitives = e.children[...]
        if hasNoOpSourcePrelude(primitives) {
            // the chain continues from the source graphic, under the blend's result name
            previousResult = primitives[primitives.startIndex + 1].attributes["result"]
            primitives = primitives.dropFirst(2)
        }
        for n in primitives {
            if var effect = try parseEffect(n) {
                // only a linear chain is supported: each primitive must consume the previous result
                if let input = n.attributes["in"] {
                    let isSource = node.effects.isEmpty && input == "SourceGraphic"
                    let isPrevious = previousResult != nil && input == previousResult
                    if !isSource && !isPrevious {
                        effect = .unsupported(name: n.name)
                    }
                }
                previousResult = n.attributes["result"]
                node.effects.append(effect)
            }
        }

        return node
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
              ["x", "y", "width", "height"].allSatisfy({ blend.attributes[$0] == nil }) else {
            return false
        }
        return true
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
        default:
            guard e.name.hasPrefix("fe") else { return nil }
            return .unsupported(name: e.name)
        }
    }
}
