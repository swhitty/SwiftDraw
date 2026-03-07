//
//  FontDataProvider.swift
//  swift-woff2
//
//  Created by Simon Whitty on 7/2/26.
//  Copyright 2026 Simon Whitty
//
//  Distributed under the permissive zlib license
//  Get the latest version from here:
//
//  https://github.com/swhitty/swift-woff2
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

#if canImport(CoreGraphics)
import Foundation
import CoreGraphics

/// A protocol for types that can provide font data and create CGFonts
protocol FontDataProvider {
    init(data: Data) throws
    init(contentsOf url: URL) throws
    func makeCGFont() throws -> CGFont
}

extension TTF: FontDataProvider {}
extension WOFF: FontDataProvider {}
extension WOFF2: FontDataProvider {}

enum FontDataProviderError: Error {
    case unsupportedFormat
    case insufficientData
}

/// Auto-detects font format from data and returns the appropriate provider
func makeFontDataProvider(data: Data) throws -> any FontDataProvider {
    guard data.count >= 4 else {
        throw FontDataProviderError.insufficientData
    }
    let signature = UInt32(data[0]) << 24 | UInt32(data[1]) << 16 | UInt32(data[2]) << 8 | UInt32(data[3])
    switch signature {
    case 0x774F4632: // wOF2
        return try WOFF2(data: data)
    case 0x774F4646: // wOFF
        return try WOFF(data: data)
    case 0x00010000, 0x4F54544F: // TrueType, OpenType (OTTO)
        return try TTF(data: data)
    default:
        throw FontDataProviderError.unsupportedFormat
    }
}
#endif
