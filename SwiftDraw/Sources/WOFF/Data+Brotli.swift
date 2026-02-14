//
//  Data+Brotli.swift
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

#if canImport(Compression)
import Foundation
import Compression

extension Data {
    
    /// Decompresses Brotli-compressed data.
    /// - Parameter decompressedSize: The size of the decompressed data.
    /// - Returns: The decompressed data.
    /// - Throws: `BrotliError.decompressionFailed` if decompression fails.
    func decompressBrotli(decompressedSize: Int) throws(BrotliError) -> Data {
#if compiler(>=6.2)
        if #available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) {
            return try _decompressBrotliSpan(decompressedSize: decompressedSize)
        } else {
            return try _decompressBrotliLegacy(decompressedSize: decompressedSize)
        }
#else
        return try _decompressBrotliLegacy(decompressedSize: decompressedSize)
#endif
    }

#if compiler(>=6.2)
    @available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *)
    private func _decompressBrotliSpan(decompressedSize: Int) throws(BrotliError) -> Data {
        let srcSpan = self.bytes
        var decompressedData = Data(count: decompressedSize)
        var dstSpan = decompressedData.mutableBytes
        var actualSize = 0
        
        srcSpan.withUnsafeBytes { srcBuffer in
            dstSpan.withUnsafeMutableBytes { dstBuffer in
                guard let srcPtr = srcBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self),
                      let dstPtr = dstBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return
                }
                actualSize = compression_decode_buffer(
                    dstPtr,
                    decompressedSize,
                    srcPtr,
                    count,
                    nil,
                    COMPRESSION_BROTLI
                )
            }
        }
        
        guard actualSize > 0 else {
            throw .decompressionFailed
        }
        
        decompressedData.count = actualSize
        return decompressedData
    }
#endif

    private func _decompressBrotliLegacy(decompressedSize: Int) throws(BrotliError) -> Data {
        var decompressedData = Data(count: decompressedSize)
        var actualSize = 0
        var thrownError: BrotliError?
        
        self.withUnsafeBytes { srcBuffer in
            guard let srcPtr = srcBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                thrownError = .decompressionFailed
                return
            }
            
            actualSize = decompressedData.withUnsafeMutableBytes { dstBuffer -> Int in
                guard let dstPtr = dstBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return 0
                }
                return compression_decode_buffer(
                    dstPtr,
                    decompressedSize,
                    srcPtr,
                    count,
                    nil,
                    COMPRESSION_BROTLI
                )
            }
        }
        
        if let error = thrownError {
            throw error
        }
        
        guard actualSize > 0 else {
            throw .decompressionFailed
        }
        
        decompressedData.count = actualSize
        return decompressedData
    }
}

enum BrotliError: Error {
    case decompressionFailed
}
#endif
