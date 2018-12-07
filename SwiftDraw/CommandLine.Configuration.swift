//
//  CommandLine.Configuration.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 7/12/18.
//  Copyright 2018 Simon Whitty
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

extension CommandLine {

    public struct Configuration {
        public var input: URL
        public var output: URL
        public var format: Format
    }

    public enum Format: String {
        case jpeg
        case pdf
        case png
    }

    public static func parseConfiguration(from args: [String], baseDirectory: URL) throws -> Configuration {
        guard args.count > 2 else {
            throw Error.invalid
        }

        let source = try CommandLine.parseFileURL(file: args[1], within: baseDirectory)
        let modifiers = try CommandLine.parseModifiers(from: Array(args.dropFirst(2)))
        guard
            let formatString = modifiers[.format],
            let format = Format(rawValue: formatString) else {
                throw Error.invalid
        }

        let result = source.newURL(for: format)
        return Configuration(input: source, output: result, format: format)
    }

    static func parseFileURL(file: String, within directory: URL) throws -> URL {
        guard #available(macOS 10.11, *) else {
            throw Error.invalid
        }

        return URL(fileURLWithPath: file, relativeTo: directory).standardizedFileURL
    }
}


extension URL {

    var lastPathComponentName: String {
        let filename = lastPathComponent
        let extensionOffset = pathExtension.isEmpty ? 0 : -pathExtension.count - 1
        let index = filename.index(filename.endIndex, offsetBy: extensionOffset)
        return String(filename[..<index])
    }

    func newURL(for format: CommandLine.Format) -> URL {
        let newFilename = "\(lastPathComponentName).\(format.pathExtension)"
        return deletingLastPathComponent().appendingPathComponent(newFilename).standardizedFileURL
    }
}

private extension CommandLine.Format {

    var pathExtension: String {
        switch self {
        case .jpeg:
            return "jpg"
        case .pdf:
            return "pdf"
        case .png:
            return "png"
        }
    }
}

