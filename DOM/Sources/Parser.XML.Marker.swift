//
//  Parser.XML.Marker.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 15/11/26.
//  Copyright 2026 Simon Whitty
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

extension XMLParser {

    func parseMarker(_ e: XML.Element) throws -> DOM.Marker {
        guard e.name == "marker" else { throw Error.invalid }

        let att = try parseAttributes(e)
        let id: String = try att.parseString("id")

        let marker = DOM.Marker(id: id)
        marker.class = try? att.parseString("class")
        marker.attributes = try parsePresentationAttributes(e)
        applyStyle(of: e, to: marker)

        // an invalid value is ignored and the spec default applies
        marker.markerWidth = parseDefaultedLength(att, "markerWidth", .horizontal)
        marker.markerHeight = parseDefaultedLength(att, "markerHeight", .vertical)
        marker.refX = parseDefaultedLength(att, "refX", .horizontal)
        marker.refY = parseDefaultedLength(att, "refY", .vertical)
        marker.markerUnits = (try? att.parseRaw("markerUnits")) ?? nil
        marker.orient = (try? att.parseString("orient")).flatMap(Self.parseMarkerOrient)
        marker.viewBox = try? parseViewBox(try att.parseString("viewBox"))
        marker.preserveAspectRatio = parsePreserveAspectRatio(try? att.parseString("preserveAspectRatio"))

        // the contents resolve percentages against the marker's own viewport
        let width = marker.viewBox?.width ?? marker.markerWidth ?? 3
        let height = marker.viewBox?.height ?? marker.markerHeight ?? 3
        lengthContext.viewports.append(Viewport(width: width, height: height))
        defer { lengthContext.viewports.removeLast() }
        marker.childElements = try parseGraphicsElements(e.children)
        return marker
    }

    /// `auto`, `auto-start-reverse` or an angle (`45`, `45deg`, `1rad`, `50grad`, `0.25turn`); nil when invalid.
    static func parseMarkerOrient(_ text: String) -> DOM.Marker.Orient? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch text {
        case "auto": return .auto
        case "auto-start-reverse": return .autoStartReverse
        default: break
        }

        let units: [(suffix: String, degrees: Double)] = [
            ("deg", 1), ("grad", 0.9), ("rad", 180 / .pi), ("turn", 360),
        ]
        var number = Substring(text)
        var scale = 1.0
        if let unit = units.first(where: { text.hasSuffix($0.suffix) }) {
            number = number.dropLast(unit.suffix.count)
            scale = unit.degrees
        }
        var scanner = XMLParser.Scanner(text: String(number))
        guard let value = try? scanner.scanDouble(), scanner.isEOF else { return nil }
        let degrees = value * scale
        guard degrees.isFinite else { return nil }
        return .angle(DOM.Float(degrees))
    }
}
