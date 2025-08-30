//
//  Parser.XML.ImageTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 3/3/17.
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


import Foundation

@testable import SwiftDrawDOM
import Testing
#if canImport(CoreGraphics)
import CoreGraphics

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension CGImage {
    static func from(data: Data) -> CGImage? {
#if canImport(UIKit)
        return UIImage(data: data)?.cgImage
#elseif canImport(AppKit)
        guard let image = NSImage(data: data) else { return nil }
        var rect = NSRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
#endif
    }
}

struct ParserXMLImageTests {

    @Test
    func image() throws {
        var node = ["xlink:href": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg=="]
        node["width"] = "10"
        node["height"] = "10"

        let image = try XMLParser().parseImage(node)

        #expect(image.href.isDataURL)

        let decode = try #require(image.href.decodedData)

        #expect(decode.mimeType == "image/png")

        let cgImage = CGImage.from(data: decode.data)

        #expect(cgImage != nil)
        #expect(cgImage?.width == 5)
        #expect(cgImage?.height == 5)
    }

    @Test
    func imageLineBreaks() throws {
        let base64 = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblA " + "\n" +
        " AAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg=="

        let node = ["xlink:href": base64, "width": "10", "height": "10"]

        let image = try XMLParser().parseImage(node)

        #expect(image.href.isDataURL)

        let decode = try #require(image.href.decodedData)

        #expect(decode.mimeType == "image/png")

        let cgImage = CGImage.from(data: decode.data)

        #expect(cgImage != nil)
        #expect(cgImage?.width == 5)
        #expect(cgImage?.height == 5)
    }
}

#endif
