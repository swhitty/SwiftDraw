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
        let url = URL(string: "data:image/png;base64,f00d")
        XCTAssertEqual(url?.decodedData?.mimeType, "image/png")
        XCTAssertEqual(url?.decodedData?.data.base64EncodedString(), "f00d")
        
        XCTAssertNil(URL(string: "data:;base64,f00d")?.decodedData)
        XCTAssertNil(URL(string: "data:image/png;bas,f00d")?.decodedData)
        XCTAssertNil(URL(string: "data:image/png;base64")?.decodedData)
        XCTAssertNil(URL(string: "data:image/png;base64,")?.decodedData)
    }
    
    func testDataURL() {
        XCTAssertTrue(URL(string: "data:image/png;base64,f00d")!.isDataURL)
        XCTAssertTrue(URL(string: "data:f00d")!.isDataURL)
        XCTAssertFalse(URL(string: "#identifier")!.isDataURL)
        XCTAssertFalse(URL(string: "data")!.isDataURL)
        XCTAssertFalse(URL(string: "www.google.com")!.isDataURL)
    }
}

