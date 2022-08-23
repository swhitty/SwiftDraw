//
//  CommandLine+Process.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 23/8/22.
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

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

public extension CommandLine {

    static func processImage(with config: Configuration) throws -> Data {
        guard FileManager.default.fileExists(atPath: config.input.path) else {
            throw Error.fileNotFound
        }

        switch config.format {
        case .swift:
            let code = try CGTextRenderer.render(fileURL: config.input,
                                                 size: config.size.renderSize,
                                                 options: config.options,
                                                 precision: config.precision ?? 2)
            return code.data(using: .utf8)!
        case .sfsymbol:
            let renderer = SFSymbolRenderer(options: config.options,
                                            insets: config.insets,
                                            precision: config.precision ?? 3)
            let svg = try renderer.render(fileURL: config.input)
            return svg.data(using: .utf8)!
        case .jpeg, .pdf, .png:
            #if canImport(CoreGraphics)
            guard let image = SwiftDraw.Image(fileURL: config.input, options: config.options),
                  let data = processImage(image, with: config) else {
                throw Error.invalid
            }
            return data
            #else
            throw Error.unsupported
            #endif

        }
    }

    static func processImage(_ image: SwiftDraw.Image, with config: Configuration) -> Data? {
        #if canImport(CoreGraphics)
        switch config.format {
        case .jpeg:
            return image.jpegData(size: config.size.cgValue, scale: config.scale.cgValue)
        case .pdf:
            return try? Image.pdfData(fileURL: config.input, size: config.size.cgValue)
        case .png:
            return image.pngData(size: config.size.cgValue, scale: config.scale.cgValue)
        case .swift, .sfsymbol:
            preconditionFailure()
        }
        #else
        return nil
        #endif
    }
}

#if canImport(CoreGraphics)
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
#endif

private extension CommandLine.Size {
    var renderSize: CGTextRenderer.Size? {
        switch self {
        case .default:
            return nil
        case .custom(width: let width, height: let height):
            return (width: width, height: height)
        }
    }
}
