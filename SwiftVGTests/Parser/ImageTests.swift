//
//  ImageTests.swift
//  SwiftVG
//
//  Created by Simon Whitty on 7/3/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

import Foundation

import XCTest
@testable import SwiftVG

extension CGImage {
    static func from(data: Data) -> CGImage? {
    #if os(iOS)
        return UIImage(data: data)?.cgImage
    #elseif os(macOS)
        guard let image = NSImage(data: data) else { return nil }
        var rect = NSRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    #endif
    }
}

class ImageTests: XCTestCase {
    
    func testImage() throws {
        var node = ["xlink:href": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg=="]
        node["width"] = "10"
        node["height"] = "10"
        
        let image = try XMLParser().parseImage(node)
        
        XCTAssertTrue(image.href.isDataURL)
        
        let decode = image.href.decodedData!
        
        XCTAssertEqual(decode.mimeType, "image/png")
        
        let cgImage = CGImage.from(data: decode.data)
        
        XCTAssertNotNil(cgImage)
        XCTAssertEqual(cgImage?.width, 5)
        XCTAssertEqual(cgImage?.height, 5)
    }
    
    func testImageLineBreaks() throws {
        let base64 = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblA " + "\n" +
                    " AAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg=="

        let node = ["xlink:href": base64, "width": "10", "height": "10"]
        
        let image = try XMLParser().parseImage(node)
        
        XCTAssertTrue(image.href.isDataURL)
        
        let decode = image.href.decodedData!
        
        XCTAssertEqual(decode.mimeType, "image/png")
        
        let cgImage = CGImage.from(data: decode.data)
        
        XCTAssertNotNil(cgImage)
        XCTAssertEqual(cgImage?.width, 5)
        XCTAssertEqual(cgImage?.height, 5)
    }
}
