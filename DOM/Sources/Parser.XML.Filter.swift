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
                filters.append(try parseFilter(n))
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
        for n in e.children {
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
