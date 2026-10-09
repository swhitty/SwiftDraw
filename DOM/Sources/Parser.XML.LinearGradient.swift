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

    func parseLinearGradients(_ e: XML.Element) throws -> [DOM.LinearGradient] {
        var gradients = [DOM.LinearGradient]()

        for n in e.children {
            if n.name == "linearGradient" {
                try appendSkippingInvalid(&gradients, n, parseLinearGradient)
            } else {
                gradients.append(contentsOf: try parseLinearGradients(n))
            }
        }
        return gradients
    }

    func parseLinearGradient(_ e: XML.Element) throws -> DOM.LinearGradient {
        guard e.name == "linearGradient" else {
            throw Error.invalid
        }

        let nodeAtt: any AttributeParser = try parseAttributes(e)
        let node = DOM.LinearGradient(id: try nodeAtt.parseString("id"))
        node.x1 = try nodeAtt.parseCoordinateOrPercentage("x1")
        node.y1 = try nodeAtt.parseCoordinateOrPercentage("y1")
        node.x2 = try nodeAtt.parseCoordinateOrPercentage("x2")
        node.y2 = try nodeAtt.parseCoordinateOrPercentage("y2")

        for n in e.children where n.name == "stop" {
            let att: any AttributeParser = try parseAttributes(n)
            var stop = try parseLinearGradientStop(att)
            if let cascaded = cascadedStop(n) {
                stop.color = cascaded.color ?? stop.color
                stop.opacity = cascaded.opacity ?? stop.opacity
            }
            node.stops.append(stop)
        }

        // an unreadable value is dropped like the other attributes, the gradient is kept (SVG 1.1 §13.2.2)
        node.gradientUnits = (try? nodeAtt.parseRaw("gradientUnits")) ?? nil
        node.href  = try? nodeAtt.parseHref()

        // an unreadable value is left unset, so it is inherited through href (SVG 1.1 §13.2)
        if let val = try? nodeAtt.parseString("gradientTransform") {
          if val.trimmingCharacters(in: .whitespaces) == "none" { node.gradientTransform = [] }
          else if let t = try? parseTransform(val) { node.gradientTransform = t }
        }
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
