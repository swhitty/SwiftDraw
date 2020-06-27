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
      print("Created: \(config.output.path)")
    } catch _ {
      print("Failure: \(config.output.path)")
    }
    
    return .ok
  }
  
  static func process(with config: Configuration) throws -> Data {
    guard
      let svg = SwiftDraw.Image(fileURL: config.input),
      let data = processImage(svg, with: config) else {
        throw Error.invalid
    }
    
    return data
  }
  
  static func processImage(_ image: SwiftDraw.Image, with config: Configuration) -> Data? {
    switch config.format {
    case .jpeg:
      return image.jpegData(size: config.size.cgValue, scale: config.scale.cgValue)
    case .pdf:
      return try? Image.pdfData(fileURL: config.input, size: config.size.cgValue)
    case .png:
      return image.pngData(size: config.size.cgValue, scale: config.scale.cgValue)
    }
  }
  
  static func printHelp() {
    print("")
    print("""
swiftdraw, version 0.7.2
copyright (c) 2020 Simon Whitty

usage: swiftdraw <file.svg> [--format png | pdf | jpeg] [--size wxh] [--scale 1x | 2x | 3x]

<file> svg file to be processed

--format  format to output image with png | pdf | jpeg
--size    size of output image e.g. 100x200
--scale   scale of output image with 1x | 2x | 3x
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

private extension CommandLine.Scale {
  
  var cgValue: CGFloat {
    switch self {
    case .default:
      return 1
    case .retina:
      return 2
    case .superRetina:
      return 3
    }
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
}
