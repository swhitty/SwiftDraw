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

    enum Error: Swift.Error {
        case unsupportedGraphicsElement(DOM.GraphicsElement)
    }

    struct SVG {

        private let formatter: XML.Formatter.CoordinateFormatter

        init(formatter: XML.Formatter.CoordinateFormatter) {
            self.formatter = formatter
        }

        func makeElement(from svg: DOM.SVG) throws -> XML.Element {
            let element = XML.Element(
                name: "svg",
                attributes: makeGraphicsAttributes(from: svg)
            )

            element.attributes["xmlns"] = "http://www.w3.org/2000/svg"
            element.attributes["xmlns:xlink"] = "http://www.w3.org/1999/xlink"
            element.attributes["viewBox"] = makeViewBox(svg.viewBox)

            if svg.viewBox != .init(x: 0, y: 0, width: DOM.Coordinate(svg.width), height: DOM.Coordinate(svg.height)) {
                element.attributes["width"] = formatter.formatLength(svg.width)
                element.attributes["height"] = formatter.formatLength(svg.height)
            }

            if let defs = try makeDefs(svg.defs) {
                element.children.append(defs)
            }

            try element.children.append(
                contentsOf: makeElements(from: svg.childElements)
            )

            return element
        }

        func makeViewBox(_ viewBox: DOM.SVG.ViewBox?) -> String? {
            guard let viewBox = viewBox else { return nil }
            return formatter.format(viewBox.x, viewBox.y, viewBox.width, viewBox.height)
        }

        func makeDefs(_ defs: DOM.SVG.Defs) throws -> XML.Element? {
            let element = XML.Element(name: "defs")

            element.children.append(
                contentsOf: defs.linearGradients.map(makeLinearGradient)
            )

            try element.children.append(
                contentsOf: makeElements(from: defs.elements.values)
            )

            return element.children.isEmpty ? nil : element
        }

        func makeGraphicsAttributes(from graphic: DOM.GraphicsElement) -> [String: String] {
            makeGraphicsAttributes(from: graphic.attributes, element: graphic)
        }

        func makeGraphicsAttributes(from graphic: DOM.PresentationAttributes,
                                    element: ElementAttributes) -> [String: String] {
            var attributes: [String: String] = [:]

            attributes["id"] = element.id
            attributes["opacity"] = formatter.format(graphic.opacity)
            attributes["display"] = graphic.display?.rawValue
            attributes["stroke"] = graphic.stroke.map(encodeFill)
            attributes["stroke-width"] = formatter.format(graphic.strokeWidth)
            attributes["stroke-opacity"] = formatter.format(graphic.strokeOpacity)
            attributes["stroke-linecap"] = graphic.strokeLineCap?.rawValue
            attributes["stroke-linejoin"] = graphic.strokeLineJoin?.rawValue
            attributes["stroke-dasharray"] = graphic.strokeDashArray?
                                                            .map { formatter.format($0) }
                                                            .joined(separator: " ")

            attributes["fill-opacity"] = formatter.format(graphic.fillOpacity)
            attributes["fill"] = graphic.fill.map(encodeFill)
            attributes["fill-rule"] = graphic.fillRule?.rawValue

            attributes["font-family"] = graphic.fontFamily
            attributes["font-size"] = formatter.format(graphic.fontSize)

            attributes["clip-path"] = graphic.clipPath.map(encodeURL)
            attributes["mask"] = graphic.mask.map(encodeURL)
            attributes["transform"] = graphic.transform?
                                                    .map(encodeTransform)
                                                    .joined(separator: " ")
            return attributes
        }

        func makeLinearGradient(_ gradient: DOM.LinearGradient) -> XML.Element {
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

        func makeElements<S: Sequence>(from graphicElements: S) throws -> [XML.Element] where S.Element == DOM.GraphicsElement {
            var elements = [XML.Element]()
            for graphic in graphicElements {
                let elementName = String(describing: graphic).replacingOccurrences(of: "SwiftDraw.", with: "")
                do {
                    elements.append(try makeElement(from: graphic))
                } catch Error.unsupportedGraphicsElement {
                    print("Warning:", elementName, "has no encoder, ignoring element.", to: &.standardError)
                } catch {
                    print("[encoding error]", elementName, "error:", error, to: &.standardError)
                    throw error
                }
            }
            return elements
        }

        func makeElement(from graphic: DOM.GraphicsElement) throws -> XML.Element {

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
                throw Error.unsupportedGraphicsElement(graphic)
            }

            if let container = graphic as? ContainerElement {
                try element.children.append(
                    contentsOf: makeElements(from: container.childElements)
                )
            }

            return element
        }

        func makeElement(from rect: DOM.Rect) -> XML.Element {
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

        func makeElement(from use: DOM.Use) -> XML.Element {
            let element = XML.Element(
                name: "use",
                attributes: makeGraphicsAttributes(from: use)
            )

            element.attributes["xlink:href"] = use.href.absoluteString
            element.attributes["x"] = use.x.map { String($0) }
            element.attributes["y"] = use.y.map { String($0) }
            return element
        }

        func makeElement(from group: DOM.Group) -> XML.Element {
            let element = XML.Element(
                name: "g",
                attributes: makeGraphicsAttributes(from: group)
            )

            return element
        }

        func makeElement(from text: DOM.Text) -> XML.Element {
            let element = XML.Element(
                name: "text",
                attributes: makeGraphicsAttributes(from: text)
            )
            element.innerText = text.value
            element.attributes["x"] = text.x.map { String($0) }
            element.attributes["y"] = text.y.map { String($0) }
            return element
        }

        func makeElement(from path: DOM.Path) -> XML.Element {
            let element = XML.Element(
                name: "path",
                attributes: makeGraphicsAttributes(from: path)
            )
            element.attributes["d"] = encodeSegments(path.segments)
            return element
        }

        func encodeFill(from fill: DOM.Fill) -> String {
            switch fill {
            case .color(let color):
                return encodeColor(from: color)
            case .url(let url):
                return encodeURL(url)
            }
        }

        func encodeURL(_ url: URL) -> String {
            "url(\(url.absoluteString))"
        }

        func encodeColor(from color: DOM.Color) -> String {
            switch color {
            case .none:
                return "none"
            case .currentColor:
                return "currentColor"
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

        func encodeTransform(_ transform: DOM.Transform) -> String {
            switch transform {
            case let .matrix(a: a, b: b, c: c, d: d, e: e, f: f):
                return "matrix(\(formatter.format(a,b,c,d,e,f)))"
            case let .translate(tx: tx, ty: ty):
                return "translate(\(formatter.format(tx, ty))"
            case let .scale(sx: sx, sy: sy):
                return "scale(\(formatter.format(sx, sy))"
            case let .rotate(angle: angle):
                return "rotate(\(formatter.format(angle))"
            case let .rotatePoint(angle: angle, cx: cx, cy: cy):
                return "rotate(\(formatter.format(angle, cx, cy))"
            case let .skewX(angle: angle):
                return "skewX(\(formatter.format(angle))"
            case let .skewY(angle: angle):
                return "skewY(\(formatter.format(angle))"
            }
        }

        func encodeSegments(_ segments: [DOM.Path.Segment]) -> String {
            let encoded = segments.map(encodeSegment)
            return encoded.joined(separator: " ")
        }

        func encodeSegment(_ segment: DOM.Path.Segment) -> String {
            switch segment {
            case .move(x: let x, y: let y, space: let space):
                let cmd: DOM.Path.Command = space == .absolute ? .move : .moveRelative
                let point = formatter.format(x, y)
                return "\(cmd.rawValue)\(point)"
            case .line(x: let x, y: let y, space: let space):
                let cmd: DOM.Path.Command = space == .absolute ? .line : .lineRelative
                let point = formatter.format(x, y)
                return "\(cmd.rawValue)\(point)"
            case .horizontal(x: let x, space: let space):
                let cmd: DOM.Path.Command = space == .absolute ? .horizontal : .horizontalRelative
                let x = formatter.format(x)
                return "\(cmd.rawValue)\(x)"
            case .vertical(y: let y, space: let space):
                let cmd: DOM.Path.Command = space == .absolute ? .vertical : .verticalRelative
                let y = formatter.format(y)
                return "\(cmd.rawValue)\(y)"
            case .cubic(x1: let x1, y1: let y1, x2: let x2, y2: let y2, x: let x, y: let y, space: let space):
                let cmd: DOM.Path.Command = space == .absolute ? .cubic : .cubicRelative
                let control1 = formatter.format(x1, y1)
                let control2 = formatter.format(x2, y2)
                let point = formatter.format(x, y)
                return "\(cmd.rawValue)\(control1) \(control2) \(point)"
            case .cubicSmooth(x2: let x2, y2: let y2, x: let x, y: let y, space: let space):
                let cmd: DOM.Path.Command = space == .absolute ? .cubicSmooth : .cubicSmoothRelative
                let control = formatter.format(x2, y2)
                let point = formatter.format(x, y)
                return "\(cmd.rawValue)\(control) \(point)"
            case .quadratic(x1: let x1, y1: let y1, x: let x, y: let y, space: let space):
                let cmd: DOM.Path.Command = space == .absolute ? .quadratic : .quadraticRelative
                let control = formatter.format(x1, y1)
                let point = formatter.format(x, y)
                return "\(cmd.rawValue)\(control) \(point)"
            case .quadraticSmooth(x: let x, y: let y, space: let space):
                let cmd: DOM.Path.Command = space == .absolute ? .quadraticSmooth : .quadraticSmoothRelative
                let point = formatter.format(x, y)
                return "\(cmd.rawValue)\(point)"
            case .arc(rx: let rx, ry: let ry, rotate: let rotate, large: let large, sweep: let sweep, x: let x, y: let y, space: let space):
                let cmd: DOM.Path.Command = space == .absolute ? .arc : .arcRelative
                let r = formatter.format(rx, ry)
                let rotate = formatter.format(rotate)
                let large = formatter.format(large)
                let sweep = formatter.format(sweep)
                let point = formatter.format(x, y)
                return "\(cmd.rawValue)\(r) \(rotate) \(large) \(sweep) \(point)"
            case .close:
                let cmd = DOM.Path.Command.close
                return "\(cmd.rawValue)"
            }
        }
    }
}
