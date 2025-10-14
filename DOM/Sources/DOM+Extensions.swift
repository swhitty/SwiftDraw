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

package extension DOM.Polyline {
  // requires even number of elements
  convenience init(_ p: DOM.Coordinate...) {
    
    var points = [DOM.Point]()
    
    for index in stride(from: 0, to: p.count, by: 2) {
      points.append(DOM.Point(p[index], p[index + 1]))
    }
    
    self.init(points: points)
  }
}

package extension DOM.Polygon {
  // requires even number of elements
  convenience init(_ p: DOM.Coordinate...) {
    
    var points = [DOM.Point]()
    
    for index in stride(from: 0, to: p.count, by: 2) {
      points.append(DOM.Point(p[index], p[index + 1]))
    }
    
    self.init(points: points)
  }
}

package extension XML.Element {
  convenience init(_ name: String, style: String) {
    self.init(name: name, attributes: ["style": style])
  }
  
  convenience init(_ name: String, id: String, style: String) {
    self.init(name: name, attributes: ["id": id, "style": style])
  }
}

package extension DOM.SVG {

    static func parse(fileNamed name: String, in bundle: Bundle) throws -> DOM.SVG {
        guard let url = bundle.url(forResource: name, withExtension: nil) else {
            throw Error("missing resource: \(name) in bundle: \(bundle)")
        }

        let parser = XMLParser(options: [.skipInvalidElements], filename: url.lastPathComponent)
        let element = try XML.SAXParser.parse(contentsOf: url)
        return try parser.parseSVG(element)
    }

    static func parse(
        xml: String,
        options: XMLParser.Options = [.skipInvalidElements]
    ) throws -> DOM.SVG {
        let element = try XML.SAXParser.parse(data: xml.data(using: .utf8)!)
        let parser = XMLParser(options: options)
        return try parser.parseSVG(element)
    }

    private struct Error: LocalizedError {
        var errorDescription: String?

        init(_ message: String) {
            self.errorDescription = message
        }
    }
}
