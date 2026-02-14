//
//  GlyfTransform.swift
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

// MARK: - GlyfTransform

/// Handles WOFF2 glyf/loca table transform reversal
/// Reference: https://www.w3.org/TR/WOFF2/ Section 5
struct GlyfTransform {

    /// Header from transformed glyf table (36 bytes)
    struct Header {
        let reserved: UInt16
        let optionFlags: UInt16
        let numGlyphs: UInt16
        let indexFormat: UInt16  // 0 = short loca (UInt16), 1 = long loca (UInt32)
        let nContourStreamSize: UInt32
        let nPointsStreamSize: UInt32
        let flagStreamSize: UInt32
        let glyphStreamSize: UInt32
        let compositeStreamSize: UInt32
        let bboxStreamSize: UInt32
        let instructionStreamSize: UInt32

        /// Whether the overlap simple bitmap is present
        var hasOverlapBitmap: Bool {
            (optionFlags & 0x0001) != 0
        }
    }

    /// Result of glyf/loca reconstruction
    struct ReconstructedTables {
        let glyf: Data
        let loca: Data
    }

    /// Parses the 36-byte transformed glyf header
    static func parseHeader(from data: Data) throws -> Header {
        guard data.count >= 36 else {
            throw GlyfTransformError.invalidHeader
        }

        var offset = 0
        let reserved = data.readUInt16BE(at: &offset)

        guard reserved == 0 else {
            throw GlyfTransformError.invalidHeader
        }

        let optionFlags = data.readUInt16BE(at: &offset)
        let numGlyphs = data.readUInt16BE(at: &offset)
        let indexFormat = data.readUInt16BE(at: &offset)
        let nContourStreamSize = data.readUInt32BE(at: &offset)
        let nPointsStreamSize = data.readUInt32BE(at: &offset)
        let flagStreamSize = data.readUInt32BE(at: &offset)
        let glyphStreamSize = data.readUInt32BE(at: &offset)
        let compositeStreamSize = data.readUInt32BE(at: &offset)
        let bboxStreamSize = data.readUInt32BE(at: &offset)
        let instructionStreamSize = data.readUInt32BE(at: &offset)

        return Header(
            reserved: reserved,
            optionFlags: optionFlags,
            numGlyphs: numGlyphs,
            indexFormat: indexFormat,
            nContourStreamSize: nContourStreamSize,
            nPointsStreamSize: nPointsStreamSize,
            flagStreamSize: flagStreamSize,
            glyphStreamSize: glyphStreamSize,
            compositeStreamSize: compositeStreamSize,
            bboxStreamSize: bboxStreamSize,
            instructionStreamSize: instructionStreamSize
        )
    }

    /// Calculates stream offsets from header
    static func streamOffsets(from header: Header) -> StreamOffsets {
        let headerSize = 36
        var offset = headerSize

        let nContour = offset
        offset += Int(header.nContourStreamSize)

        let nPoints = offset
        offset += Int(header.nPointsStreamSize)

        let flags = offset
        offset += Int(header.flagStreamSize)

        let glyph = offset
        offset += Int(header.glyphStreamSize)

        let composite = offset
        offset += Int(header.compositeStreamSize)

        let bbox = offset
        offset += Int(header.bboxStreamSize)

        let instruction = offset

        return StreamOffsets(
            nContour: nContour,
            nPoints: nPoints,
            flags: flags,
            glyph: glyph,
            composite: composite,
            bbox: bbox,
            instruction: instruction
        )
    }

    /// Stream offsets within the transformed glyf data
    struct StreamOffsets {
        let nContour: Int
        let nPoints: Int
        let flags: Int
        let glyph: Int
        let composite: Int
        let bbox: Int
        let instruction: Int
    }

    /// Reconstructs standard glyf and loca tables from transformed data
    static func reconstruct(from transformedGlyf: Data) throws -> ReconstructedTables {
        let header = try parseHeader(from: transformedGlyf)
        let offsets = streamOffsets(from: header)

        // Create stream readers
        var nContourReader = StreamReader(data: transformedGlyf, offset: offsets.nContour)
        var nPointsReader = StreamReader(data: transformedGlyf, offset: offsets.nPoints)
        var flagReader = StreamReader(data: transformedGlyf, offset: offsets.flags)
        var glyphReader = StreamReader(data: transformedGlyf, offset: offsets.glyph)
        var compositeReader = StreamReader(data: transformedGlyf, offset: offsets.composite)
        var bboxReader = StreamReader(data: transformedGlyf, offset: offsets.bbox)
        var instructionReader = StreamReader(data: transformedGlyf, offset: offsets.instruction)

        // Parse bbox bitmap - must be 4-byte aligned per WOFF2 spec
        let bboxBitmapSize = ((Int(header.numGlyphs) + 31) >> 5) << 2
        let bboxBitmap = transformedGlyf.subdata(in: offsets.bbox..<(offsets.bbox + bboxBitmapSize))
        bboxReader.offset += bboxBitmapSize

        // Build glyf table
        var glyfData = Data()
        var locaOffsets: [UInt32] = []

        for glyphIndex in 0..<Int(header.numGlyphs) {
            locaOffsets.append(UInt32(glyfData.count))

            // Read nContour (Int16) - positive = simple, 0 = empty, -1 = composite
            let nContour = nContourReader.readInt16BE()

            if nContour == 0 {
                // Empty glyph - no data
                continue
            } else if nContour > 0 {
                // Simple glyph
                let glyphData = try reconstructSimpleGlyph(
                    nContours: Int(nContour),
                    glyphIndex: glyphIndex,
                    bboxBitmap: bboxBitmap,
                    nPointsReader: &nPointsReader,
                    flagReader: &flagReader,
                    glyphReader: &glyphReader,
                    bboxReader: &bboxReader,
                    instructionReader: &instructionReader
                )
                glyfData.append(glyphData)
            } else {
                // Composite glyph (nContour == -1)
                let glyphData = try reconstructCompositeGlyph(
                    glyphIndex: glyphIndex,
                    bboxBitmap: bboxBitmap,
                    compositeReader: &compositeReader,
                    glyphReader: &glyphReader,
                    bboxReader: &bboxReader,
                    instructionReader: &instructionReader
                )
                glyfData.append(glyphData)
            }

            // Pad to 4-byte boundary (per Google's reference implementation)
            while glyfData.count % 4 != 0 {
                glyfData.append(0)
            }
        }

        // Final loca entry
        locaOffsets.append(UInt32(glyfData.count))

        // Build loca table
        let locaData = buildLocaTable(offsets: locaOffsets, indexFormat: header.indexFormat)

        return ReconstructedTables(glyf: glyfData, loca: locaData)
    }

    // MARK: - Simple Glyph Reconstruction

    private static func reconstructSimpleGlyph(
        nContours: Int,
        glyphIndex: Int,
        bboxBitmap: Data,
        nPointsReader: inout StreamReader,
        flagReader: inout StreamReader,
        glyphReader: inout StreamReader,
        bboxReader: inout StreamReader,
        instructionReader: inout StreamReader
    ) throws -> Data {
        // Read points per contour and build endPtsOfContours
        var endPtsOfContours: [UInt16] = []
        var totalPoints = 0

        for _ in 0..<nContours {
            let nPoints = try read255UInt16(from: &nPointsReader)
            totalPoints += Int(nPoints)
            endPtsOfContours.append(UInt16(totalPoints - 1))
        }

        // Decode coordinate triplets
        var points: [(x: Int16, y: Int16, onCurve: Bool)] = []
        var x: Int = 0
        var y: Int = 0

        for _ in 0..<totalPoints {
            let (dx, dy, onCurve) = try decodeTriplet(flagReader: &flagReader, glyphReader: &glyphReader)
            x += dx
            y += dy
            points.append((Int16(clamping: x), Int16(clamping: y), onCurve))
        }

        // Read instruction length and instructions
        let instructionLength = try read255UInt16(from: &glyphReader)
        let instructions = instructionReader.readBytes(Int(instructionLength))

        // Get bounding box
        let bbox: (xMin: Int16, yMin: Int16, xMax: Int16, yMax: Int16)
        if hasBboxBit(bitmap: bboxBitmap, glyphIndex: glyphIndex) {
            // Read explicit bbox
            bbox = (
                bboxReader.readInt16BE(),
                bboxReader.readInt16BE(),
                bboxReader.readInt16BE(),
                bboxReader.readInt16BE()
            )
        } else {
            // Compute bbox from points
            bbox = computeBbox(from: points)
        }

        // Build TrueType simple glyph
        return buildSimpleGlyph(
            nContours: nContours,
            bbox: bbox,
            endPtsOfContours: endPtsOfContours,
            instructions: instructions,
            points: points
        )
    }

    // MARK: - Composite Glyph Reconstruction

    private static func reconstructCompositeGlyph(
        glyphIndex: Int,
        bboxBitmap: Data,
        compositeReader: inout StreamReader,
        glyphReader: inout StreamReader,
        bboxReader: inout StreamReader,
        instructionReader: inout StreamReader
    ) throws -> Data {
        var glyphData = Data()

        // numberOfContours = -1 for composite
        glyphData.appendInt16BE(-1)

        // Read bbox (always explicit for composites)
        let xMin = bboxReader.readInt16BE()
        let yMin = bboxReader.readInt16BE()
        let xMax = bboxReader.readInt16BE()
        let yMax = bboxReader.readInt16BE()

        glyphData.appendInt16BE(xMin)
        glyphData.appendInt16BE(yMin)
        glyphData.appendInt16BE(xMax)
        glyphData.appendInt16BE(yMax)

        // Read components
        var hasInstructions = false
        var moreComponents = true

        while moreComponents {
            let flags = compositeReader.readUInt16BE()
            let glyphIdx = compositeReader.readUInt16BE()

            glyphData.appendUInt16BE(flags)
            glyphData.appendUInt16BE(glyphIdx)

            // Read arguments
            if (flags & CompositeFlags.arg1And2AreWords) != 0 {
                glyphData.appendInt16BE(compositeReader.readInt16BE())
                glyphData.appendInt16BE(compositeReader.readInt16BE())
            } else {
                glyphData.append(compositeReader.readUInt8())
                glyphData.append(compositeReader.readUInt8())
            }

            // Read transform
            if (flags & CompositeFlags.weHaveAScale) != 0 {
                glyphData.appendInt16BE(compositeReader.readInt16BE())
            } else if (flags & CompositeFlags.weHaveAnXAndYScale) != 0 {
                glyphData.appendInt16BE(compositeReader.readInt16BE())
                glyphData.appendInt16BE(compositeReader.readInt16BE())
            } else if (flags & CompositeFlags.weHaveATwoByTwo) != 0 {
                glyphData.appendInt16BE(compositeReader.readInt16BE())
                glyphData.appendInt16BE(compositeReader.readInt16BE())
                glyphData.appendInt16BE(compositeReader.readInt16BE())
                glyphData.appendInt16BE(compositeReader.readInt16BE())
            }

            if (flags & CompositeFlags.weHaveInstructions) != 0 {
                hasInstructions = true
            }

            moreComponents = (flags & CompositeFlags.moreComponents) != 0
        }

        // Read instructions if present
        // Note: instruction length is read from glyphReader, not compositeReader!
        if hasInstructions {
            let instructionLength = try read255UInt16(from: &glyphReader)
            let instructions = instructionReader.readBytes(Int(instructionLength))
            glyphData.appendUInt16BE(instructionLength)
            glyphData.append(contentsOf: instructions)
        }

        return glyphData
    }

    // MARK: - Triplet Decoding

    /// Decodes a coordinate triplet from the flag and glyph streams
    /// Returns (dx, dy, onCurve)
    private static func decodeTriplet(
        flagReader: inout StreamReader,
        glyphReader: inout StreamReader
    ) throws -> (dx: Int, dy: Int, onCurve: Bool) {
        let flag = flagReader.readUInt8()
        let onCurve = (flag & 0x80) == 0  // Bit 7 clear = on curve
        let flagValue = Int(flag & 0x7F)

        // Triplet encoding - based on Google's TripletDecode
        let (dx, dy) = try decodeTripletCoordinates(flag: flagValue, glyphReader: &glyphReader)

        return (dx, dy, onCurve)
    }

    /// Applies sign based on flag bit - matches Google's WithSign function
    private static func withSign(_ flag: Int, _ baseval: Int) -> Int {
        return (flag & 1) != 0 ? baseval : -baseval
    }

    /// Decodes coordinate values based on flag index (0-127)
    /// This matches Google's TripletDecode implementation exactly
    private static func decodeTripletCoordinates(
        flag: Int,
        glyphReader: inout StreamReader
    ) throws -> (dx: Int, dy: Int) {
        let dx: Int
        let dy: Int

        if flag < 10 {
            // dx = 0, dy computed with sign
            let byte = Int(glyphReader.readUInt8())
            dx = 0
            dy = withSign(flag, ((flag & 14) << 7) + byte)
        } else if flag < 20 {
            // dx computed with sign, dy = 0
            let byte = Int(glyphReader.readUInt8())
            dx = withSign(flag, (((flag - 10) & 14) << 7) + byte)
            dy = 0
        } else if flag < 84 {
            // Both dx, dy from packed nibbles (1 byte)
            let b0 = flag - 20
            let b1 = Int(glyphReader.readUInt8())
            dx = withSign(flag, 1 + (b0 & 0x30) + (b1 >> 4))
            dy = withSign(flag >> 1, 1 + ((b0 & 0x0c) << 2) + (b1 & 0x0f))
        } else if flag < 120 {
            // dx, dy each from separate bytes (2 bytes)
            let b0 = flag - 84
            let byte0 = Int(glyphReader.readUInt8())
            let byte1 = Int(glyphReader.readUInt8())
            dx = withSign(flag, 1 + ((b0 / 12) << 8) + byte0)
            dy = withSign(flag >> 1, 1 + (((b0 % 12) >> 2) << 8) + byte1)
        } else if flag < 124 {
            // 12-bit coordinates (3 bytes)
            let byte0 = Int(glyphReader.readUInt8())
            let b2 = Int(glyphReader.readUInt8())
            let byte2 = Int(glyphReader.readUInt8())
            dx = withSign(flag, (byte0 << 4) + (b2 >> 4))
            dy = withSign(flag >> 1, ((b2 & 0x0f) << 8) + byte2)
        } else {
            // 16-bit coordinates (4 bytes)
            let byte0 = Int(glyphReader.readUInt8())
            let byte1 = Int(glyphReader.readUInt8())
            let byte2 = Int(glyphReader.readUInt8())
            let byte3 = Int(glyphReader.readUInt8())
            dx = withSign(flag, (byte0 << 8) + byte1)
            dy = withSign(flag >> 1, (byte2 << 8) + byte3)
        }

        return (dx, dy)
    }

    // MARK: - 255UInt16 Decoding

    /// Reads a 255UInt16 variable-length integer
    static func read255UInt16(from reader: inout StreamReader) throws -> UInt16 {
        let byte0 = reader.readUInt8()

        if byte0 < 253 {
            return UInt16(byte0)
        } else if byte0 == 253 {
            let b1 = UInt16(reader.readUInt8())
            let b2 = UInt16(reader.readUInt8())
            return (b1 << 8) | b2
        } else if byte0 == 254 {
            let b1 = UInt16(reader.readUInt8())
            return 506 + b1
        } else { // byte0 == 255
            let b1 = UInt16(reader.readUInt8())
            return 253 + b1
        }
    }

    // MARK: - Helper Functions

    private static func hasBboxBit(bitmap: Data, glyphIndex: Int) -> Bool {
        let byteIndex = glyphIndex / 8
        let bitIndex = 7 - (glyphIndex % 8)
        guard byteIndex < bitmap.count else { return false }
        return (bitmap[byteIndex] & (1 << bitIndex)) != 0
    }

    private static func computeBbox(from points: [(x: Int16, y: Int16, onCurve: Bool)]) -> (xMin: Int16, yMin: Int16, xMax: Int16, yMax: Int16) {
        guard !points.isEmpty else {
            return (0, 0, 0, 0)
        }

        var xMin = points[0].x
        var yMin = points[0].y
        var xMax = points[0].x
        var yMax = points[0].y

        for point in points {
            xMin = min(xMin, point.x)
            yMin = min(yMin, point.y)
            xMax = max(xMax, point.x)
            yMax = max(yMax, point.y)
        }

        return (xMin, yMin, xMax, yMax)
    }

    private static func buildSimpleGlyph(
        nContours: Int,
        bbox: (xMin: Int16, yMin: Int16, xMax: Int16, yMax: Int16),
        endPtsOfContours: [UInt16],
        instructions: [UInt8],
        points: [(x: Int16, y: Int16, onCurve: Bool)]
    ) -> Data {
        var data = Data()

        // Header
        data.appendInt16BE(Int16(nContours))
        data.appendInt16BE(bbox.xMin)
        data.appendInt16BE(bbox.yMin)
        data.appendInt16BE(bbox.xMax)
        data.appendInt16BE(bbox.yMax)

        // End points of contours
        for endPt in endPtsOfContours {
            data.appendUInt16BE(endPt)
        }

        // Instructions
        data.appendUInt16BE(UInt16(instructions.count))
        data.append(contentsOf: instructions)

        // Encode flags and coordinates
        let (flags, xCoords, yCoords) = encodeCoordinates(points: points)
        data.append(contentsOf: flags)
        data.append(contentsOf: xCoords)
        data.append(contentsOf: yCoords)

        return data
    }

    private static func encodeCoordinates(points: [(x: Int16, y: Int16, onCurve: Bool)]) -> (flags: [UInt8], xCoords: Data, yCoords: Data) {
        var flags: [UInt8] = []
        var xCoords = Data()
        var yCoords = Data()

        var prevX: Int = 0
        var prevY: Int = 0

        for point in points {
            let dx = Int(point.x) - prevX
            let dy = Int(point.y) - prevY

            var flag: UInt8 = point.onCurve ? 0x01 : 0x00

            // Encode X
            if dx == 0 {
                flag |= 0x10  // X is same
            } else if dx > -256 && dx < 256 {
                flag |= 0x02  // X is short
                if dx > 0 {
                    flag |= 0x10  // X is positive
                    xCoords.append(UInt8(dx))
                } else {
                    xCoords.append(UInt8(-dx))
                }
            } else {
                xCoords.appendInt16BE(Int16(clamping: dx))
            }

            // Encode Y
            if dy == 0 {
                flag |= 0x20  // Y is same
            } else if dy > -256 && dy < 256 {
                flag |= 0x04  // Y is short
                if dy > 0 {
                    flag |= 0x20  // Y is positive
                    yCoords.append(UInt8(dy))
                } else {
                    yCoords.append(UInt8(-dy))
                }
            } else {
                yCoords.appendInt16BE(Int16(clamping: dy))
            }

            flags.append(flag)
            prevX = Int(point.x)
            prevY = Int(point.y)
        }

        return (flags, xCoords, yCoords)
    }

    private static func buildLocaTable(offsets: [UInt32], indexFormat: UInt16) -> Data {
        var data = Data()

        if indexFormat == 0 {
            // Short format: UInt16 offsets divided by 2
            for offset in offsets {
                data.appendUInt16BE(UInt16(offset / 2))
            }
        } else {
            // Long format: UInt32 offsets
            for offset in offsets {
                data.appendUInt32BE(offset)
            }
        }

        return data
    }
}

// MARK: - Composite Glyph Flags

private struct CompositeFlags {
    static let arg1And2AreWords: UInt16     = 0x0001
    static let argsAreXYValues: UInt16      = 0x0002
    static let roundXYToGrid: UInt16        = 0x0004
    static let weHaveAScale: UInt16         = 0x0008
    static let moreComponents: UInt16       = 0x0020
    static let weHaveAnXAndYScale: UInt16   = 0x0040
    static let weHaveATwoByTwo: UInt16      = 0x0080
    static let weHaveInstructions: UInt16   = 0x0100
    static let useMyMetrics: UInt16         = 0x0200
    static let overlapCompound: UInt16      = 0x0400
}

// MARK: - Stream Reader

struct StreamReader {
    let data: Data
    var offset: Int

    mutating func readUInt8() -> UInt8 {
        let value = data[offset]
        offset += 1
        return value
    }

    mutating func readInt16BE() -> Int16 {
        let value = Int16(bitPattern: UInt16(data[offset]) << 8 | UInt16(data[offset + 1]))
        offset += 2
        return value
    }

    mutating func readUInt16BE() -> UInt16 {
        let value = UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
        offset += 2
        return value
    }

    mutating func readUInt32BE() -> UInt32 {
        let value = UInt32(data[offset]) << 24 |
                    UInt32(data[offset + 1]) << 16 |
                    UInt32(data[offset + 2]) << 8 |
                    UInt32(data[offset + 3])
        offset += 4
        return value
    }

    mutating func readBytes(_ count: Int) -> [UInt8] {
        guard count > 0 else { return [] }
        let endOffset = min(offset + count, data.count)
        let bytes = Array(data[offset..<endOffset])
        offset = endOffset
        return bytes
    }
}

// MARK: - Errors

enum GlyfTransformError: Error {
    case invalidHeader
    case invalidTripletFlag
    case invalidData
}

// MARK: - Data Extensions

private extension Data {
    func readUInt16BE(at offset: inout Int) -> UInt16 {
        let value = UInt16(self[offset]) << 8 | UInt16(self[offset + 1])
        offset += 2
        return value
    }

    func readUInt32BE(at offset: inout Int) -> UInt32 {
        let value = UInt32(self[offset]) << 24 |
                    UInt32(self[offset + 1]) << 16 |
                    UInt32(self[offset + 2]) << 8 |
                    UInt32(self[offset + 3])
        offset += 4
        return value
    }

    mutating func appendInt16BE(_ value: Int16) {
        let unsigned = UInt16(bitPattern: value)
        append(UInt8((unsigned >> 8) & 0xFF))
        append(UInt8(unsigned & 0xFF))
    }

    mutating func appendUInt16BE(_ value: UInt16) {
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8(value & 0xFF))
    }

    mutating func appendUInt32BE(_ value: UInt32) {
        append(UInt8((value >> 24) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8(value & 0xFF))
    }
}
