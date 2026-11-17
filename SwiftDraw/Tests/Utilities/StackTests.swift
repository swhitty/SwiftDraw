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

import Testing
@testable import SwiftDraw

struct StackTests {

    @Test
    func initStartsWithRootOnly() {
        let stack = Stack<Int>(root: 10)

        #expect(stack.root == 10)
        #expect(stack.top == 10)
        #expect(stack.storage.isEmpty)
    }

    @Test
    func pushChangesTop() {
        var stack = Stack<Int>(root: 10)

        #expect(stack.storage.isEmpty)

        stack.push(20)
        #expect(stack.top == 20)
        #expect(!stack.storage.isEmpty)

        stack.push(30)
        #expect(stack.top == 30)
        stack.push(40)
        #expect(stack.top == 40)
        stack.push(50)
        #expect(stack.top == 50)
        #expect(stack.storage == [20, 30, 40, 50])
    }

    @Test
    func popStopsAtRoot() {
        var stack = Stack<Int>(root: 10)
        var popped: Bool

        // cannot pop off root
        popped = stack.pop()
        #expect(!popped)

        stack.push(20)
        stack.push(30)
        stack.push(40)
        stack.push(50)
        #expect(stack.top == 50)
        popped = stack.pop()
        #expect(popped)
        #expect(stack.top == 40)
        popped = stack.pop()
        #expect(popped)
        #expect(stack.top == 30)
        popped = stack.pop()
        #expect(popped)
        #expect(stack.top == 20)
        popped = stack.pop()
        #expect(popped)
        #expect(stack.top == 10)

        // cannot pop off root
        popped = stack.pop()
        #expect(!popped)
    }

    @Test
    func settingTopMutatesTopmostElement() {
        var stack = Stack<Int>(root: 10)

        #expect(stack.top == 10)
        stack.top = 50
        #expect(stack.top == 50)
        #expect(stack.root == 50)
        #expect(stack.storage.isEmpty)

        stack.push(100)
        stack.top = 200

        #expect(stack.top == 200)
        #expect(stack.root == 50)
        #expect(stack.storage == [200])

        stack.push(500)
        stack.top = 600
        #expect(stack.top == 600)
        #expect(stack.root == 50)
        #expect(stack.storage == [200, 600])

        stack.pop()
        stack.top = 33
        #expect(stack.top == 33)
        #expect(stack.root == 50)
        #expect(stack.storage == [33])

        stack.pop()
        stack.top = 1
        #expect(stack.top == 1)
        #expect(stack.root == 1)
        #expect(stack.storage.isEmpty)
    }
}
