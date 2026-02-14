//
//  TTF.swift
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

#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - TTF

/// A parsed TTF (TrueType Font) file
struct TTF {
    
    /// The TTF file header
    let header: Header
    
    /// The font tables contained in the file
    let tables: [Table]
    
    /// The raw font data
    let fontData: Data
    
    /// The PostScript name of the font, if present in the name table
    var postScriptName: String? {
        parsePostScriptName()
    }
    
    /// Creates a TTF by reading and parsing a file
    /// - Parameter url: The URL of the TTF file
    /// - Throws: Error if reading or parsing fails
    init(contentsOf url: URL) throws {
        try self.init(data: Data(contentsOf: url))
    }
    
    /// Creates a TTF by parsing file data
    /// - Parameter data: The TTF file data
    /// - Throws: TTFError if parsing fails
    init(data: Data) throws {
        let parsedHeader = try Self.parseHeader(from: data)
        let tableDirectory = try Self.parseTableDirectory(from: data, numTables: parsedHeader.numTables)
        
        self.header = Header(
            sfntVersion: parsedHeader.sfntVersion,
            numTables: parsedHeader.numTables,
            searchRange: parsedHeader.searchRange,
            entrySelector: parsedHeader.entrySelector,
            rangeShift: parsedHeader.rangeShift
        )
        
        self.tables = tableDirectory.map { entry in
            Table(
                tag: entry.tag,
                checksum: entry.checksum,
                offset: entry.offset,
                length: entry.length
            )
        }
        
        self.fontData = data
    }
    
    // MARK: - Header Parsing
    
    private static func parseHeader(from data: Data) throws -> TTFHeader {
        guard data.count >= 12 else {
            throw TTFError.invalidHeader
        }
        
        var offset = 0
        
        let sfntVersion = data.readUInt32(at: &offset)
        
        // Check for valid sfnt version
        // 0x00010000 = TrueType outlines
        // 0x4F54544F = "OTTO" = OpenType with CFF
        guard sfntVersion == 0x00010000 || sfntVersion == 0x4F54544F else {
            throw TTFError.invalidSignature
        }
        
        let numTables = data.readUInt16(at: &offset)
        let searchRange = data.readUInt16(at: &offset)
        let entrySelector = data.readUInt16(at: &offset)
        let rangeShift = data.readUInt16(at: &offset)
        
        return TTFHeader(
            sfntVersion: sfntVersion,
            numTables: numTables,
            searchRange: searchRange,
            entrySelector: entrySelector,
            rangeShift: rangeShift
        )
    }
    
    // MARK: - Table Directory Parsing
    
    private static func parseTableDirectory(from data: Data, numTables: UInt16) throws -> [TableDirectoryEntry] {
        var offset = 12 // After header
        var entries: [TableDirectoryEntry] = []
        
        for _ in 0..<numTables {
            guard offset + 16 <= data.count else {
                throw TTFError.invalidTableDirectory
            }
            
            // Read 4-byte tag as string
            let tagBytes = data.subdata(in: offset..<(offset + 4))
            let tag = String(bytes: tagBytes, encoding: .ascii) ?? "????"
            offset += 4
            
            let checksum = data.readUInt32(at: &offset)
            let tableOffset = data.readUInt32(at: &offset)
            let length = data.readUInt32(at: &offset)
            
            entries.append(TableDirectoryEntry(
                tag: tag,
                checksum: checksum,
                offset: tableOffset,
                length: length
            ))
        }
        
        return entries
    }
    
    // MARK: - Name Table Parsing
    
    private func parsePostScriptName() -> String? {
        // Find the name table
        guard let nameTable = tables.first(where: { $0.tag == "name" }) else {
            return nil
        }
        
        let nameTableOffset = Int(nameTable.offset)
        var offset = nameTableOffset
        
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

extension TTF {
    /// TTF file header information
    struct Header {
        /// The sfnt version (0x00010000 for TrueType, "OTTO" for OpenType/CFF)
        let sfntVersion: UInt32
        /// Number of tables in the font
        let numTables: UInt16
        /// Search range for binary search
        let searchRange: UInt16
        /// Entry selector for binary search
        let entrySelector: UInt16
        /// Range shift for binary search
        let rangeShift: UInt16
    }
    
    /// A table contained in the TTF file
    struct Table {
        /// Four-character table tag (e.g., "name", "glyf", "head")
        let tag: String
        /// Checksum for this table
        let checksum: UInt32
        /// Offset from beginning of file to this table
        let offset: UInt32
        /// Length of this table
        let length: UInt32
    }
}

// MARK: - Internal Data Types

private struct TTFHeader {
    let sfntVersion: UInt32
    let numTables: UInt16
    let searchRange: UInt16
    let entrySelector: UInt16
    let rangeShift: UInt16
}

private struct TableDirectoryEntry {
    let tag: String
    let checksum: UInt32
    let offset: UInt32
    let length: UInt32
}

// MARK: - Errors

enum TTFError: Error {
    case invalidHeader
    case invalidSignature
    case invalidTableDirectory
    #if canImport(CoreGraphics)
    case invalidFontData
    #endif
}

// MARK: - CGFont

#if canImport(CoreGraphics)
extension TTF {
    /// Creates a CGFont from the font data
    /// - Returns: A CGFont instance
    /// - Throws: TTFError.invalidFontData if the font cannot be created
    func makeCGFont() throws -> CGFont {
        guard let provider = CGDataProvider(data: fontData as CFData),
              let font = CGFont(provider) else {
            throw TTFError.invalidFontData
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
}
