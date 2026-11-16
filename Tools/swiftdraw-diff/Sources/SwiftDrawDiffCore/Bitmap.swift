public import CoreGraphics
public import Foundation
import ImageIO
import UniformTypeIdentifiers

/// An opaque 8-bit RGBA image (alpha is always 255): a rendering composited onto white.
///
/// Every renderer's PNG is read as sRGB whatever its colour tag says (resvg writes none,
/// swiftdrawcli and WebKit tag sRGB), so comparing two images compares the bytes each
/// renderer produced, with no colour conversion in between.
public struct Bitmap: Equatable, Sendable {
    public var width: Int
    public var height: Int
    /// RGBA, row 0 at the top.
    public var pixels: [UInt8]

    public init(width: Int, height: Int, pixels: [UInt8]) {
        precondition(pixels.count == width * height * 4)
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    public static func white(width: Int, height: Int) -> Bitmap {
        Bitmap(width: width, height: height, pixels: [UInt8](repeating: 255, count: width * height * 4))
    }

    public static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

    public struct DecodeError: Error, CustomStringConvertible {
        public var description: String
    }

    /// Decodes a PNG (or any image ImageIO reads) and composites it onto white.
    public init(imageData data: Data) throws {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            throw DecodeError(description: "not a readable image")
        }
        // Read RGB images as sRGB without converting; anything else (grey, indexed) is converted.
        let input = image.colorSpace?.model == .rgb ? (image.copy(colorSpace: Self.sRGB) ?? image) : image
        let w = image.width, h = image.height
        var pixels = [UInt8](repeating: 255, count: w * h * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let ctx = CGContext(
                data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                space: Self.sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            ctx.interpolationQuality = .none
            ctx.draw(input, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { throw DecodeError(description: "could not create a \(w)×\(h) bitmap") }
        self.init(width: w, height: h, pixels: pixels)
    }

    public init(contentsOf url: URL) throws {
        try self.init(imageData: Data(contentsOf: url))
    }

    public var isBlank: Bool {
        for i in stride(from: 0, to: pixels.count, by: 4) where pixels[i] < 250 || pixels[i + 1] < 250 || pixels[i + 2] < 250 {
            return false
        }
        return true
    }

    /// This image at `width`×`height`: cropped, or padded with white, at the top-left. Never resampled.
    public func fitted(width: Int, height: Int) -> Bitmap {
        guard width != self.width || height != self.height else { return self }
        var out = Bitmap.white(width: width, height: height)
        let rowBytes = min(width, self.width) * 4
        for y in 0..<min(height, self.height) {
            let src = y * self.width * 4, dst = y * width * 4
            out.pixels.replaceSubrange(dst..<(dst + rowBytes), with: pixels[src..<(src + rowBytes)])
        }
        return out
    }

    public func pngData() throws -> Data {
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(
                width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                space: Self.sRGB, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
              ) else {
            throw DecodeError(description: "could not create a \(width)×\(height) image")
        }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data as CFMutableData, UTType.png.identifier as CFString, 1, nil) else {
            throw DecodeError(description: "could not create a PNG encoder")
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw DecodeError(description: "could not encode PNG") }
        return data as Data
    }

    public func writePNG(to url: URL) throws {
        try pngData().write(to: url)
    }
}
