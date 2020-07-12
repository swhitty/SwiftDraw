//
//  Parser.XML.Gradient.swift
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
        gradients.append(try parseLinearGradient(n))
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
    
    let nodeAtt: AttributeParser = try parseAttributes(e)
    let node = DOM.LinearGradient(id: try nodeAtt.parseString("id"))
    node.x1 = try nodeAtt.parseCoordinate("x1")
    node.y1 = try nodeAtt.parseCoordinate("y1")
    node.x2 = try nodeAtt.parseCoordinate("x2")
    node.y2 = try nodeAtt.parseCoordinate("y2")
    
    for n in e.children where n.name == "stop" {
      let att: AttributeParser = try parseAttributes(n)
      node.stops.append(try parseLinearGradientStop(att))
    }

    node.gradientUnits = try nodeAtt.parseRaw("gradientUnits")
    node.href  = try? nodeAtt.parseUrl("xlink:href")
    
    return node
  }
  
  func parseLinearGradientStop(_ att: AttributeParser) throws -> DOM.LinearGradient.Stop {
    let offset: DOM.Float = try att.parsePercentage("offset")
    let color: DOM.Color = try att.parseFill("stop-color").getColor()
    let opacity: DOM.Float? = try att.parsePercentage("stop-opacity")
    return DOM.LinearGradient.Stop(offset: offset, color: color, opacity: opacity ?? 1.0)
  }
}
