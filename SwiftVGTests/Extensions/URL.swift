//
//  URL.swift
//  SwiftVG
//
//  Created by Simon Whitty on 28/2/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

import XCTest
@testable import SwiftVG

class URLTests: XCTestCase {
    
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

