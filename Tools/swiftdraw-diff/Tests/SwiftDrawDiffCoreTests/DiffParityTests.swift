import Foundation
import JavaScriptCore
import Testing
@testable import SwiftDrawDiffCore

/// The Swift diff must give exactly the scores the scoring page's JavaScript gave, so results
/// stay comparable with earlier runs. This runs that JavaScript (copied verbatim from the page
/// before scoring moved to Swift) in JavaScriptCore on the same images.
struct DiffParityTests {

    @Test(arguments: [(0, 0), (1, 32), (2, 32), (3, 32), (0, 2)])
    func matchesJavaScript(blur: Int, threshold: Int) throws {
        for seed in 1...4 {
            let w = 37, h = 23
            let a = Self.image(width: w, height: h, seed: UInt64(seed))
            let b = Self.image(width: w, height: h, seed: UInt64(seed * 7 + 3))
            let swift = try #require(Diff.compare(a, b, blur: blur, threshold: threshold))
            let js = try Self.javaScriptDiff(a, b, blur: blur, threshold: threshold)
            #expect(swift.ink == js.ink)
            #expect(swift.differing == js.differing)
            #expect(swift.image.pixels == js.image)
        }
    }

    @Test
    func blurMatchesJavaScript() throws {
        let a = Self.image(width: 19, height: 11, seed: 42)
        let context = try Self.context()
        context.setObject(a.pixels.map(Int.init), forKeyedSubscript: "src" as NSString)
        let result = try #require(context.evaluateScript("Array.from(boxBlur(new Uint8ClampedArray(src), 19, 11, 2))")?.toArray() as? [NSNumber])
        #expect(Diff.boxBlur(a.pixels, width: 19, height: 11, radius: 2) == result.map(\.uint8Value))
    }

    @Test
    func clampingMatchesUint8ClampedArray() throws {
        let values = [2.5, 3.5, 0.5, 254.5, -1, 300, 127.49, 127.51, .nan]
        let context = try Self.context()
        context.setObject(values, forKeyedSubscript: "values" as NSString)
        let js = try #require(context.evaluateScript("Array.from(new Uint8ClampedArray(values))")?.toArray() as? [NSNumber])
        #expect(values.map(Diff.clamped) == js.map(\.uint8Value))
    }

    /// Shapes in a few colours on white plus noise, so blurring produces fractional values.
    static func image(width: Int, height: Int, seed: UInt64) -> Bitmap {
        var state = seed &* 6364136223846793005 &+ 1442695040888963407
        func next() -> Int {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Int(truncatingIfNeeded: state >> 33)
        }
        var image = Bitmap.white(width: width, height: height)
        for _ in 0..<6 {
            let x0 = next() % width, y0 = next() % height
            let x1 = min(width, x0 + 1 + next() % 12), y1 = min(height, y0 + 1 + next() % 9)
            let colour = [UInt8(next() % 256), UInt8(next() % 256), UInt8(next() % 256)]
            for y in y0..<y1 { for x in x0..<x1 { for c in 0..<3 { image.pixels[(y * width + x) * 4 + c] = colour[c] } } }
        }
        for _ in 0..<40 {
            let p = (next() % (width * height)) * 4
            image.pixels[p + next() % 3] = UInt8(next() % 256)
        }
        return image
    }

    static func context() throws -> JSContext {
        let context = try #require(JSContext())
        context.exceptionHandler = { _, exception in Issue.record("JavaScript: \(exception?.toString() ?? "?")") }
        context.evaluateScript("""
        class ImageData { constructor(w, h) { this.width = w; this.height = h; this.data = new Uint8ClampedArray(w * h * 4); } }
        const BLUR = 2, THRESHOLD = 32;
        """)
        context.evaluateScript(pageScript)
        return context
    }

    static func javaScriptDiff(_ a: Bitmap, _ b: Bitmap, blur: Int, threshold: Int) throws -> (ink: Int, differing: Int, image: [UInt8]) {
        let context = try context()
        context.setObject(a.pixels.map(Int.init), forKeyedSubscript: "a" as NSString)
        context.setObject(b.pixels.map(Int.init), forKeyedSubscript: "b" as NSString)
        let script = """
        (() => {
          const img = p => ({ data: new Uint8ClampedArray(p) });
          const d = diff(img(a), img(b), \(a.width), \(a.height), \(blur), \(threshold));
          return { ink: d.ink, differing: d.differing, image: Array.from(d.image.data) };
        })()
        """
        let result = try #require(context.evaluateScript(script)?.toDictionary())
        let image = try #require(result["image"] as? [NSNumber]).map(\.uint8Value)
        return (try #require(result["ink"] as? Int), try #require(result["differing"] as? Int), image)
    }

    /// `boxBlur` and `diff` from the scoring page (PageShared.swift), verbatim.
    static let pageScript = #"""
    function boxBlur(src, w, h, r) {
      if (r <= 0) return src;
      const tmp = new Float32Array(src.length), out = new Uint8ClampedArray(src.length);
      const k = 2 * r + 1;
      for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) for (let c = 0; c < 3; c++) {
        let s = 0;
        for (let i = -r; i <= r; i++) { const xx = Math.min(w - 1, Math.max(0, x + i)); s += src[(y * w + xx) * 4 + c]; }
        tmp[(y * w + x) * 4 + c] = s / k;
      }
      for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) for (let c = 0; c < 3; c++) {
        let s = 0;
        for (let i = -r; i <= r; i++) { const yy = Math.min(h - 1, Math.max(0, y + i)); s += tmp[(yy * w + x) * 4 + c]; }
        out[(y * w + x) * 4 + c] = s / k;
      }
      return out;
    }
    
    // Blurred, thresholded diff of two ImageData. score = differing ink pixels / ink pixels.
    function diff(a, b, w, h, blur = BLUR, threshold = THRESHOLD) {
      const ba = boxBlur(a.data, w, h, blur), bb = boxBlur(b.data, w, h, blur);
      const out = new ImageData(w, h);
      let ink = 0, bad = 0;
      for (let p = 0; p < w * h; p++) {
        const i = p * 4;
        let d = 0, isInk = false;
        for (let c = 0; c < 3; c++) {
          d = Math.max(d, Math.abs(ba[i + c] - bb[i + c]));
          if (ba[i + c] < 245 || bb[i + c] < 245) isInk = true;
        }
        const lum = (a.data[i] * 3 + a.data[i + 1] * 6 + a.data[i + 2]) / 10;
        const faded = 200 + lum * 55 / 255;
        if (isInk) ink++;
        if (isInk && d > threshold) { bad++; out.data.set([230, 30, 30, 255], i); }
        else out.data.set([faded, faded, faded, 255], i);
      }
      return { score: ink ? bad / ink : 0, image: out, differing: bad, ink };
    }
    """#
}
