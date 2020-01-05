//
//  StackTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 15/6/17.
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

final class StackTests: XCTestCase {
  
  func testInit() {
    let stack = Stack<Int>(root: 10)
    
    XCTAssertEqual(stack.root, 10)
    XCTAssertEqual(stack.top, 10)
    XCTAssertTrue(stack.storage.isEmpty)
  }
  
  func testPush() {
    var stack = Stack<Int>(root: 10)
    
    XCTAssertTrue(stack.storage.isEmpty)
    
    stack.push(20)
    XCTAssertEqual(stack.top, 20)
    XCTAssertFalse(stack.storage.isEmpty)
    
    stack.push(30)
    XCTAssertEqual(stack.top, 30)
    stack.push(40)
    XCTAssertEqual(stack.top, 40)
    stack.push(50)
    XCTAssertEqual(stack.top, 50)
    XCTAssertEqual(stack.storage, [20, 30, 40, 50])
  }
  
  func testPop() {
    var stack = Stack<Int>(root: 10)
    
    //cannot pop off root
    XCTAssertFalse(stack.pop())
    
    stack.push(20)
    stack.push(30)
    stack.push(40)
    stack.push(50)
    XCTAssertEqual(stack.top, 50)
    XCTAssertTrue(stack.pop())
    XCTAssertEqual(stack.top, 40)
    XCTAssertTrue(stack.pop())
    XCTAssertEqual(stack.top, 30)
    XCTAssertTrue(stack.pop())
    XCTAssertEqual(stack.top, 20)
    XCTAssertTrue(stack.pop())
    XCTAssertEqual(stack.top, 10)
    
    //cannot pop off root
    XCTAssertFalse(stack.pop())
  }
  
  func testMutation() {
    
    var stack = Stack<Int>(root: 10)
    
    XCTAssertEqual(stack.top, 10)
    stack.top = 50
    XCTAssertEqual(stack.top, 50)
    XCTAssertEqual(stack.root, 50)
    XCTAssertTrue(stack.storage.isEmpty)
    
    stack.push(100)
    stack.top = 200
    
    XCTAssertEqual(stack.top, 200)
    XCTAssertEqual(stack.root, 50)
    XCTAssertEqual(stack.storage, [200])
    
    stack.push(500)
    stack.top = 600
    XCTAssertEqual(stack.top, 600)
    XCTAssertEqual(stack.root, 50)
    XCTAssertEqual(stack.storage, [200, 600])
    
    stack.pop()
    stack.top = 33
    XCTAssertEqual(stack.top, 33)
    XCTAssertEqual(stack.root, 50)
    XCTAssertEqual(stack.storage, [33])
    
    stack.pop()
    stack.top = 1
    XCTAssertEqual(stack.top, 1)
    XCTAssertEqual(stack.root, 1)
    XCTAssertTrue(stack.storage.isEmpty)
    
  }
  
  
}
