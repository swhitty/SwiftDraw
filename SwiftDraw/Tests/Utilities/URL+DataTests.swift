//
//  URL.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 28/2/17.
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
import SwiftDrawDOM
import Testing
@testable import SwiftDraw

struct URLTests {

    @Test
    func decodedData() {
        let url = URL(maybeData: "data:image/png;base64,f00d")
        #expect(url?.decodedData?.mimeType == "image/png")
        #expect(url?.decodedData?.data.base64EncodedString() == "f00d")
    }

    @Test(
        arguments: [
            "data:;base64,f00d",
            "data:image/png;bas,f00d",
            "data:image/png;base64",
            "data:image/png;base64,",
        ]
    )
    func malformedDataURLHasNoDecodedData(string: String) {
        #expect(URL(maybeData: string)?.decodedData == nil)
    }

    @Test(
        arguments: [
            ("data:image/png;base64,f00d", true),
            ("data:f00d", true),
            ("#identifier", false),
            ("data", false),
            ("www.google.com", false),
        ] as [(String, Bool)]
    )
    func isDataURL(string: String, expected: Bool) throws {
        #expect(try #require(URL(maybeData: string)).isDataURL == expected)
    }

    @Test
    func decodedDataIgnoresLineBreaks() {
        let url = URL(maybeData: "data:image/png;base64,8badf00d\n\t 8badf00d")
        #expect(url?.decodedData?.mimeType == "image/png")
        #expect(url?.decodedData?.data.base64EncodedString() == "8badf00d8badf00d")
    }
}
