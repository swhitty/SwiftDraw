//
//  GradientTests.swift
//  SwiftVG
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright © 2016 WhileLoop Pty Ltd. All rights reserved.
//

import XCTest
@testable import SwiftVG

class GradientTests: XCTestCase {
    
    func testLinerGradient() {
        let node = XML.Element(name: "linearGradient")
        
        node.children.append(XML.Element(name: "stop", attributes: ["offset": "0%", "stop-color": "black"]))
        node.children.append(XML.Element(name: "stop", attributes: ["offset": "25%", "stop-color": "red"]))
        node.children.append(XML.Element(name: "stop", attributes: ["offset": "50%", "stop-color": "black"]))
        node.children.append(XML.Element(name: "stop", attributes: ["offset": "100%", "stop-color": "red"]))
        
        let expected = DOM.LinearGradient()
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
}
