//
//  UseTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 27/2/17.
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

final class UseTests: XCTestCase {
  
  func testUse() throws {
    var node = ["xlink:href": "#line2", "href": "#line1"]
    
    var parsed = try XMLParser().parseUse(node)
    XCTAssertEqual(parsed.href.fragment, "line2")
    XCTAssertNil(parsed.x)
    XCTAssertNil(parsed.y)
    
    node["x"] = "20"
    node["y"] = "30"
    
    parsed = try XMLParser().parseUse(node)
    XCTAssertEqual(parsed.href.fragment, "line2")
    XCTAssertEqual(parsed.x, 20)
    XCTAssertEqual(parsed.y, 30)
  }
}
