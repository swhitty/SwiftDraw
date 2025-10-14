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

        for n in e.children {
            if let effect = try parseEffect(n) {
                node.effects.append(effect)
            }
        }

        return node
    }

    func parseEffect(_ e: XML.Element) throws -> DOM.Filter.Effect? {
        switch e.name {
        case "feGaussianBlur":
            let att: any AttributeParser = try parseAttributes(e)
            return try .gaussianBlur(stdDeviation: att.parseFloat("stdDeviation"))
        default:
            return nil
        }
    }
}
