//
//  WOFF.swift
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
import Foundation
import Compression

#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - WOFF

/// A parsed WOFF (Web Open Font Format 1.0) file
struct WOFF {
    
    /// The WOFF file header
    let header: Header
    
    /// The font tables contained in the file
    let tables: [Table]
    
    /// The decompressed font data
    let fontData: Data
    
    /// The PostScript name of the font, if present in the name table
    var postScriptName: String? {
        parsePostScriptName()
    }
    
    /// Creates a WOFF by reading and parsing a file
    /// - Parameter url: The URL of the WOFF file
    /// - Throws: Error if reading or parsing fails
    init(contentsOf url: URL) throws {
        try self.init(data: Data(contentsOf: url))
    }
    
    /// Creates a WOFF by parsing and decompressing file data
    /// - Parameter data: The WOFF file data
    /// - Throws: WOFFError if parsing or decompression fails
    init(data: Data) throws {
        let parsedHeader = try Self.parseHeader(from: data)
        let tableDirectory = try Self.parseTableDirectory(from: data, numTables: parsedHeader.numTables)
        let decompressedData = try Self.decompressTables(from: data, tables: tableDirectory, flavor: parsedHeader.flavor)
        
        self.header = Header(
            flavor: parsedHeader.flavor,
            numTables: parsedHeader.numTables,
            totalSfntSize: parsedHeader.totalSfntSize,
            majorVersion: parsedHeader.majorVersion,
            minorVersion: parsedHeader.minorVersion
        )
        
        self.tables = tableDirectory.map { entry in
            Table(
                tag: entry.tag,
                offset: entry.offset,
                compLength: entry.compLength,
                origLength: entry.origLength,
                origChecksum: entry.origChecksum
            )
        }
        
        self.fontData = decompressedData
    }
    
    // MARK: - Header Parsing
    
    private static func parseHeader(from data: Data) throws -> WOFFHeader {
        guard data.count >= 44 else {
            throw WOFFError.invalidHeader
        }
        
        var offset = 0
        
        // Read signature (should be 0x774F4646 = "wOFF")
        let signature = data.readUInt32(at: &offset)
        guard signature == 0x774F4646 else {
            throw WOFFError.invalidSignature
        }
        
        let flavor = data.readUInt32(at: &offset)
        let length = data.readUInt32(at: &offset)
        let numTables = data.readUInt16(at: &offset)
        let reserved = data.readUInt16(at: &offset)
        let totalSfntSize = data.readUInt32(at: &offset)
        let majorVersion = data.readUInt16(at: &offset)
        let minorVersion = data.readUInt16(at: &offset)
        let metaOffset = data.readUInt32(at: &offset)
        let metaLength = data.readUInt32(at: &offset)
        let metaOrigLength = data.readUInt32(at: &offset)
        let privOffset = data.readUInt32(at: &offset)
        let privLength = data.readUInt32(at: &offset)
        
        return WOFFHeader(
            signature: signature,
            flavor: flavor,
            length: length,
            numTables: numTables,
            reserved: reserved,
            totalSfntSize: totalSfntSize,
            majorVersion: majorVersion,
            minorVersion: minorVersion,
            metaOffset: metaOffset,
            metaLength: metaLength,
            metaOrigLength: metaOrigLength,
            privOffset: privOffset,
            privLength: privLength
        )
    }
    
    // MARK: - Table Directory Parsing
    
    private static func parseTableDirectory(from data: Data, numTables: UInt16) throws -> [TableDirectoryEntry] {
        var offset = 44 // After header
        var entries: [TableDirectoryEntry] = []
        
        for _ in 0..<numTables {
            guard offset + 20 <= data.count else {
                throw WOFFError.invalidTableDirectory
            }
            
            // Read 4-byte tag as string
            let tagBytes = data.subdata(in: offset..<(offset + 4))
            let tag = String(bytes: tagBytes, encoding: .ascii) ?? "????"
            offset += 4
            
            let tableOffset = data.readUInt32(at: &offset)
            let compLength = data.readUInt32(at: &offset)
            let origLength = data.readUInt32(at: &offset)
            let origChecksum = data.readUInt32(at: &offset)
            
            entries.append(TableDirectoryEntry(
                tag: tag,
                offset: tableOffset,
                compLength: compLength,
                origLength: origLength,
                origChecksum: origChecksum
            ))
        }
        
        return entries
    }
    
    // MARK: - Table Decompression
    
    private static func decompressTables(from data: Data, tables: [TableDirectoryEntry], flavor: UInt32) throws -> Data {
        // First, decompress all tables and collect their data
        var tableDataMap: [(entry: TableDirectoryEntry, data: Data)] = []
        
        for table in tables {
            let tableOffset = Int(table.offset)
            let compLength = Int(table.compLength)
            let origLength = Int(table.origLength)
            
            guard tableOffset + compLength <= data.count else {
                throw WOFFError.invalidCompressedData
            }
            
            let compressedTableData = data.subdata(in: tableOffset..<(tableOffset + compLength))
            
            let tableData: Data
            if compLength == origLength {
                // Table is not compressed
                tableData = compressedTableData
            } else {
                // Table is zlib compressed
                tableData = try decompressZlib(compressedTableData, decompressedSize: origLength)
            }
            
            tableDataMap.append((table, tableData))
        }
        
        // Build a proper sfnt file
        return buildSfntFile(flavor: flavor, tables: tableDataMap)
    }
    
    private static func buildSfntFile(flavor: UInt32, tables: [(entry: TableDirectoryEntry, data: Data)]) -> Data {
        let numTables = UInt16(tables.count)
        
        // Calculate searchRange, entrySelector, rangeShift
        var searchRange: UInt16 = 1
        var entrySelector: UInt16 = 0
        while searchRange * 2 <= numTables {
            searchRange *= 2
            entrySelector += 1
        }
        searchRange *= 16
        let rangeShift = numTables * 16 - searchRange
        
        var sfntData = Data()
        
        // Write sfnt header (12 bytes)
        sfntData.appendUInt32(flavor)
        sfntData.appendUInt16(numTables)
        sfntData.appendUInt16(searchRange)
        sfntData.appendUInt16(entrySelector)
        sfntData.appendUInt16(rangeShift)
        
        // Calculate where table data starts (after header + table directory)
        let headerSize = 12
        let tableDirectorySize = Int(numTables) * 16
        var currentOffset = UInt32(headerSize + tableDirectorySize)
        
        // Build table directory entries and collect offsets
        var tableOffsets: [(tag: String, checksum: UInt32, offset: UInt32, length: UInt32)] = []
        
        for (entry, tableData) in tables {
            let checksum = entry.origChecksum
            let length = UInt32(tableData.count)
            tableOffsets.append((entry.tag, checksum, currentOffset, length))
            
            // Advance offset, padding to 4-byte boundary
            let paddedLength = (length + 3) & ~3
            currentOffset += paddedLength
        }
        
        // Write table directory (sorted by tag for binary search)
        let sortedTables = tableOffsets.sorted { $0.tag < $1.tag }
        for table in sortedTables {
            // Write 4-byte tag
            if let tagData = table.tag.data(using: .ascii), tagData.count == 4 {
                sfntData.append(tagData)
            } else {
                sfntData.append(Data([0x3F, 0x3F, 0x3F, 0x3F])) // "????"
            }
            sfntData.appendUInt32(table.checksum)
            sfntData.appendUInt32(table.offset)
            sfntData.appendUInt32(table.length)
        }
        
        // Write table data in original order
        for (_, tableData) in tables {
            sfntData.append(tableData)
            
            // Pad to 4-byte boundary
            let padding = (4 - (tableData.count % 4)) % 4
            if padding > 0 {
                sfntData.append(Data(count: padding))
            }
        }
        
        return sfntData
    }
    
    private static func decompressZlib(_ data: Data, decompressedSize: Int) throws -> Data {
        // WOFF uses zlib-wrapped deflate. The Compression framework's COMPRESSION_ZLIB
        // expects raw deflate, so we need to strip the 2-byte zlib header and 4-byte
        // Adler-32 checksum trailer.
        guard data.count > 6 else {
            throw WOFFError.decompressionFailed
        }
        
        // Skip 2-byte zlib header (CMF + FLG) and 4-byte Adler-32 trailer
        let rawDeflate = data.dropFirst(2).dropLast(4)
        
        var decompressedData = Data(count: decompressedSize)
        var actualSize = 0
        
        rawDeflate.withUnsafeBytes { srcBuffer in
            decompressedData.withUnsafeMutableBytes { dstBuffer in
                guard let srcPtr = srcBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self),
                      let dstPtr = dstBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return
                }
                actualSize = compression_decode_buffer(
                    dstPtr, decompressedSize,
                    srcPtr, rawDeflate.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        
        guard actualSize > 0 else {
            throw WOFFError.decompressionFailed
        }
        
        decompressedData.count = actualSize
        return decompressedData
    }
    
    // MARK: - Name Table Parsing
    
    private func parsePostScriptName() -> String? {
        // fontData is now a proper sfnt file, so we need to read the table directory
        // to find the name table offset
        guard fontData.count >= 12 else { return nil }
        
        var offset = 4 // Skip sfnt version
        let numTables = fontData.readUInt16(at: &offset)
        offset = 12 // Skip rest of header (searchRange, entrySelector, rangeShift)
        
        // Find the name table in the table directory
        var nameTableOffset: Int?
        for _ in 0..<numTables {
            guard offset + 16 <= fontData.count else { return nil }
            
            let tagBytes = fontData.subdata(in: offset..<(offset + 4))
            let tag = String(bytes: tagBytes, encoding: .ascii) ?? "????"
            offset += 4
            
            offset += 4 // Skip checksum
            let tableOffset = fontData.readUInt32(at: &offset)
            offset += 4 // Skip length
            
            if tag == "name" {
                nameTableOffset = Int(tableOffset)
                break
            }
        }
        
        guard let nameTableOffset else { return nil }
        
        offset = nameTableOffset
        
        // Read the name table header
        guard offset + 6 <= fontData.count else { return nil }
        
        _ = fontData.readUInt16(at: &offset) // format
        let count = fontData.readUInt16(at: &offset)
        let storageOffset = fontData.readUInt16(at: &offset)
        
        // Look for PostScript name (nameID = 6)
        for _ in 0..<count {
            guard offset + 12 <= fontData.count else { return nil }
            
            let platformID = fontData.readUInt16(at: &offset)
            _ = fontData.readUInt16(at: &offset) // encodingID
            _ = fontData.readUInt16(at: &offset) // languageID
            let nameID = fontData.readUInt16(at: &offset)
            let length = fontData.readUInt16(at: &offset)
            let stringOffset = fontData.readUInt16(at: &offset)
            
            // PostScript name has nameID = 6
            if nameID == 6 {
                // storageOffset is relative to the start of the name table
                let actualOffset = nameTableOffset + Int(storageOffset) + Int(stringOffset)
                guard actualOffset + Int(length) <= fontData.count else { return nil }
                
                let nameData = fontData.subdata(in: actualOffset..<(actualOffset + Int(length)))
                
                // Decode based on platform
                if platformID == 1 { // Macintosh
                    return String(data: nameData, encoding: .macOSRoman)
                } else if platformID == 3 { // Windows
                    return String(data: nameData, encoding: .utf16BigEndian)
                }
            }
        }
        
        return nil
    }
}

// MARK: - Types

extension WOFF {
    /// WOFF file header information
    struct Header {
        /// The "sfnt version" of the original font
        let flavor: UInt32
        /// Number of tables in the font
        let numTables: UInt16
        /// Total size of decompressed font data
        let totalSfntSize: UInt32
        /// Major version of the WOFF file
        let majorVersion: UInt16
        /// Minor version of the WOFF file
        let minorVersion: UInt16
    }
    
    /// A table contained in the WOFF file
    struct Table {
        /// Four-character table tag (e.g., "name", "glyf", "head")
        let tag: String
        /// Offset to the compressed data in the WOFF file
        let offset: UInt32
        /// Compressed length of this table
        let compLength: UInt32
        /// Original uncompressed length of this table
        let origLength: UInt32
        /// Checksum of the uncompressed table
        let origChecksum: UInt32
    }
}

// MARK: - Internal Data Types

private struct WOFFHeader {
    let signature: UInt32
    let flavor: UInt32
    let length: UInt32
    let numTables: UInt16
    let reserved: UInt16
    let totalSfntSize: UInt32
    let majorVersion: UInt16
    let minorVersion: UInt16
    let metaOffset: UInt32
    let metaLength: UInt32
    let metaOrigLength: UInt32
    let privOffset: UInt32
    let privLength: UInt32
}

private struct TableDirectoryEntry {
    let tag: String
    let offset: UInt32
    let compLength: UInt32
    let origLength: UInt32
    let origChecksum: UInt32
}

// MARK: - Errors

enum WOFFError: Error {
    case invalidHeader
    case invalidSignature
    case invalidTableDirectory
    case invalidCompressedData
    case decompressionFailed
    #if canImport(CoreGraphics)
    case invalidFontData
    #endif
}

// MARK: - CGFont

#if canImport(CoreGraphics)
extension WOFF {
    /// Creates a CGFont from the decompressed font data
    /// - Returns: A CGFont instance
    /// - Throws: WOFFError.invalidFontData if the font cannot be created
    func makeCGFont() throws -> CGFont {
        guard let provider = CGDataProvider(data: fontData as CFData),
              let font = CGFont(provider) else {
            throw WOFFError.invalidFontData
        }
        return font
    }
}
#endif

// MARK: - Data Extensions

private extension Data {
    func readUInt16(at offset: inout Int) -> UInt16 {
        let value = UInt16(self[offset]) << 8 | UInt16(self[offset + 1])
        offset += 2
        return value
    }
    
    func readUInt32(at offset: inout Int) -> UInt32 {
        let value = UInt32(self[offset]) << 24 |
                    UInt32(self[offset + 1]) << 16 |
                    UInt32(self[offset + 2]) << 8 |
                    UInt32(self[offset + 3])
        offset += 4
        return value
    }
    
    mutating func appendUInt16(_ value: UInt16) {
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8(value & 0xFF))
    }
    
    mutating func appendUInt32(_ value: UInt32) {
        append(UInt8((value >> 24) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8(value & 0xFF))
    }
}
