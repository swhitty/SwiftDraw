//
//  CommandLine.FilterOptionsTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 15/11/26.
//  Copyright 2026 Simon Whitty
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

@testable import SwiftDraw
import Foundation
import Testing

struct CommandLineFilterOptionsTests {

    private func options(_ args: String...) throws -> SVG.Options {
        try CommandLine.parseConfiguration(
            from: ["swiftdraw", "file.svg", "--format", "png"] + args,
            baseDirectory: URL(fileURLWithPath: "/")
        ).options
    }

    @Test
    func disableFiltersFlag() throws {
        #expect(try options("--disable-filters").contains(.disableFilters))
        #expect(try !options().contains(.disableFilters))
    }

    @Test
    func disableFiltersWithHideUnsupportedFilters() throws {
        let options = try options("--hide-unsupported-filters", "--disable-filters")
        #expect(options.contains(.disableFilters))
        #expect(options.contains(.hideUnsupportedFilters))
    }

    @Test
    func disableFiltersTakesNoValue() {
        #expect(throws: (any Error).self) {
            try options("--disable-filters", "yes")
        }
    }
}
