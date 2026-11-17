//
//  LayerTree.ImageTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 3/6/17.
//  Copyright 2020 WhileLoop Pty Ltd. All rights reserved.
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
@testable import SwiftDraw
import Testing

struct LayerTreeImageTests {

    let someData = Data(base64Encoded: "8badf00d")!
    let moreData = Data(base64Encoded: "f00d")!

    @Test
    func initFromMimeType() {
        let i1 = LayerTree.Image(mimeType: "image/png", data: someData)
        let i2 = LayerTree.Image(mimeType: "image/jpg", data: moreData)
        let i3 = LayerTree.Image(mimeType: "image/jpeg", data: someData)

        #expect(i1 == .png(data: someData))
        #expect(i2 == .jpeg(data: moreData))
        #expect(i3 == .jpeg(data: someData))

        #expect(LayerTree.Image(mimeType: "image/jpg", data: Data()) == nil)
        #expect(LayerTree.Image(mimeType: "image", data: someData) == nil)
    }

    @Test
    func imageEquality() {
        let i1 = LayerTree.Image(mimeType: "image/jpeg", data: someData)
        let i2 = LayerTree.Image(mimeType: "image/jpg", data: someData)
        let i3 = LayerTree.Image(mimeType: "image/png", data: someData)

        #expect(i1 == .jpeg(data: someData))
        #expect(i1 == i1)
        #expect(i1 == i2)

        #expect(i3 == .png(data: someData))
        #expect(i3 == i3)

        #expect(i1 != i3)
    }
}
