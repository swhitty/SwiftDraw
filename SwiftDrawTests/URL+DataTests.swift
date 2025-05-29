//
//  URL.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 28/2/17.
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

import SwiftDrawDOM
import XCTest
@testable import SwiftDraw

final class URLTests: XCTestCase {

  func testDecodedData() {
    let url = URL(maybeData: "data:image/png;base64,f00d")
    XCTAssertEqual(url?.decodedData?.mimeType, "image/png")
    XCTAssertEqual(url?.decodedData?.data.base64EncodedString(), "f00d")
    
    XCTAssertNil(URL(maybeData: "data:;base64,f00d")?.decodedData)
    XCTAssertNil(URL(maybeData: "data:image/png;bas,f00d")?.decodedData)
    XCTAssertNil(URL(maybeData: "data:image/png;base64")?.decodedData)
    XCTAssertNil(URL(maybeData: "data:image/png;base64,")?.decodedData)
  }

  func testDataURL() {
    XCTAssertTrue(URL(maybeData: "data:image/png;base64,f00d")!.isDataURL)
    XCTAssertTrue(URL(maybeData: "data:f00d")!.isDataURL)
    XCTAssertFalse(URL(maybeData: "#identifier")!.isDataURL)
    XCTAssertFalse(URL(maybeData: "data")!.isDataURL)
    XCTAssertFalse(URL(maybeData: "www.google.com")!.isDataURL)
  }

  func testDecodedDataLineBreak() {
    let url = URL(maybeData: "data:image/png;base64,8badf00d\n\t 8badf00d")
    XCTAssertEqual(url?.decodedData?.mimeType, "image/png")
    XCTAssertEqual(url?.decodedData?.data.base64EncodedString(), "8badf00d8badf00d")
  }

}

