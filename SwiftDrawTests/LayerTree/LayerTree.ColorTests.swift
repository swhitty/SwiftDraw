//
//  LayerTree.ColorTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 3/6/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
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

class LayerTreeColorTests: XCTestCase {
    
    let noColor = LayerTree.Color.none
    let someColor = LayerTree.Color.rgba(r: 0.1, g: 0.2, b: 0.3, a: 0.4)
    let anotherColor = LayerTree.Color.rgba(r: 0.4, g: 0.3, b: 0.2, a: 0.1)
    
    func testEquality() {
        XCTAssertEqual(noColor, .none)
        XCTAssertEqual(someColor, .rgba(r: 0.1, g: 0.2, b: 0.3, a: 0.4))
        XCTAssertEqual(anotherColor, .rgba(r: 0.4, g: 0.3, b: 0.2, a: 0.1))
        
        XCTAssertNotEqual(noColor, someColor)
        XCTAssertNotEqual(noColor, anotherColor)
        XCTAssertNotEqual(someColor, anotherColor)
    }
    
    func testWithAlpha() {
        //test alpha can be easily adjusted on rgba values
        //apha 0.0 == .none
        
        //.none color cannot change alpha
        XCTAssertEqual(noColor.withAlpha(1.0), .none)
        XCTAssertEqual(noColor.withAlpha(0.5), .none)
        XCTAssertEqual(noColor.withAlpha(0.3), .none)
        XCTAssertEqual(noColor.withAlpha(0.0), .none)
        
        XCTAssertEqual(someColor.withAlpha(1.0), .rgba(r: 0.1, g: 0.2, b: 0.3, a: 1.0))
        XCTAssertEqual(someColor.withAlpha(0.5), .rgba(r: 0.1, g: 0.2, b: 0.3, a: 0.5))
        XCTAssertEqual(someColor.withAlpha(0.3), .rgba(r: 0.1, g: 0.2, b: 0.3, a: 0.3))
        XCTAssertEqual(someColor.withAlpha(0.0), .none)
        
        XCTAssertEqual(anotherColor.withAlpha(1.0), .rgba(r: 0.4, g: 0.3, b: 0.2, a: 1.0))
        XCTAssertEqual(anotherColor.withAlpha(0.5), .rgba(r: 0.4, g: 0.3, b: 0.2, a: 0.5))
        XCTAssertEqual(anotherColor.withAlpha(0.3), .rgba(r: 0.4, g: 0.3, b: 0.2, a: 0.3))
        XCTAssertEqual(anotherColor.withAlpha(0.0), .none)
    }
    
    func testMultiplyingAlpha() {
        //test alpha can be easily multiplied on rgba values
        //apha 0.0 == .none
        
        XCTAssertEqual(noColor.withMultiplyingAlpha(1.0), .none)
        XCTAssertEqual(noColor.withMultiplyingAlpha(0.5), .none)
        XCTAssertEqual(noColor.withMultiplyingAlpha(0.3), .none)
        XCTAssertEqual(noColor.withMultiplyingAlpha(0.0), .none)
        
        XCTAssertEqual(someColor.withMultiplyingAlpha(1.0), .rgba(r: 0.1, g: 0.2, b: 0.3, a: 0.4))
        XCTAssertEqual(someColor.withMultiplyingAlpha(0.5), .rgba(r: 0.1, g: 0.2, b: 0.3, a: 0.2))
        XCTAssertEqual(someColor.withMultiplyingAlpha(0.0), .none)
        
        XCTAssertEqual(anotherColor.withMultiplyingAlpha(1.0), .rgba(r: 0.4, g: 0.3, b: 0.2, a: 0.1))
        XCTAssertEqual(anotherColor.withMultiplyingAlpha(0.5), .rgba(r: 0.4, g: 0.3, b: 0.2, a: 0.05))
        XCTAssertEqual(anotherColor.withMultiplyingAlpha(0.0), .none)
    }
    
    func testRGBi() {
        //a color can be created from (UInt8, UInt8, UInt8)
        
        XCTAssertEqual(LayerTree.Color((UInt8(102), UInt8(102), UInt8(102))), .rgba(r: 0.4, g: 0.4, b: 0.4, a: 1.0))
        XCTAssertEqual(LayerTree.Color((UInt8(102), UInt8(0), UInt8(102))), .rgba(r: 0.4, g: 0.0, b: 0.4, a: 1.0))
        XCTAssertEqual(LayerTree.Color((UInt8(102), UInt8(102), UInt8(0))), .rgba(r: 0.4, g: 0.4, b: 0.0, a: 1.0))
        
        XCTAssertEqual(LayerTree.Color((UInt8(204), UInt8(204), UInt8(204))), .rgba(r: 0.8, g: 0.8, b: 0.8, a: 1.0))
        XCTAssertEqual(LayerTree.Color((UInt8(204), UInt8(0), UInt8(204))), .rgba(r: 0.8, g: 0.0, b: 0.8, a: 1.0))
        XCTAssertEqual(LayerTree.Color((UInt8(204), UInt8(204), UInt8(0))), .rgba(r: 0.8, g: 0.8, b: 0.0, a: 1.0))
    }
    
    func testLuminanceToAlpha() {
        // svg masks are constructed from 100% black with alpha from the RGB luminance value
        
        let white = LayerTree.Color.rgba(r: 1.0, g: 1.0, b: 1.0, a: 1.0)
        let black = LayerTree.Color.rgba(r: 0.0, g: 0.0, b: 0.0, a: 1.0)
        let clear = LayerTree.Color.rgba(r: 0.0, g: 0.0, b: 0.0, a: 1.0)
        let red = LayerTree.Color.rgba(r: 1.0, g: 0.0, b: 0.0, a: 1.0)
        let green = LayerTree.Color.rgba(r: 0.0, g: 1.0, b: 0.0, a: 1.0)
        let blue = LayerTree.Color.rgba(r: 0.0, g: 0.0, b: 1.0, a: 1.0)
        
        //should be completley masked away
        XCTAssertEqual(noColor.luminanceToAlpha(), .none)
        XCTAssertEqual(black.luminanceToAlpha(), .none)
        XCTAssertEqual(clear.luminanceToAlpha(), .none)
        
        XCTAssertEqual(white.luminanceToAlpha(), black.withAlpha(1.0))
        XCTAssertEqual(red.luminanceToAlpha(), black.withAlpha(0.2126))
        XCTAssertEqual(green.luminanceToAlpha(), black.withAlpha(0.7152))
        XCTAssertEqual(blue.luminanceToAlpha(), black.withAlpha(0.0722))
    }
    
    func testFromDOM() {
        // DOM.Color converts correctly
        
        let none = DOM.Color.none
        let black = DOM.Color.keyword(.black)
        let white = DOM.Color.keyword(.white)
        let red = DOM.Color.rgbi(255, 0, 0)
        let green = DOM.Color.rgbi(0, 255, 0)
        let blue = DOM.Color.rgbi(0, 0, 255)
        
        XCTAssertEqual(LayerTree.Color(none), .none)
        XCTAssertEqual(LayerTree.Color(black), .rgba(r: 0.0, g: 0.0, b: 0.0, a: 1.0))
        XCTAssertEqual(LayerTree.Color(white), .rgba(r: 1.0, g: 1.0, b: 1.0, a: 1.0))
        XCTAssertEqual(LayerTree.Color(red), .rgba(r: 1.0, g: 0.0, b: 0.0, a: 1.0))
        XCTAssertEqual(LayerTree.Color(green), .rgba(r: 0.0, g: 1.0, b: 0.0, a: 1.0))
        XCTAssertEqual(LayerTree.Color(blue), .rgba(r: 0.0, g: 0.0, b: 1.0, a: 1.0))
    }

}

