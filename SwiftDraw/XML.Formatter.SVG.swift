//
//  XML.swift
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

import Foundation

extension XML.Formatter {
    struct SVG {

        static func makeElement(from svg: DOM.SVG) -> XML.Element {
            let element = XML.Element(
                name: "svg",
                attributes: ["xmlns": "http://www.w3.org/2000/svg",
                             "xmlns:xlink": "http://www.w3.org/1999/xlink"]
            )

            element.attributes["viewBox"] = makeViewBox(svg.viewBox)

            if svg.viewBox != .init(x: 0, y: 0, width: DOM.Coordinate(svg.width), height: DOM.Coordinate(svg.height)) {
                element.attributes["width"] = String(svg.width)
                element.attributes["height"] = String(svg.height)
            }

            if let defs = makeDefs(svg.defs) {
                element.children.append(defs)
            }

            element.children.append(
                contentsOf: svg.childElements.map(makeElement)
            )

            return element
        }

        static func makeViewBox(_ viewBox: DOM.SVG.ViewBox?) -> String? {
            guard let viewBox = viewBox else { return nil }
            return [
                String(viewBox.x),
                String(viewBox.y),
                String(viewBox.width),
                String(viewBox.height)
            ].joined(separator: " ")
        }

        static func makeDefs(_ defs: DOM.SVG.Defs) -> XML.Element? {
            let element = XML.Element(name: "defs")

            element.children.append(
                contentsOf: defs.linearGradients.map(makeLinearGradient)
            )

            element.children.append(
                contentsOf: defs.elements.values.map(makeElement)
            )

            return element.children.isEmpty ? nil : element
        }

        static func makeGraphicsAttributes(from graphic: DOM.GraphicsElement) -> [String: String] {
            var attributes: [String: String] = [:]

            attributes["id"] = graphic.id
            attributes["opacity"] = graphic.opacity.map { String($0) }
            attributes["display"] = graphic.display?.rawValue
            attributes["stroke"] = graphic.stroke.map(encodeColor)
            attributes["stroke-width"] = graphic.strokeWidth.map { String($0) }
            attributes["stroke-opacity"] = graphic.strokeOpacity.map { String($0) }
            attributes["stroke-linecap"] = graphic.strokeLineCap?.rawValue
            attributes["stroke-linejoin"] = graphic.strokeLineJoin?.rawValue
            attributes["stroke-dasharray"] = graphic.strokeDashArray?
                                                            .map { String($0) }
                                                            .joined(separator: " ")

            attributes["fill-opacity"] = graphic.fillOpacity.map { String($0) }
            attributes["fill"] = graphic.fill.map(encodeFill)
            attributes["fill-rule"] = graphic.fillRule?.rawValue

            attributes["font-family"] = graphic.fontFamily
            attributes["font-size"] = graphic.fontSize.map { String($0) }

            attributes["clip-path"] = graphic.clipPath.map(encodeURL)
            attributes["mask"] = graphic.mask.map(encodeURL)
            attributes["transform"] = graphic.transform?
                                                    .map(encodeTransform)
                                                    .joined(separator: " ")
            return attributes
        }

        static func makeLinearGradient(_ gradient: DOM.LinearGradient) -> XML.Element {
            let element = XML.Element(
                name: "linearGradient",
                attributes: ["id": gradient.id]
            )
            element.attributes["x1"] = gradient.x1.map { String($0) }
            element.attributes["x2"] = gradient.x2.map { String($0) }
            element.attributes["y1"] = gradient.y1.map { String($0) }
            element.attributes["y2"] = gradient.y2.map { String($0) }
            return element
        }

        static func makeElement(from graphic: DOM.GraphicsElement) -> XML.Element {

            let element: XML.Element

            if let rect = graphic as? DOM.Rect {
                element = makeElement(from: rect)
            } else if let use = graphic as? DOM.Use {
                element = makeElement(from: use)
            } else if let group = graphic as? DOM.Group {
                element = makeElement(from: group)
            } else if let text = graphic as? DOM.Text {
                element = makeElement(from: text)
            } else if let path = graphic as? DOM.Path {
                element = makeElement(from: path)
            } else {
                fatalError("Element not supported \(graphic)")
            }

            if let container = graphic as? ContainerElement {
                element.children.append(
                    contentsOf: container.childElements.map(makeElement)
                )
            }

            return element
        }

        static func makeElement(from rect: DOM.Rect) -> XML.Element {
            let element = XML.Element(
                name: "rect",
                attributes: makeGraphicsAttributes(from: rect)
            )

            element.attributes["width"] = String(rect.width)
            element.attributes["height"] = String(rect.height)
            element.attributes["x"] = rect.x.map { String($0) }
            element.attributes["y"] = rect.y.map { String($0) }
            element.attributes["rx"] = rect.rx.map { String($0) }
            element.attributes["ry"] = rect.ry.map { String($0) }
            return element
        }

        static func makeElement(from use: DOM.Use) -> XML.Element {
            let element = XML.Element(
                name: "use",
                attributes: makeGraphicsAttributes(from: use)
            )

            element.attributes["xlink:href"] = use.href.absoluteString
            element.attributes["x"] = use.x.map { String($0) }
            element.attributes["y"] = use.y.map { String($0) }
            return element
        }

        static func makeElement(from group: DOM.Group) -> XML.Element {
            let element = XML.Element(
                name: "g",
                attributes: makeGraphicsAttributes(from: group)
            )

            return element
        }

        static func makeElement(from text: DOM.Text) -> XML.Element {
            let element = XML.Element(
                name: "text",
                attributes: makeGraphicsAttributes(from: text)
            )
            element.innerText = text.value
            element.attributes["x"] = text.x.map { String($0) }
            element.attributes["y"] = text.y.map { String($0) }
            return element
        }

        static func makeElement(from path: DOM.Path) -> XML.Element {
            let element = XML.Element(
                name: "path",
                attributes: makeGraphicsAttributes(from: path)
            )
            element.attributes["d"] = encodeSegments(path.segments)
            return element
        }

        static func encodeFill(from fill: DOM.Fill) -> String {
            switch fill {
            case .color(let color):
                return encodeColor(from: color)
            case .url(let url):
                return encodeURL(url)
            }
        }

        static func encodeURL(_ url: URL) -> String {
            "url(\(url.absoluteString))"
        }

        static func encodeColor(from color: DOM.Color) -> String {
            switch color {
            case .none:
                return "none"
            case let .keyword(k):
                return k.rawValue
            case let .rgbi(r, g, b):
                return "rgb(\(r), \(g), \(b))"
            case let .rgbf(r, g, b):
                let rr = String(format: "%.0f", r * 100)
                let gg = String(format: "%.0f", g * 100)
                let bb = String(format: "%.0f", b * 100)
                return "rgb(\(rr)%, \(gg)%, \(bb)%)"
            case let .p3(r, g, b):
                return "color(display-p3 \(r), \(g), \(b))"
            case let .hex(r, g, b):
                let rr = String(format: "%02X", r)
                let gg = String(format: "%02X", g)
                let bb = String(format: "%02X", b)
                return "#\(rr)\(gg)\(bb)"
            }
        }

        static func encodeTransform(_ transform: DOM.Transform) -> String {
            switch transform {
            case let .matrix(a: a, b: b, c: c, d: d, e: e, f: f):
                return "matrix(\(a), \(b), \(c), \(d), \(e), \(f))"
            case let .translate(tx: tx, ty: ty):
                return "translate(\(tx), \(ty)"
            case let .scale(sx: sx, sy: sy):
                return "scale(\(sx), \(sy)"
            case let .rotate(angle: angle):
                return "rotate(\(angle))"
            case let .rotatePoint(angle: angle, cx: cx, cy: cy):
                return "rotate(\(angle), \(cx), \(cy))"
            case let .skewX(angle: angle):
                return "skewX(\(angle))"
            case let .skewY(angle: angle):
                return "skewY(\(angle))"
            }
        }

        static func encodeSegments(_ segments: [DOM.Path.Segment]) -> String {
            segments.map(encodeSegment).joined(separator: " ")
        }

        static func encodeSegment(_ segment: DOM.Path.Segment) -> String {
            switch segment {
            case .move(x: let x, y: let y, space: let space):
                let cmd: DOM.Path.Command = space == .absolute ? .move : .moveRelative
                return "\(cmd.rawValue)\(x),\(y)"
            case .line(x: let x, y: let y, space: let space):
                let cmd: DOM.Path.Command = space == .absolute ? .line : .lineRelative
                return "\(cmd.rawValue)\(x),\(y)"
            case .horizontal(x: let x, space: let space):
                let cmd: DOM.Path.Command = space == .absolute ? .horizontal : .horizontalRelative
                return "\(cmd.rawValue)\(x)"
            case .vertical(y: let y, space: let space):
                let cmd: DOM.Path.Command = space == .absolute ? .vertical : .verticalRelative
                return "\(cmd.rawValue)\(y)"
            case .cubic(x1: let x1, y1: let y1, x2: let x2, y2: let y2, x: let x, y: let y, space: let space):
                let cmd: DOM.Path.Command = space == .absolute ? .cubic : .cubicRelative
                return "\(cmd.rawValue)\(x1),\(y1) \(x2),\(y2) \(x),\(y)"
            case .cubicSmooth(x2: let x2, y2: let y2, x: let x, y: let y, space: let space):
                let cmd: DOM.Path.Command = space == .absolute ? .cubicSmooth : .cubicSmoothRelative
                return "\(cmd.rawValue)\(x2),\(y2) \(x),\(y)"
            case .quadratic(x1: let x1, y1: let y1, x: let x, y: let y, space: let space):
                let cmd: DOM.Path.Command = space == .absolute ? .quadratic : .quadraticRelative
                return "\(cmd.rawValue)\(x1),\(y1) \(x),\(y)"
            case .quadraticSmooth(x: let x, y: let y, space: let space):
                let cmd: DOM.Path.Command = space == .absolute ? .quadraticSmooth : .quadraticSmoothRelative
                return "\(cmd.rawValue)\(x),\(y)"
            case .arc(rx: let rx, ry: let ry, rotate: let rotate, large: let large, sweep: let sweep, x: let x, y: let y, space: let space):
                let cmd: DOM.Path.Command = space == .absolute ? .arc : .arcRelative
                return "\(cmd.rawValue)\(rx),\(ry) \(rotate) \(large), \(sweep) \(x),\(y)"
            case .close:
                let cmd = DOM.Path.Command.close
                return "\(cmd.rawValue)"
            }
        }
    }
}
