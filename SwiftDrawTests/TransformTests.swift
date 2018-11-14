//
//  TransformTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright 2016 Simon Whitty
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

private typealias CharacterSet = SwiftDraw.CharacterSet
private typealias Scanner = SwiftDraw.SlowScanner

class TransformTests: XCTestCase {
    
    func testMatrix() {
        AssertMatrixEqual("matrix(0 1 2 3 4 5)", (0, 1, 2, 3, 4, 5))
        AssertMatrixEqual("matrix(0,1,2,3,4,5)", (0, 1, 2, 3, 4, 5))
        AssertMatrixEqual("matrix(1.1,1.2,1.3,1.4,1.5,1.6)", (1.1, 1.2, 1.3, 1.4, 1.5, 1.6))
    }
    
    func testTranslate() {
        AssertTranslateEqual("translate(5)", (5, 0))
        AssertTranslateEqual("translate(5, 6)", (5, 6))
        AssertTranslateEqual("translate(5  6)", (5, 6))
        AssertTranslateEqual("translate(1.3, 4.5)", (1.3, 4.5))
    }
    
    func testScale() {
        AssertScaleEqual("scale(5)", (5, 5))
        AssertScaleEqual("scale(5, 6)", (5, 6))
        AssertScaleEqual("scale(5  6)", (5, 6))
        AssertScaleEqual("scale(1.3, 4.5)", (1.3, 4.5))
    }
    
    func testRotate() {
        AssertRotateEqual("rotate(5)", 5)
        AssertRotatePointEqual("rotate(5, 6, 7)", (5, 6, 7))
        AssertRotatePointEqual("rotate(5  6  7)", (5, 6, 7))
        AssertRotatePointEqual("rotate(1.3, 4.5, 5.4)", (1.3, 4.5, 5.4))
    }
    
    func testSkewX() {
        AssertSkewXEqual("skewX(5)", 5)
        AssertSkewXEqual("skewX(6.7)", 6.7)
        AssertSkewXEqual("skewX(0)", 0)
    }
    
    func testSkewY() {
        AssertSkewYEqual("skewY(5)", 5)
        AssertSkewYEqual("skewY(6.7)", 6.7)
        AssertSkewYEqual("skewY(0)", 0)
    }
    
    func testTransform() {
        
        let expected = [DOM.Transform.scale(sx: 2, sy: 2),
                        DOM.Transform.translate(tx: 4, ty: 0),
                        DOM.Transform.scale(sx: 5, sy: 5)]
        
        AssertTransformEqual("scale(2) translate(4) scale(5, 5) ", expected)
    }
    
}

private func AssertTransformEqual(_ text: String, _ expected: [DOM.Transform], file: StaticString = #file, line: UInt = #line) {
    guard let parsed = try? XMLParser().parseTransform(text) else {
        XCTFail("Failed to parse transforms from \(text)", file: file, line: line)
        return
    }
    XCTAssertEqual(parsed, expected, file: file, line: line)
}

private func AssertMatrixEqual(_ text: String, _ expected: (DOM.Float, DOM.Float, DOM.Float, DOM.Float, DOM.Float, DOM.Float), file: StaticString = #file, line: UInt = #line) {
    
    var scanner = Scanner(text: text)
    guard let parsed = try? XMLParser().parseMatrix(&scanner) else {
        XCTFail("Failed to parse matrix from \(text)", file: file, line: line)
        return
    }
    
    let transform = DOM.Transform.matrix(a: expected.0, b: expected.1, c: expected.2, d: expected.3, e: expected.4, f: expected.5)
    XCTAssertEqual(parsed, transform, file: file, line: line)
}

private func AssertTranslateEqual(_ text: String, _ expected: (DOM.Float, DOM.Float), file: StaticString = #file, line: UInt = #line) {
    var scanner = Scanner(text: text)
    guard let parsed = try? XMLParser().parseTranslate(&scanner) else {
        XCTFail("Failed to parse translate from \(text)", file: file, line: line)
        return
    }
    
    let transform = DOM.Transform.translate(tx: expected.0, ty: expected.1)
    XCTAssertEqual(parsed, transform, file: file, line: line)
}

private func AssertScaleEqual(_ text: String, _ expected: (DOM.Float, DOM.Float), file: StaticString = #file, line: UInt = #line) {
    var scanner = Scanner(text: text)
    guard let parsed = try? XMLParser().parseScale(&scanner) else {
        XCTFail("Failed to parse scale from \(text)", file: file, line: line)
        return
    }
    
    let transform = DOM.Transform.scale(sx: expected.0, sy: expected.1)
    XCTAssertEqual(parsed, transform, file: file, line: line)
}

private func AssertRotateEqual(_ text: String, _ expected: DOM.Float, file: StaticString = #file, line: UInt = #line) {
    var scanner = Scanner(text: text)
    guard let parsed = try? XMLParser().parseRotate(&scanner) else {
        XCTFail("Failed to parse rotate from \(text)", file: file, line: line)
        return
    }
    
    let transform = DOM.Transform.rotate(angle: expected)
    XCTAssertEqual(parsed, transform, file: file, line: line)
}

private func AssertRotatePointEqual(_ text: String, _ expected: (DOM.Float, DOM.Float, DOM.Float), file: StaticString = #file, line: UInt = #line) {
    var scanner = Scanner(text: text)
    guard let parsed = try? XMLParser().parseRotate(&scanner) else {
        XCTFail("Failed to parse rotate from \(text)", file: file, line: line)
        return
    }
    
    let transform = DOM.Transform.rotatePoint(angle: expected.0, cx: expected.1, cy: expected.2)
    XCTAssertEqual(parsed, transform, file: file, line: line)
}

private func AssertSkewXEqual(_ text: String, _ expected: DOM.Float, file: StaticString = #file, line: UInt = #line) {
    var scanner = Scanner(text: text)
    guard let parsed = try? XMLParser().parseSkewX(&scanner) else {
        XCTFail("Failed to parse skewX from \(text)", file: file, line: line)
        return
    }
    
    XCTAssertEqual(parsed, .skewX(angle: expected), file: file, line: line)
}

private func AssertSkewYEqual(_ text: String, _ expected: DOM.Float, file: StaticString = #file, line: UInt = #line) {
    var scanner = Scanner(text: text)
    guard let parsed = try? XMLParser().parseSkewY(&scanner) else {
        XCTFail("Failed to parse skewY from \(text)", file: file, line: line)
        return
    }
    
    XCTAssertEqual(parsed, .skewY(angle: expected), file: file, line: line)
}
