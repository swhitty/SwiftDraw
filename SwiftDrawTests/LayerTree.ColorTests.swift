//
//  ColorTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 3/6/17.
//  Copyright 2020 WhileLoop Pty Ltd. All rights reserved.
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

import DOM
import XCTest

@testable import SwiftDraw

final class LayerTreeColorTests: XCTestCase {
  
  typealias Color = LayerTree.Color
  
  let noColor = Color.none
  let someColor = Color.srgb(r: 0.1, g: 0.2, b: 0.3, a: 0.4)
  let anotherColor = Color.srgb(r: 0.4, g: 0.3, b: 0.2, a: 0.1)
  
  func testStaticColors() {
    XCTAssertEqual(Color.black, .srgb(r: 0, g: 0, b: 0, a: 1.0))
    XCTAssertEqual(Color.white, .srgb(r: 1, g: 1, b: 1, a: 1.0))
  }
  
  func testWithAlpha() {
    //test alpha can be easily adjusted on rgba values
    //apha 0.0 == .none
    
    //.none color cannot change alpha
    XCTAssertEqual(noColor.withAlpha(1.0).maybeNone(), .none)
    XCTAssertEqual(noColor.withAlpha(0.5).maybeNone(), .none)
    XCTAssertEqual(noColor.withAlpha(0.3).maybeNone(), .none)
    XCTAssertEqual(noColor.withAlpha(0.0).maybeNone(), .none)
    
    XCTAssertEqual(someColor.withAlpha(1.0).maybeNone(), .srgb(r: 0.1, g: 0.2, b: 0.3, a: 0.4 * 1))
    XCTAssertEqual(someColor.withAlpha(0.5).maybeNone(), .srgb(r: 0.1, g: 0.2, b: 0.3, a: 0.4 * 0.5))
    XCTAssertEqual(someColor.withAlpha(0.3).maybeNone(), .srgb(r: 0.1, g: 0.2, b: 0.3, a: 0.4 * 0.3))
    XCTAssertEqual(someColor.withAlpha(0.0).maybeNone(), .none)
    
    XCTAssertEqual(anotherColor.withAlpha(1.0).maybeNone(), .srgb(r: 0.4, g: 0.3, b: 0.2, a: 0.1 * 1))
    XCTAssertEqual(anotherColor.withAlpha(0.5).maybeNone(), .srgb(r: 0.4, g: 0.3, b: 0.2, a: 0.1 * 0.5))
    XCTAssertEqual(anotherColor.withAlpha(0.3).maybeNone(), .srgb(r: 0.4, g: 0.3, b: 0.2, a: 0.1 * 0.3))
    XCTAssertEqual(anotherColor.withAlpha(0.0).maybeNone(), .none)
  }
  
  func testMultiplyingAlpha() {
    //test alpha can be easily multiplied on rgba values
    //apha 0.0 == .none
    
    XCTAssertEqual(noColor.withMultiplyingAlpha(1.0), .none)
    XCTAssertEqual(noColor.withMultiplyingAlpha(0.5), .none)
    XCTAssertEqual(noColor.withMultiplyingAlpha(0.3), .none)
    XCTAssertEqual(noColor.withMultiplyingAlpha(0.0), .none)
    
    XCTAssertEqual(someColor.withMultiplyingAlpha(1.0), .srgb(r: 0.1, g: 0.2, b: 0.3, a: 0.4))
    XCTAssertEqual(someColor.withMultiplyingAlpha(0.5), .srgb(r: 0.1, g: 0.2, b: 0.3, a: 0.2))
    XCTAssertEqual(someColor.withMultiplyingAlpha(0.0).maybeNone(), .none)
    
    XCTAssertEqual(anotherColor.withMultiplyingAlpha(1.0), .srgb(r: 0.4, g: 0.3, b: 0.2, a: 0.1))
    XCTAssertEqual(anotherColor.withMultiplyingAlpha(0.5), .srgb(r: 0.4, g: 0.3, b: 0.2, a: 0.05))
    XCTAssertEqual(anotherColor.withMultiplyingAlpha(0.0).maybeNone(), .none)
  }
  
  func testRGBi() {
    //a color can be created from (UInt8, UInt8, UInt8)

    XCTAssertEqual(Color(UInt8(102), UInt8(102), UInt8(102)), .srgb(r: 0.4, g: 0.4, b: 0.4, a: 1.0))
    XCTAssertEqual(Color(UInt8(102), UInt8(0), UInt8(102)), .srgb(r: 0.4, g: 0.0, b: 0.4, a: 1.0))
    XCTAssertEqual(Color(UInt8(102), UInt8(102), UInt8(0)), .srgb(r: 0.4, g: 0.4, b: 0.0, a: 1.0))

    XCTAssertEqual(Color(UInt8(204), UInt8(204), UInt8(204)), .srgb(r: 0.8, g: 0.8, b: 0.8, a: 1.0))
    XCTAssertEqual(Color(UInt8(204), UInt8(0), UInt8(204)), .srgb(r: 0.8, g: 0.0, b: 0.8, a: 1.0))
    XCTAssertEqual(Color(UInt8(204), UInt8(204), UInt8(0)), .srgb(r: 0.8, g: 0.8, b: 0.0, a: 1.0))
  }
  
  func testLuminanceConverter() {
    // svg masks are constructed from 100% black with alpha from the RGB luminance value
    
    let white = Color.white
    let black = Color.black
    let red = Color.srgb(r: 1.0, g: 0.0, b: 0.0, a: 1.0)
    let green = Color.srgb(r: 0.0, g: 1.0, b: 0.0, a: 1.0)
    let blue = Color.srgb(r: 0.0, g: 0.0, b: 1.0, a: 1.0)
    
    let converter = LuminanceColorConverter()
    XCTAssertEqual(converter.createColor(from: white), .gray(white: 0.0, a: 1.0))
    XCTAssertEqual(converter.createColor(from: red), .gray(white: 0.0, a: 0.2126))
    XCTAssertEqual(converter.createColor(from: green), .gray(white: 0.0, a: 0.7152))
    XCTAssertEqual(converter.createColor(from: blue), .gray(white: 0.0, a: 0.0722))
    XCTAssertEqual(converter.createColor(from: black), .gray(white: 0.0, a: 0.0))
  }
  
  func testFromDOM() {
    // DOM.Color converts correctly
    
    let none = DOM.Color.none
    let black = DOM.Color.keyword(.black)
    let white = DOM.Color.keyword(.white)
    let red = DOM.Color.rgbi(255, 0, 0, 1.0)
    let green = DOM.Color.rgbi(0, 255, 0, 1.0)
    let blue = DOM.Color.rgbi(0, 0, 255, 1.0)
    
    XCTAssertEqual(Color(none), .none)
    XCTAssertEqual(Color(black), .srgb(r: 0.0, g: 0.0, b: 0.0, a: 1.0))
    XCTAssertEqual(Color(white), .srgb(r: 1.0, g: 1.0, b: 1.0, a: 1.0))
    XCTAssertEqual(Color(red), .srgb(r: 1.0, g: 0.0, b: 0.0, a: 1.0))
    XCTAssertEqual(Color(green), .srgb(r: 0.0, g: 1.0, b: 0.0, a: 1.0))
    XCTAssertEqual(Color(blue), .srgb(r: 0.0, g: 0.0, b: 1.0, a: 1.0))
  }

  func testCurrentColor() {
      // DOM.Color converts correctly

    let none = DOM.Color.none
    let black = DOM.Color.keyword(.black)
    let white = DOM.Color.keyword(.white)

    XCTAssertEqual(Color.create(from: .currentColor, current: none), .none)
    XCTAssertEqual(Color.create(from: .currentColor, current: black), Color(black))
    XCTAssertEqual(Color.create(from: .currentColor, current: white), Color(white))
  }
}

extension LayerTree.Color {

  init(_ color: DOM.Color) {
    self = LayerTree.Color.create(from: color, current: .none)
  }

  static func srgb(r: LayerTree.Float,
                   g: LayerTree.Float,
                   b: LayerTree.Float,
                   a: LayerTree.Float) -> Self {
    .rgba(r: r, g: g, b: b, a: a, space: .srgb)
  }
}
