//
//  DOM.Element.Equality.swift
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
@testable import SwiftDraw

extension DOM {
  
  static func createLine() -> DOM.Line {
    return DOM.Line(x1: 0, y1: 1, x2: 3, y2: 4)
  }
  
  static func createCircle() -> DOM.Circle {
    return DOM.Circle(cx: 0, cy: 1, r: 2)
  }
  
  static func createEllipse() -> DOM.Ellipse {
    return DOM.Ellipse(cx: 0, cy: 1, rx: 2, ry: 3)
  }
  
  static func createRect() -> DOM.Rect {
    return DOM.Rect(x: 0, y: 1, width: 2, height: 3)
  }
  
  static func createPolygon() -> DOM.Polygon {
    return DOM.Polygon(0, 1, 2, 3, 4, 5)
  }
  
  static func createPolyline() -> DOM.Polyline {
    return DOM.Polyline(0, 1, 2, 3, 4, 5)
  }
  
  static func createText() -> DOM.Text {
    return DOM.Text(y: 1, value: "The quick brown fox")
  }
  
  static func createPath() -> DOM.Path {
    let path = DOM.Path(x: 0, y: 1)
    path.segments.append(.move(x: 10, y: 10, space: .absolute))
    path.segments.append(.horizontal(x: 10, space: .absolute))
    return path
  }
  
  static func createGroup() -> DOM.Group {
    let group = DOM.Group()
    group.childElements.append(createLine())
    group.childElements.append(createPolygon())
    group.childElements.append(createCircle())
    group.childElements.append(createPath())
    group.childElements.append(createRect())
    group.childElements.append(createEllipse())
    return group
  }
}

// Equatable just for tests

extension DOM.GraphicsElement: Swift.Equatable {
  public static func ==(lhs: DOM.GraphicsElement, rhs: DOM.GraphicsElement) -> Bool {
    let toString: (Any) -> String = { var text = ""; dump($0, to: &text); return text }
    return toString(lhs) == toString(rhs)
  }
}

extension DOM.Polyline {
  // requires even number of elements
  convenience init(_ p: DOM.Coordinate...) {
    
    var points = [DOM.Point]()
    
    for index in stride(from: 0, to: p.count, by: 2) {
      points.append(DOM.Point(p[index], p[index + 1]))
    }
    
    self.init(points: points)
  }
}

extension DOM.Polygon {
  // requires even number of elements
  convenience init(_ p: DOM.Coordinate...) {
    
    var points = [DOM.Point]()
    
    for index in stride(from: 0, to: p.count, by: 2) {
      points.append(DOM.Point(p[index], p[index + 1]))
    }
    
    self.init(points: points)
  }
}

extension XML.Element {
  convenience init(_ name: String, style: String) {
    self.init(name: name, attributes: ["style": style])
  }
  
  convenience init(_ name: String, id: String, style: String) {
    self.init(name: name, attributes: ["id": id, "style": style])
  }
}

extension DOM.SVG {

    static func parse(fileNamed name: String, in bundle: Bundle = .test) throws -> DOM.SVG {
        guard let url = bundle.url(forResource: name, withExtension: nil) else {
            throw Error.missing
        }

        let parser = XMLParser(options: [.skipInvalidElements], filename: url.lastPathComponent)
        let element = try XML.SAXParser.parse(contentsOf: url)
        return try parser.parseSVG(element)
    }

    static func parse(
        xml: String,
        options: SwiftDraw.XMLParser.Options = [.skipInvalidElements]
    ) throws -> DOM.SVG {
        let element = try XML.SAXParser.parse(data: xml.data(using: .utf8)!)
        let parser = XMLParser(options: options)
        return try parser.parseSVG(element)
    }

    enum Error: Swift.Error {
        case missing
    }
}
