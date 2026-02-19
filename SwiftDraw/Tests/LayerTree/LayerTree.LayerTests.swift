//
//  LayerTree.LayerTests.swift
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

import XCTest
@testable import SwiftDraw
import SwiftDrawDOM

final class LayerTreeLayerTests: XCTestCase {

  private typealias Layer = LayerTree.Layer
  private typealias Contents = LayerTree.Layer.Contents
  private typealias TextAttributes = LayerTree.TextAttributes
  private typealias Point = LayerTree.Point

  func testLayersWithSimpleContentsAreAppendedWithoutLayer() {
    let parent = LayerTree.Layer()
    let simple = LayerTree.Layer()
    simple.appendContents(.mockImage)

    parent.appendContents(.layer(simple))
    XCTAssertEqual(parent.contents, [.mockImage])
  }

  func testLayersWithComplexContentsAreAppendedWithoutLayer() {
    let parent = LayerTree.Layer()
    let complex = LayerTree.Layer()
    complex.appendContents(.mockImage)
    complex.opacity = 0.5

    parent.appendContents(.layer(complex))
    XCTAssertEqual(parent.contents, [.layer(complex)])
  }

  func testContentsTextEquality() {
    let c1 = Contents.text("Charlie", .zero, .normal)
    let c2 = Contents.text("Ida", .zero, .normal)
    let c3 = Contents.text("Charlie", Point(10, 20), .normal)

    var att = TextAttributes.normal
    att.color = .srgb(r: 1.0, g: 0, b: 0, a: 1.0)
    let c4 = Contents.text("Charlie", .zero, att)

    XCTAssertEqual(c1, c1)
    XCTAssertEqual(c1, .text("Charlie", .zero, .normal))

    XCTAssertEqual(c2, c2)
    XCTAssertEqual(c2, .text("Ida", .zero, .normal))
    
    XCTAssertEqual(c3, c3)
    XCTAssertEqual(c3, .text("Charlie", Point(10, 20), .normal))

    XCTAssertEqual(c4, c4)
    XCTAssertEqual(c4, .text("Charlie", .zero, att))

    XCTAssertNotEqual(c1, c2)
    XCTAssertNotEqual(c1, c3)
    XCTAssertNotEqual(c1, c4)
    XCTAssertNotEqual(c2, c3)
    XCTAssertNotEqual(c2, c4)
    XCTAssertNotEqual(c3, c4)
  }
}

private extension LayerTree.Layer.Contents {

  static var mockImage: LayerTree.Layer.Contents {
    let image = LayerTree.Image(mimeType: "image/png", data: Data(base64Encoded: "f00d")!)!
    return .image(image)
  }
}

extension LayerTree.TextAttributes {
    static var normal: Self {
        LayerTree.TextAttributes(
            color: .black,
            font: [.name("Times")],
            size: 12.0,
            anchor: .start,
            baseline: .auto
        )
    }
}
