//
//  PairedSequence.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 6/8/22.
//  Copyright 2022 Simon Whitty
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

struct PairedSequenceTests {

    @Test(
        arguments: [
            (["a", "b", "c", "d"], .nextSkippingLast, ["ab", "bc", "cd"]),
            (["a", "b", "c", "d"], .nextWrappingToFirst, ["ab", "bc", "cd", "da"]),
            (["a", "b"], .nextSkippingLast, ["ab"]),
            (["a", "b"], .nextWrappingToFirst, ["ab", "ba"]),
            (["a"], .nextSkippingLast, []),
            (["a"], .nextWrappingToFirst, []),
            ([], .nextSkippingLast, []),
            ([], .nextWrappingToFirst, []),
        ] as [([String], PairedSequence<[String]>.Options, [String])]
    )
    func pairsElements(elements: [String], options: PairedSequence<[String]>.Options, expected: [String]) {
        #expect(elements.paired(with: options).map { "\($0)\($1)" } == expected)
    }
}
