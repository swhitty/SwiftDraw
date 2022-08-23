//
//  CommandLine.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 23/11/18.
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
import SwiftDraw

extension SwiftDraw.CommandLine {
    
    static func run(with args: [String] = Swift.CommandLine.arguments,
                    baseDirectory: URL = .currentDirectory) -> ExitCode {
        
        guard let config = try? parseConfiguration(from: args, baseDirectory: baseDirectory) else {
            print("Invalid Syntax.", to: &.standardError)
            printHelp()
            return .error
        }

        let data: Data
        do {
            data = try process(with: config)
        } catch Error.fileNotFound {
            print("Failure: File does not exist.", to: &.standardError)
            return .error
        } catch {
            print("Failure:", error.localizedDescription, to: &.standardError)
            printHelp()
            return .error
        }

        do {
            try data.write(to: config.output)
            print("Created: \(config.output.path)")
        } catch _ {
            print("Failure: \(config.output.path)", to: &.standardError)
        }
        
        return .ok
    }
    
    static func process(with config: Configuration) throws -> Data {
        guard let data = try processImage(config: config) else {
            throw Error.invalid
        }
        
        return data
    }
    
    static func processImage(config: Configuration) throws -> Data? {
        guard FileManager.default.fileExists(atPath: config.input.path) else {
            throw Error.fileNotFound
        }

        switch config.format {
        case .swift:
            let code = try CGTextRenderer.render(fileURL: config.input,
                                                 size: config.size.renderSize,
                                                 options: config.options,
                                                 precision: config.precision ?? 2)
            return code.data(using: .utf8)
        case .sfsymbol:
            let renderer = SFSymbolRenderer(options: config.options, precision: config.precision ?? 3)
            let svg = try renderer.render(fileURL: config.input)
            return svg.data(using: .utf8)
        case .jpeg, .pdf, .png:
            guard let image = SwiftDraw.Image(fileURL: config.input, options: config.options),
                  let data = processImage(image, with: config) else {
                throw Error.invalid
            }
            return data
        }
    }
    
    static func printHelp() {
        print("")
        print("""
swiftdraw, version 0.12.0
copyright (c) 2022 Simon Whitty

usage: swiftdraw <file.svg> [--format png | pdf | jpeg | swift] [--size wxh] [--scale 1x | 2x | 3x]

<file> svg file to be processed

Options:
 --format     format to output image with png | pdf | jpeg | swift | sfsymbol
 --size       size of output image e.g. 100x200
 --scale      scale of output image with 1x | 2x | 3x
 --precision  maximum number of decimal places

 --hideUnsupportedFilters   hides any elements with unsupported filters. Disabled by default.

""")
    }
}

extension SwiftDraw.CommandLine {
    
    // Represents the exit codes to the command line. See `man sysexits` for more information.
    enum ExitCode: Int32 {
        case ok = 0 // EX_OK
        case error = 70 // EX_SOFTWARE
    }
}

private extension URL {
    static var currentDirectory: URL {
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }
}

private extension CommandLine.Size {
    
    var cgValue: CGSize? {
        switch self {
        case .default:
            return nil
        case .custom(width: let width, height: let height):
            return CGSize(width: CGFloat(width), height: CGFloat(height))
        }
    }
    
    var renderSize: CGTextRenderer.Size? {
        switch self {
        case .default:
            return nil
        case .custom(width: let width, height: let height):
            return (width: width, height: height)
        }
    }
}
