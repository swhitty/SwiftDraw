import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import SwiftDrawDiffCore

struct BitmapTests {

    @Test
    func pngRoundTrip() throws {
        var image = Bitmap.white(width: 3, height: 2)
        image.pixels.replaceSubrange(0..<4, with: [10, 20, 30, 255])  // top-left
        image.pixels.replaceSubrange(20..<24, with: [200, 100, 50, 255])  // bottom-right
        let decoded = try Bitmap(imageData: image.pngData())
        #expect(decoded == image)
        #expect(!decoded.isBlank)
        #expect(Bitmap.white(width: 4, height: 4).isBlank)
    }

    @Test
    func transparencyIsCompositedOntoWhite() throws {
        // A fully transparent pixel and a half-transparent black one.
        let png = try Self.png(width: 2, height: 1, rgba: [0, 0, 0, 0, 0, 0, 0, 128], colorSpace: Bitmap.sRGB)
        let bitmap = try Bitmap(imageData: png)
        #expect(Array(bitmap.pixels[0..<4]) == [255, 255, 255, 255])
        #expect((126...128).contains(Int(bitmap.pixels[4])))
        #expect(bitmap.pixels[7] == 255)
    }

    @Test
    func rgbIsReadAsSRGBWithoutConversion() throws {
        // resvg's PNGs carry no colour tag; tagged ones are read as sRGB bytes too, never converted.
        let p3 = try #require(CGColorSpace(name: CGColorSpace.displayP3))
        let png = try Self.png(width: 1, height: 1, rgba: [255, 0, 0, 255], colorSpace: p3)
        #expect(try Array(Bitmap(imageData: png).pixels[0..<4]) == [255, 0, 0, 255])
    }

    @Test
    func fittedPadsAndCropsAtTopLeft() {
        var image = Bitmap(width: 2, height: 2, pixels: [UInt8](repeating: 0, count: 16))
        image.pixels[15] = 255
        let padded = image.fitted(width: 3, height: 3)
        #expect(padded.width == 3 && padded.height == 3)
        #expect(Array(padded.pixels[0..<4]) == [0, 0, 0, 0])
        #expect(Array(padded.pixels[8..<12]) == [255, 255, 255, 255])  // new column
        #expect(Array(padded.pixels[24..<28]) == [255, 255, 255, 255])  // new row
        let cropped = image.fitted(width: 1, height: 1)
        #expect(cropped.pixels == [0, 0, 0, 0])
        #expect(image.fitted(width: 2, height: 2) == image)
    }

    @Test
    func diffScoresInkThatDiffers() throws {
        let white = Bitmap.white(width: 10, height: 10)
        var mark = white
        for p in 0..<10 { mark.pixels.replaceSubrange((p * 4)..<(p * 4 + 3), with: [0, 0, 0]) }  // top row black
        #expect(try #require(Diff.compare(white, white, blur: 0)).score == 0)
        let d = try #require(Diff.compare(white, mark, blur: 0))
        #expect(d.ink == 10)
        #expect(d.differing == 10)
        #expect(d.score == 1)
        #expect(Diff.compare(white, Bitmap.white(width: 9, height: 10), blur: 0) == nil)
    }

    static func png(width: Int, height: Int, rgba: [UInt8], colorSpace: CGColorSpace) throws -> Data {
        let provider = try #require(CGDataProvider(data: Data(rgba) as CFData))
        let image = try #require(
            CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        )
        let data = NSMutableData()
        let dest = try #require(
            CGImageDestinationCreateWithData(data as CFMutableData, UTType.png.identifier as CFString, 1, nil)
        )
        CGImageDestinationAddImage(dest, image, nil)
        #expect(CGImageDestinationFinalize(dest))
        return data as Data
    }
}

struct RenderCacheTests {

    @Test
    func storesAndFindsRenders() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "RenderCacheTests-\(UUID().uuidString)"
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = RenderCache(root: root)
        #expect(cache.lookup("r", "k", as: RenderResult.self) == nil)

        let png = root.appendingPathComponent("in.png")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: png)
        cache.store("r", "k", meta: RenderResult.ok, png: png)
        cache.store("r", "fail", meta: RenderResult.failed("parse error"), png: nil)

        let hit = try #require(cache.lookup("r", "k", as: RenderResult.self))
        #expect(hit.meta == .ok)
        #expect(try Data(contentsOf: #require(hit.png)) == Data([1, 2, 3]))
        let miss = try #require(cache.lookup("r", "fail", as: RenderResult.self))
        #expect(miss.meta == .failed("parse error"))
        #expect(miss.png == nil)
    }

    @Test
    func disabledCacheStoresNothing() {
        let cache = RenderCache(root: nil)
        cache.store("r", "k", meta: RenderResult.ok, png: nil)
        #expect(cache.lookup("r", "k", as: RenderResult.self) == nil)
        #expect(cache.swiftdrawBinary(sha: "abc") == nil)
    }

    @Test
    func hashesAreStable() {
        #expect(RenderCache.hash("a", "b") == RenderCache.hash("a", "b"))
        #expect(RenderCache.hash("a", "b") != RenderCache.hash("ab"))
        #expect(RenderCache.hash(Data("x".utf8)) == "2d711642b726b04401627ca9fbac32f5c8530fb1903cc4db02258717921a4881")
    }
}
