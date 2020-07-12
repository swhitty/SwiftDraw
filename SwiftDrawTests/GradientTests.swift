//
//  GradientTests.swift
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

import XCTest
@testable import SwiftDraw

final class GradientTests: XCTestCase {
  
  func testLinerGradient() {
    let node = XML.Element(name: "linearGradient", attributes: ["id": "blue"])
    
    node.children.append(XML.Element(name: "stop", attributes: ["offset": "0%", "stop-color": "black"]))
    node.children.append(XML.Element(name: "stop", attributes: ["offset": "25%", "stop-color": "red"]))
    node.children.append(XML.Element(name: "stop", attributes: ["offset": "50%", "stop-color": "black"]))
    node.children.append(XML.Element(name: "stop", attributes: ["offset": "100%", "stop-color": "red"]))
    
    let expected = DOM.LinearGradient(id: "blue")
    expected.stops.append(DOM.LinearGradient.Stop(offset: 0, color: .keyword(.black)))
    expected.stops.append(DOM.LinearGradient.Stop(offset: 0.25, color: .keyword(.red)))
    expected.stops.append(DOM.LinearGradient.Stop(offset: 0.5, color: .keyword(.black)))
    expected.stops.append(DOM.LinearGradient.Stop(offset: 1, color: .keyword(.red)))
    
    let parsed = try? XMLParser().parseLinearGradient(node)
    XCTAssertEqual(expected, parsed)
    XCTAssertEqual(expected.stops.count, parsed?.stops.count)
  }
  
  func testLinerGradientStop() {
    
    var node = ["offset": "25.5%", "stop-color": "black"]
    
    var parsed = try? XMLParser().parseLinearGradientStop(node)
    XCTAssertEqual(parsed?.offset, 0.255)
    XCTAssertEqual(parsed?.color, .keyword(.black))
    XCTAssertEqual(parsed?.opacity, 1.0)
    
    node["stop-opacity"] = "99%"
    parsed = try? XMLParser().parseLinearGradientStop(node)
    XCTAssertEqual(parsed?.opacity, 0.99)
    
    // test required properties
    node = [:]
    node["offset"] = "10%"
    XCTAssertThrowsError(try XMLParser().parseLinearGradientStop(node))
    node["stop-color"] = "black"
    XCTAssertNotNil(try XMLParser().parseLinearGradientStop(node))
  }

  func testGradientUnits() throws {
    let node = XML.Element(name: "linearGradient", attributes: ["id": "abc"])

    var gradient = try XMLParser().parseLinearGradient(node)
    XCTAssertNil(gradient.gradientUnits)

    node.attributes["gradientUnits"] = "userSpaceOnUse"
    gradient = try XMLParser().parseLinearGradient(node)
    XCTAssertEqual(gradient.gradientUnits, .userSpaceOnUse)

    node.attributes["gradientUnits"] = "objectBoundingBox"
    gradient = try XMLParser().parseLinearGradient(node)
    XCTAssertEqual(gradient.gradientUnits, .objectBoundingBox)

    node.attributes["gradientUnits"] = "invalid"
    XCTAssertThrowsError(try XMLParser().parseLinearGradient(node))
  }
}
