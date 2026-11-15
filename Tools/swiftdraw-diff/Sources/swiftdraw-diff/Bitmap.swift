import Accelerate
import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// sRGB, 8-bit, premultiplied RGBA, always composited onto opaque white.
struct Bitmap {
    var width: Int
    var height: Int
    var pixels: [UInt8]

    static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    /// Creates a white bitmap and lets `draw` paint into it.
    /// The context uses CoreGraphics' native bottom-left origin.
    static func render(width: Int, height: Int, draw: (CGContext) -> Void) -> Bitmap? {
        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.interpolationQuality = .high
        draw(ctx)
        guard let data = ctx.data else { return nil }
        let buffer = UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: width * height * 4)
        return Bitmap(width: width, height: height, pixels: Array(buffer))
    }

    var sha256: String {
        SHA256.hash(data: Data(pixels)).map { String(format: "%02x", $0) }.joined()
    }

    var isBlank: Bool {
        !pixels.contains { $0 < 250 }
    }

    /// The same image with its rows in reverse order.
    func flippedVertically() -> Bitmap {
        let stride = width * 4
        var flipped = [UInt8]()
        flipped.reserveCapacity(pixels.count)
        for row in (0..<height).reversed() {
            flipped.append(contentsOf: pixels[(row * stride)..<((row + 1) * stride)])
        }
        return Bitmap(width: width, height: height, pixels: flipped)
    }

    func makeCGImage() -> CGImage? {
        let data = Data(pixels) as CFData
        guard let provider = CGDataProvider(data: data) else { return nil }
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: width * 4, space: Self.colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }

    func writePNG(to url: URL) throws {
        guard let image = makeCGImage(),
              let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw CocoaError(.fileWriteUnknown) }
    }

    /// Box blur, used to absorb anti-aliasing differences before comparing.
    func blurred(radius: Int) -> Bitmap {
        guard radius > 0 else { return self }
        var src = pixels
        var dst = [UInt8](repeating: 0, count: pixels.count)
        let k = UInt32(radius * 2 + 1)
        src.withUnsafeMutableBytes { s in
            dst.withUnsafeMutableBytes { d in
                var sb = vImage_Buffer(data: s.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width * 4)
                var db = vImage_Buffer(data: d.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width * 4)
                _ = vImageBoxConvolve_ARGB8888(&sb, &db, nil, 0, 0, k, k, nil, vImage_Flags(kvImageEdgeExtend))
            }
        }
        return Bitmap(width: width, height: height, pixels: dst)
    }
}

struct Diff {
    /// Pixels that are non-white in either image.
    var inkPixels: Int
    /// Ink pixels whose max channel delta exceeds the threshold.
    var diffPixels: Int
    /// Mean absolute channel error over all pixels, 0...255.
    var meanError: Double
    var image: Bitmap

    /// Fraction of ink pixels that differ.
    var score: Double {
        inkPixels == 0 ? 0 : Double(diffPixels) / Double(inkPixels)
    }

    static func compare(_ a: Bitmap, _ b: Bitmap, blur: Int, threshold: Int = 32) -> Diff? {
        guard a.width == b.width, a.height == b.height else { return nil }
        let ba = a.blurred(radius: blur), bb = b.blurred(radius: blur)
        var ink = 0, diff = 0, total = 0
        var out = [UInt8](repeating: 255, count: a.pixels.count)
        let count = a.width * a.height
        for p in 0..<count {
            let i = p * 4
            var maxDelta = 0
            var isInk = false
            for c in 0..<3 {
                let va = Int(ba.pixels[i + c]), vb = Int(bb.pixels[i + c])
                maxDelta = max(maxDelta, abs(va - vb))
                total += abs(Int(a.pixels[i + c]) - Int(b.pixels[i + c]))
                if va < 245 || vb < 245 { isInk = true }
            }
            // Diff image: faded reference, red where the images differ.
            let lum = (Int(a.pixels[i]) * 3 + Int(a.pixels[i + 1]) * 6 + Int(a.pixels[i + 2])) / 10
            let faded = UInt8(200 + lum * 55 / 255)
            if isInk { ink += 1 }
            if isInk && maxDelta > threshold {
                diff += 1
                out[i] = 230; out[i + 1] = 30; out[i + 2] = 30
            } else {
                out[i] = faded; out[i + 1] = faded; out[i + 2] = faded
            }
            out[i + 3] = 255
        }
        return Diff(
            inkPixels: ink,
            diffPixels: diff,
            meanError: Double(total) / Double(count * 3),
            image: Bitmap(width: a.width, height: a.height, pixels: out)
        )
    }
}
