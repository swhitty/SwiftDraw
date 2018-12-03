//
//  CommandLine.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 23/11/18.
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
import SwiftDraw

struct CommandLine {

    var directory: URL

    init(directory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) {
        self.directory = directory
    }

    func run(with args: [String] = Swift.CommandLine.arguments) -> ExitCode {
        guard let config = try? parseConfiguration(from: args) else {
            print("Invalid Syntax.")
            printHelp()
            return .error
        }

        guard
            let data = try? process(with: config) else {
            print("Failure")
            printHelp()
            return .error
        }

        do {
            try data.write(to: config.output)
            print("Created: \(data.count) \(config.output)")
        } catch _ {
            print("Failure: \(data.count) \(config.output)")
        }

        return .ok
    }

    func printHelp() {
        print("")
        print("""
swiftdraw, version 0.2
copyright (c) 2018 Simon Whitty

usage: swiftdraw <file.svg> [--format png | pdf | jpeg] [--output filename] [...]

<file> svg file to be processed

--format    format to output image with. png | pdf | jpeg
--output    filename to output image to.  Optional.
""")
    }

    func process(with config: Configuration) throws -> Data {
        guard
            let svg = SwiftDraw.Image(fileURL: config.inputSVG),
            let data = CommandLine.processImage(svg, with: config) else {
            throw Error.invalid
        }

        return data
    }

    static func processImage(_ image: SwiftDraw.Image, with config: Configuration) -> Data? {
        switch config.format {
        case .jpeg:
            return image.jpegData()
        case .pdf:
            return image.pdfData()
        case .png:
            return image.pngData()
        }
    }

    static func parseURL(file: String, directory: URL) throws -> URL {
        guard #available(macOS 10.11, *) else {
            throw Error.invalid
        }

        return URL(fileURLWithPath: file, relativeTo: directory).standardizedFileURL
    }

    func parseConfiguration(from args: [String]) throws -> Configuration {
        guard
            args.count >= 3,
            let format = Format(rawValue: args[2]) else {
            throw Error.invalid
        }

        let source = try CommandLine.parseURL(file: args[1], directory: directory)
        let result = source.newURL(for: format)

        return Configuration(inputSVG: source, output: result, format: format)
    }
}

extension CommandLine {

    struct Configuration {
        var inputSVG: URL
        var output: URL
        var format: Format
    }

    enum Format: String {
        case jpeg
        case pdf
        case png
    }

    enum Error: Swift.Error {
        case invalid
    }

    // Represents the exit codes to the command line. See `man sysexits` for more information.
    enum ExitCode: Int32 {
        case ok = 0 // EX_OK
        case error = 70 // EX_SOFTWARE
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
