//
//  DOM.ElementTests.swift
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
@testable import DOM

final class DOMElementTests: XCTestCase {
  
  func testLine() {
    let element = DOM.createLine()
    var another = DOM.createLine()
    
    XCTAssertEqual(element, another)
    
    another.x1 = 1
    XCTAssertNotEqual(element, another)
    
    another = DOM.createLine()
    another.attributes.fill = .color(.keyword(.black))
    XCTAssertNotEqual(element, another)
    
    another.attributes.fill = nil
    XCTAssertEqual(element, another)
  }
  
  func testCircle() {
    let element = DOM.createCircle()
    var another = DOM.createCircle()
    
    XCTAssertEqual(element, another)
    
    another.cx = 1
    XCTAssertNotEqual(element, another)
    
    another = DOM.createCircle()
    another.attributes.fill = .color(.keyword(.black))
    XCTAssertNotEqual(element, another)
    
    another.attributes.fill = nil
    XCTAssertEqual(element, another)
  }
  
  func testEllipse() {
    let element = DOM.createEllipse()
    var another = DOM.createEllipse()
    
    XCTAssertEqual(element, another)
    
    another.cx = 1
    XCTAssertNotEqual(element, another)
    
    another = DOM.createEllipse()
    another.attributes.fill = .color(.keyword(.black))
    XCTAssertNotEqual(element, another)
    
    another.attributes.fill = nil
    XCTAssertEqual(element, another)
  }
  
  func testRect() {
    let element = DOM.createRect()
    var another = DOM.createRect()
    
    XCTAssertEqual(element, another)
    
    another.x = 1
    XCTAssertNotEqual(element, another)
    
    another = DOM.createRect()
    another.attributes.fill = .color(.keyword(.black))
    XCTAssertNotEqual(element, another)
    
    another.attributes.fill = nil
    XCTAssertEqual(element, another)
  }
  
  func testPolygon() {
    let element = DOM.createPolygon()
    var another = DOM.createPolygon()
    
    XCTAssertEqual(element, another)
    
    another.points.append(DOM.Point(6, 7))
    XCTAssertNotEqual(element, another)
    
    another = DOM.createPolygon()
    another.attributes.fill = .color(.keyword(.black))
    XCTAssertNotEqual(element, another)
    
    another.attributes.fill = nil
    XCTAssertEqual(element, another)
  }
  
  func testPolyline() {
    let element = DOM.createPolyline()
    var another = DOM.createPolyline()
    
    XCTAssertEqual(element, another)
    
    another.points.append(DOM.Point(6, 7))
    XCTAssertNotEqual(element, another)
    
    another = DOM.createPolyline()
    another.attributes.fill = .color(.keyword(.black))
    XCTAssertNotEqual(element, another)
    
    another.attributes.fill = nil
    XCTAssertEqual(element, another)
  }
  
  func testText() {
    let element = DOM.createText()
    var another = DOM.createText()
    
    XCTAssertEqual(element, another)
    
    another.value = "Simon"
    XCTAssertNotEqual(element, another)
    
    another = DOM.createText()
    another.attributes.fill = .color(.keyword(.black))
    XCTAssertNotEqual(element, another)
    
    another.attributes.fill = nil
    XCTAssertEqual(element, another)
  }
  
  func testGroup() {
    let group = DOM.createGroup()
    var another = DOM.createGroup()
    
    XCTAssertEqual(group, another)
    
    another.childElements.append(DOM.createCircle())
    XCTAssertNotEqual(group, another)
    
    another = DOM.createGroup()
    another.attributes.fill = .color(.keyword(.black))
    XCTAssertNotEqual(group, another)
    
    another.attributes.fill = nil
    XCTAssertEqual(group, another)
  }
}
