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
            data = try processImage(with: config)
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
    
    static func printHelp() {
        print("")
        print("""
swiftdraw, version 0.18.3
copyright (c) 2025 Simon Whitty

usage: swiftdraw <file.svg> [--format png | pdf | jpeg | swift | sfsymbol] [--size wxh] [--scale 1x | 2x | 3x]

<file> svg file to be processed

Options:
 --format      format to output image: png | pdf | jpeg | swift | sfsymbol
 --size        size of output image: 100x200
 --scale       scale of output image: 1x | 2x | 3x
 --insets      crop inset of output image: top,left,bottom,right
 --precision   maximum number of decimal places
 --output      optional path of output file

 --hideUnsupportedFilters   hide elements with unsupported filters.

Available keys for --format swift:
 --api                api of generated code:  appkit | uikit

Available keys for --format sfsymbol:
 --insets             alignment of regular variant: top,left,bottom,right | auto
 --ultralight         svg file of ultralight variant
 --ultralightInsets   alignment of ultralight variant: top,left,bottom,right | auto
 --black              svg file of black variant
 --blackInsets        alignment of black variant: top,left,bottom,right | auto


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
