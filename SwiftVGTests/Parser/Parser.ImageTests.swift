//
//  Parser.ImageTests.swift
//  SwiftVG
//
//  Created by Simon Whitty on 28/1/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

import XCTest
@testable import SwiftVG

class ParserImageTests: XCTestCase {
    
    func loadXml(_ filename: String) -> XML.Element? {
        let bundle = Bundle(for: TextTests.self)
        let url = bundle.url(forResource: filename, withExtension: nil)!
        return try? XML.SAXParser.parse(contentsOf: url)
    }
    
    func testShapes() {
        
        let element = loadXml("shapes.svg")
        XCTAssertNotNil(element)
        
        
        
        
    }
    
}
