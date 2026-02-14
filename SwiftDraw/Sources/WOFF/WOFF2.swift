//
//  WOFF2.swift
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

// MARK: - WOFF2

/// A parsed WOFF2 (Web Open Font Format 2.0) file
struct WOFF2 {
    
    /// The WOFF2 file header
    let header: Header
    
    /// The font tables contained in the file
    let tables: [Table]
    
    /// The decompressed font data
    let fontData: Data
    
    /// The PostScript name of the font, if present in the name table
    var postScriptName: String? {
        parsePostScriptName()
    }
    
    /// Creates a WOFF2 by reading and parsing a file
    /// - Parameter url: The URL of the WOFF2 file
    /// - Throws: Error if reading or parsing fails
    init(contentsOf url: URL) throws {
        try self.init(data: Data(contentsOf: url))
    }
    
    /// Creates a WOFF2 by parsing and decompressing file data
    /// - Parameter data: The WOFF2 file data
    /// - Throws: WOFF2Error if parsing or decompression fails
    init(data: Data) throws {
        let parsedHeader = try Self.parseHeader(from: data)
        let tableDirectory = try Self.parseTableDirectory(from: data, header: parsedHeader)
        let decompressedData = try Self.decompressBrotli(data: data, header: parsedHeader)
        
        self.header = Header(
            flavor: parsedHeader.flavor,
            numTables: parsedHeader.numTables,
            totalSfntSize: parsedHeader.totalSfntSize,
            majorVersion: parsedHeader.majorVersion,
            minorVersion: parsedHeader.minorVersion
        )
        
        self.tables = tableDirectory.map { entry in
            Table(
                tag: entry.tag.stringValue,
                origLength: entry.origLength,
                transformLength: entry.transformLength
            )
        }
        
        // Build sfnt file from decompressed data, applying transforms
        self.fontData = try Self.buildSfntFile(
            flavor: parsedHeader.flavor,
            tables: self.tables,
            tableDirectory: tableDirectory,
            decompressedData: decompressedData
        )
    }
    
    // MARK: - Header Parsing
    
    private static func parseHeader(from data: Data) throws -> WOFF2Header {
        guard data.count >= 48 else {
            throw WOFF2Error.invalidHeader
        }
        
        var offset = 0
        
        // Read signature (should be 0x774F4632 = "wOF2")
        let signature = data.readUInt32(at: &offset)
        guard signature == 0x774F4632 else {
            throw WOFF2Error.invalidSignature
        }
        
        let flavor = data.readUInt32(at: &offset)
        let length = data.readUInt32(at: &offset)
        let numTables = data.readUInt16(at: &offset)
        let reserved = data.readUInt16(at: &offset)
        let totalSfntSize = data.readUInt32(at: &offset)
        let totalCompressedSize = data.readUInt32(at: &offset)
        let majorVersion = data.readUInt16(at: &offset)
        let minorVersion = data.readUInt16(at: &offset)
        let metaOffset = data.readUInt32(at: &offset)
        let metaLength = data.readUInt32(at: &offset)
        let metaOrigLength = data.readUInt32(at: &offset)
        let privOffset = data.readUInt32(at: &offset)
        let privLength = data.readUInt32(at: &offset)
        
        return WOFF2Header(
            signature: signature,
            flavor: flavor,
            length: length,
            numTables: numTables,
            reserved: reserved,
            totalSfntSize: totalSfntSize,
            totalCompressedSize: totalCompressedSize,
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
    
    private static func parseTableDirectory(from data: Data, header: WOFF2Header) throws -> [TableDirectoryEntry] {
        var offset = 48 // After header
        var entries: [TableDirectoryEntry] = []
        
        for _ in 0..<header.numTables {
            guard offset + 1 <= data.count else {
                throw WOFF2Error.invalidTableDirectory
            }
            
            let flags = data[offset]
            offset += 1
            
            // Parse tag
            let tag: TableTag
            let tagBits = (flags & 0x3F)
            
            if tagBits < 63 {
                // Known table tag from the spec
                tag = TableTag(rawValue: tagBits) ?? .unknown
            } else {
                // Custom tag (4 bytes)
                guard offset + 4 <= data.count else {
                    throw WOFF2Error.invalidTableDirectory
                }
                tag = .custom(data.readUInt32(at: &offset))
            }
            
            // Parse origLength
            let origLength = try data.readUIntBase128(at: &offset)
            
            // Parse transformLength based on WOFF2 spec rules:
            // - For glyf (10) and loca (11): transformLength present when transform version is 0 or 1
            // - For other tables: transformLength present when transform version is non-zero
            var transformLength: UInt32?
            let transformVersion = (flags >> 6) & 0x03
            
            if tagBits == 10 || tagBits == 11 { // glyf or loca
                if transformVersion == 0 || transformVersion == 1 {
                    transformLength = try data.readUIntBase128(at: &offset)
                }
            } else {
                if transformVersion != 0 {
                    transformLength = try data.readUIntBase128(at: &offset)
                }
            }
            
            entries.append(TableDirectoryEntry(
                tag: tag,
                flags: flags,
                origLength: origLength,
                transformLength: transformLength
            ))
        }
        
        return entries
    }
    
    // MARK: - Brotli Decompression

    private static func decompressBrotli(data: Data, header: WOFF2Header) throws -> Data {
        // Find where compressed data starts
        var compressedDataOffset = 48 // After header

        // Skip table directory to find compressed data
        var tempOffset = compressedDataOffset
        for _ in 0..<header.numTables {
            guard tempOffset < data.count else {
                throw WOFF2Error.invalidFormat
            }

            let flags = data[tempOffset]
            tempOffset += 1

            let tagBits = (flags & 0x3F)
            if tagBits == 63 {
                tempOffset += 4 // Custom tag
            }

            // Skip origLength (UIntBase128)
            _ = try data.readUIntBase128(at: &tempOffset)

            // Skip transformLength based on WOFF2 spec rules:
            // - For glyf (10) and loca (11): transformLength present when transform version is 0 or 1
            // - For other tables: transformLength present when transform version is non-zero
            let transformVersion = (flags >> 6) & 0x03
            
            if tagBits == 10 || tagBits == 11 { // glyf or loca
                if transformVersion == 0 || transformVersion == 1 {
                    _ = try data.readUIntBase128(at: &tempOffset)
                }
            } else {
                if transformVersion != 0 {
                    _ = try data.readUIntBase128(at: &tempOffset)
                }
            }
        }

        compressedDataOffset = tempOffset
        let compressedLength = Int(header.totalCompressedSize)

        guard compressedDataOffset + compressedLength <= data.count else {
            throw WOFF2Error.invalidCompressedData
        }

        let compressedData = data.subdata(in: compressedDataOffset..<(compressedDataOffset + compressedLength))

        do {
            return try compressedData.decompressBrotli(decompressedSize: Int(header.totalSfntSize))
        } catch {
            throw WOFF2Error.decompressionFailed
        }
    }
    
    // MARK: - Build sfnt File
    
    private static func buildSfntFile(
        flavor: UInt32,
        tables: [Table],
        tableDirectory: [TableDirectoryEntry],
        decompressedData: Data
    ) throws -> Data {
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
        
        // Calculate where table data starts (after header + table directory)
        let headerSize = 12
        let tableDirectorySize = Int(numTables) * 16
        var currentOffset = UInt32(headerSize + tableDirectorySize)
        
        // Extract table data from decompressed stream, applying transforms
        var decompressedOffset = 0
        var tableDataList: [(tag: String, checksum: UInt32, offset: UInt32, length: UInt32, data: Data)] = []
        
        // Find glyf and loca indices for transform handling
        var glyfIndex: Int?
        var locaIndex: Int?
        for (index, entry) in tableDirectory.enumerated() {
            if entry.tag == .glyf { glyfIndex = index }
            if entry.tag == .loca { locaIndex = index }
        }
        
        // Check if glyf is transformed (transformVersion == 0 for glyf means transformed)
        var glyfTransformed = false
        if let gi = glyfIndex {
            let flags = tableDirectory[gi].flags
            let transformVersion = (flags >> 6) & 0x03
            // For glyf, transformVersion 0 means transformed, 3 means not transformed
            glyfTransformed = (transformVersion == 0)
        }
        
        var reconstructedGlyf: Data?
        var reconstructedLoca: Data?
        
        // If glyf is transformed, reconstruct it
        if glyfTransformed, let gi = glyfIndex {
            // Find glyf offset in decompressed data
            var glyfOffset = 0
            for i in 0..<gi {
                glyfOffset += Int(tables[i].decompressedSize)
            }
            let glyfSize = Int(tables[gi].decompressedSize)
            let glyfData = decompressedData.subdata(in: glyfOffset..<(glyfOffset + glyfSize))
            
            let result = try GlyfTransform.reconstruct(from: glyfData)
            reconstructedGlyf = result.glyf
            reconstructedLoca = result.loca
        }
        
        // Process each table
        for (index, table) in tables.enumerated() {
            let tableSize = Int(table.decompressedSize)
            var tableData: Data
            
            if index == glyfIndex, let glyf = reconstructedGlyf {
                // Use reconstructed glyf
                tableData = glyf
            } else if index == locaIndex, let loca = reconstructedLoca {
                // Use reconstructed loca
                tableData = loca
            } else {
                // Use original decompressed data
                tableData = decompressedData.subdata(in: decompressedOffset..<(decompressedOffset + tableSize))
            }
            
            let checksum = calculateChecksum(tableData)
            tableDataList.append((table.tag, checksum, currentOffset, UInt32(tableData.count), tableData))
            
            // Advance offset, padding to 4-byte boundary
            let paddedLength = (UInt32(tableData.count) + 3) & ~3
            currentOffset += paddedLength
            decompressedOffset += tableSize
        }
        
        // Build sfnt data
        var sfntData = Data()
        
        // Write sfnt header (12 bytes)
        sfntData.appendUInt32(flavor)
        sfntData.appendUInt16(numTables)
        sfntData.appendUInt16(searchRange)
        sfntData.appendUInt16(entrySelector)
        sfntData.appendUInt16(rangeShift)
        
        // Sort tables by tag for binary search (sfnt requirement)
        let sortedTables = tableDataList.sorted { $0.tag < $1.tag }
        
        // Recalculate offsets for sorted order
        var sortedWithOffsets: [(tag: String, checksum: UInt32, offset: UInt32, length: UInt32, data: Data)] = []
        var dataOffset = UInt32(headerSize + tableDirectorySize)
        for table in sortedTables {
            sortedWithOffsets.append((table.tag, table.checksum, dataOffset, table.length, table.data))
            let paddedLength = (table.length + 3) & ~3
            dataOffset += paddedLength
        }
        
        // Write table directory
        for table in sortedWithOffsets {
            // Write 4-byte tag
            if let tagData = table.tag.data(using: .ascii), tagData.count == 4 {
                sfntData.append(tagData)
            } else {
                // Pad short tags with spaces
                var paddedTag = table.tag
                while paddedTag.count < 4 {
                    paddedTag += " "
                }
                if let tagData = paddedTag.data(using: .ascii) {
                    sfntData.append(tagData.prefix(4))
                } else {
                    sfntData.append(Data([0x3F, 0x3F, 0x3F, 0x3F])) // "????"
                }
            }
            sfntData.appendUInt32(table.checksum)
            sfntData.appendUInt32(table.offset)
            sfntData.appendUInt32(table.length)
        }
        
        // Write table data in sorted order (matching directory offsets)
        for table in sortedWithOffsets {
            sfntData.append(table.data)
            
            // Pad to 4-byte boundary
            let padding = (4 - (Int(table.length) % 4)) % 4
            if padding > 0 {
                sfntData.append(Data(count: padding))
            }
        }
        
        return sfntData
    }
    
    private static func calculateChecksum(_ data: Data) -> UInt32 {
        var sum: UInt32 = 0
        var i = 0
        while i + 4 <= data.count {
            let value = UInt32(data[i]) << 24 |
                        UInt32(data[i + 1]) << 16 |
                        UInt32(data[i + 2]) << 8 |
                        UInt32(data[i + 3])
            sum = sum &+ value
            i += 4
        }
        // Handle remaining bytes
        if i < data.count {
            var value: UInt32 = 0
            var shift = 24
            while i < data.count {
                value |= UInt32(data[i]) << shift
                shift -= 8
                i += 1
            }
            sum = sum &+ value
        }
        return sum
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

extension WOFF2 {
    /// WOFF2 file header information
    struct Header {
        /// The "sfnt version" of the original font
        let flavor: UInt32
        /// Number of tables in the font
        let numTables: UInt16
        /// Total size of decompressed font data
        let totalSfntSize: UInt32
        /// Major version of the WOFF2 file
        let majorVersion: UInt16
        /// Minor version of the WOFF2 file
        let minorVersion: UInt16
    }
    
    /// A table contained in the WOFF2 file
    struct Table {
        /// Four-character table tag (e.g., "name", "glyf", "head")
        let tag: String
        /// Original uncompressed length of the table
        let origLength: UInt32
        /// Transform length if transformation was applied
        let transformLength: UInt32?
        
        /// The actual size of this table in the decompressed stream
        var decompressedSize: UInt32 {
            transformLength ?? origLength
        }
    }
}

// MARK: - Internal Data Types

private struct WOFF2Header {
    let signature: UInt32
    let flavor: UInt32
    let length: UInt32
    let numTables: UInt16
    let reserved: UInt16
    let totalSfntSize: UInt32
    let totalCompressedSize: UInt32
    let majorVersion: UInt16
    let minorVersion: UInt16
    let metaOffset: UInt32
    let metaLength: UInt32
    let metaOrigLength: UInt32
    let privOffset: UInt32
    let privLength: UInt32
}

private struct TableDirectoryEntry {
    let tag: TableTag
    let flags: UInt8
    let origLength: UInt32
    let transformLength: UInt32?
    
    /// The actual size of this table in the decompressed stream
    var decompressedSize: UInt32 {
        transformLength ?? origLength
    }
}

private enum TableTag: Equatable {
    case cmap
    case head
    case hhea
    case hmtx
    case maxp
    case name
    case os2
    case post
    case cvt
    case fpgm
    case glyf
    case loca
    case prep
    case cff
    case vorg
    case ebdt
    case eblc
    case gasp
    case hdmx
    case kern
    case ltsh
    case pclt
    case vdmx
    case vhea
    case vmtx
    case base
    case gdef
    case gpos
    case gsub
    case ebsc
    case jstf
    case math
    case cbdt
    case cblc
    case colr
    case cpal
    case svg
    case sbix
    case acnt
    case avar
    case bdat
    case bloc
    case bsln
    case cvar
    case fdsc
    case feat
    case fmtx
    case fvar
    case gvar
    case hsty
    case just
    case lcar
    case mort
    case morx
    case opbd
    case prop
    case trak
    case zapf
    case silf
    case glat
    case gloc
    case feat2
    case sill
    case unknown
    case custom(UInt32)
    
    init?(rawValue: UInt8) {
        switch rawValue {
        case 0: self = .cmap
        case 1: self = .head
        case 2: self = .hhea
        case 3: self = .hmtx
        case 4: self = .maxp
        case 5: self = .name
        case 6: self = .os2
        case 7: self = .post
        case 8: self = .cvt
        case 9: self = .fpgm
        case 10: self = .glyf
        case 11: self = .loca
        case 12: self = .prep
        case 13: self = .cff
        case 14: self = .vorg
        case 15: self = .ebdt
        case 16: self = .eblc
        case 17: self = .gasp
        case 18: self = .hdmx
        case 19: self = .kern
        case 20: self = .ltsh
        case 21: self = .pclt
        case 22: self = .vdmx
        case 23: self = .vhea
        case 24: self = .vmtx
        case 25: self = .base
        case 26: self = .gdef
        case 27: self = .gpos
        case 28: self = .gsub
        case 29: self = .ebsc
        case 30: self = .jstf
        case 31: self = .math
        case 32: self = .cbdt
        case 33: self = .cblc
        case 34: self = .colr
        case 35: self = .cpal
        case 36: self = .svg
        case 37: self = .sbix
        case 38: self = .acnt
        case 39: self = .avar
        case 40: self = .bdat
        case 41: self = .bloc
        case 42: self = .bsln
        case 43: self = .cvar
        case 44: self = .fdsc
        case 45: self = .feat
        case 46: self = .fmtx
        case 47: self = .fvar
        case 48: self = .gvar
        case 49: self = .hsty
        case 50: self = .just
        case 51: self = .lcar
        case 52: self = .mort
        case 53: self = .morx
        case 54: self = .opbd
        case 55: self = .prop
        case 56: self = .trak
        case 57: self = .zapf
        case 58: self = .silf
        case 59: self = .glat
        case 60: self = .gloc
        case 61: self = .feat2
        case 62: self = .sill
        default: return nil
        }
    }
    
    var stringValue: String {
        switch self {
        case .cmap: return "cmap"
        case .head: return "head"
        case .hhea: return "hhea"
        case .hmtx: return "hmtx"
        case .maxp: return "maxp"
        case .name: return "name"
        case .os2: return "OS/2"
        case .post: return "post"
        case .cvt: return "cvt "
        case .fpgm: return "fpgm"
        case .glyf: return "glyf"
        case .loca: return "loca"
        case .prep: return "prep"
        case .cff: return "CFF "
        case .vorg: return "VORG"
        case .ebdt: return "EBDT"
        case .eblc: return "EBLC"
        case .gasp: return "gasp"
        case .hdmx: return "hdmx"
        case .kern: return "kern"
        case .ltsh: return "LTSH"
        case .pclt: return "PCLT"
        case .vdmx: return "VDMX"
        case .vhea: return "vhea"
        case .vmtx: return "vmtx"
        case .base: return "BASE"
        case .gdef: return "GDEF"
        case .gpos: return "GPOS"
        case .gsub: return "GSUB"
        case .ebsc: return "EBSC"
        case .jstf: return "JSTF"
        case .math: return "MATH"
        case .cbdt: return "CBDT"
        case .cblc: return "CBLC"
        case .colr: return "COLR"
        case .cpal: return "CPAL"
        case .svg: return "SVG "
        case .sbix: return "sbix"
        case .acnt: return "acnt"
        case .avar: return "avar"
        case .bdat: return "bdat"
        case .bloc: return "bloc"
        case .bsln: return "bsln"
        case .cvar: return "cvar"
        case .fdsc: return "fdsc"
        case .feat: return "feat"
        case .fmtx: return "fmtx"
        case .fvar: return "fvar"
        case .gvar: return "gvar"
        case .hsty: return "hsty"
        case .just: return "just"
        case .lcar: return "lcar"
        case .mort: return "mort"
        case .morx: return "morx"
        case .opbd: return "opbd"
        case .prop: return "prop"
        case .trak: return "trak"
        case .zapf: return "Zapf"
        case .silf: return "Silf"
        case .glat: return "Glat"
        case .gloc: return "Gloc"
        case .feat2: return "Feat"
        case .sill: return "Sill"
        case .unknown: return "????"
        case .custom(let value):
            // Convert UInt32 to 4-character string
            var chars: [UInt8] = []
            chars.append(UInt8((value >> 24) & 0xFF))
            chars.append(UInt8((value >> 16) & 0xFF))
            chars.append(UInt8((value >> 8) & 0xFF))
            chars.append(UInt8(value & 0xFF))
            return String(bytes: chars, encoding: .ascii) ?? "????"
        }
    }
}

// MARK: - Errors

enum WOFF2Error: Error {
    case invalidHeader
    case invalidSignature
    case invalidTableDirectory
    case invalidFormat
    case invalidCompressedData
    case decompressionFailed
    #if canImport(CoreGraphics)
    case invalidFontData
    #endif
}

// MARK: - CGFont

#if canImport(CoreGraphics)
import CoreGraphics

extension WOFF2 {
    /// Creates a CGFont from the reconstructed font data
    /// - Returns: A CGFont instance
    /// - Throws: WOFF2Error.invalidFontData if the font cannot be created
    func makeCGFont() throws -> CGFont {
        guard let provider = CGDataProvider(data: fontData as CFData),
              let font = CGFont(provider) else {
            throw WOFF2Error.invalidFontData
        }
        return font
    }
}
#endif

// MARK: - Data Extensions

private extension Data {
    mutating func readUInt8(at offset: inout Int) -> UInt8 {
        let value = self[offset]
        offset += 1
        return value
    }
    
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
    
    func readUIntBase128(at offset: inout Int) throws -> UInt32 {
        var result: UInt32 = 0
        
        for i in 0..<5 {
            guard offset < self.count else {
                throw WOFF2Error.invalidFormat
            }
            
            let byte = self[offset]
            offset += 1
            
            // If last iteration and high bit is set, overflow
            if i == 4 && (byte & 0x80) != 0 {
                throw WOFF2Error.invalidFormat
            }
            
            result = (result << 7) | UInt32(byte & 0x7F)
            
            if (byte & 0x80) == 0 {
                break
            }
        }
        
        return result
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

