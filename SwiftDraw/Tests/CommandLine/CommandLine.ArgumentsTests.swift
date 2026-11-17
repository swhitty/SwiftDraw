//
//  CommandLine.ArgumentsTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 7/12/18.
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

import Testing
@testable import SwiftDraw

struct CommandLineArgumentsTests {

    @Test(
        arguments: [
            (
                ["--format", "some", "--output", "more", "--scale", "magnify", "--size", "huge"],
                [.format: "some", .output: "more", .scale: "magnify", .size: "huge"]
            ),
            (
                ["--ultralightInsets", "a", "--blackInsets", "b", "--hideUnsupportedFilters", "--legacy"],
                [.ultralightInsets: "a", .blackInsets: "b", .hideUnsupportedFilters: nil, .legacy: nil]
            ),
            (
                ["--ultralight-insets", "a", "--black-insets", "b", "--hide-unsupported-filters", "--legacy"],
                [.ultralightInsets: "a", .blackInsets: "b", .hideUnsupportedFilters: nil, .legacy: nil]
            ),
            (
                ["--format", "png", "--quiet"],
                [.format: "png", .quiet: nil]
            ),
        ] as [([String], [CommandLine.Modifier: String?])]
    )
    func parsesModifiers(args: [String], expected: [CommandLine.Modifier: String?]) throws {
        #expect(try CommandLine.parseModifiers(from: args) == expected)
    }

    @Test(
        arguments: [
            // odd pairs
            ["--format"],
            ["--format", "png", "--output"],
            // duplicate modifiers
            ["--format", "png", "--format", "jpg"],
            ["--format", "png", "--output", "more", "--output", "evenmore"],
            // unknown modifiers
            ["--unknown", "png"],
            ["--format", "png", "--unknown", "more"],
            // missing prefix
            ["format", "png"],
            ["--format", "png", "output", "more"],
        ]
    )
    func invalidModifiersThrow(args: [String]) {
        #expect(throws: CommandLine.Error.invalid) {
            try CommandLine.parseModifiers(from: args)
        }
    }
}
