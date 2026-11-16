import Foundation

/// The score swiftdraw-diff has always used: blur both images a little to absorb anti-aliasing,
/// then count the "ink" pixels (non-white in either) whose largest channel difference exceeds
/// a threshold. score = differing ink pixels / ink pixels.
///
/// This is an exact port of the JavaScript diff that used to run in the scoring page (box blur
/// through a Float32Array, results stored to a Uint8ClampedArray), so scores carry over.
/// `DiffParityTests` runs both on the same images.
public struct Diff: Sendable {
    /// Pixels that are non-white (any channel < 245 after blurring) in either image.
    public var ink: Int
    /// Ink pixels whose largest channel difference after blurring exceeds the threshold.
    public var differing: Int
    /// The first image faded, with differing pixels in red.
    public var image: Bitmap

    /// Fraction of ink pixels that differ, 0...1.
    public var score: Double {
        ink == 0 ? 0 : Double(differing) / Double(ink)
    }

    public static let threshold = 32

    /// The blur radius used at `scale` pixels per point.
    public static func blur(scale: Int) -> Int { scale }

    /// nil when the images are different sizes.
    public static func compare(_ a: Bitmap, _ b: Bitmap, blur: Int, threshold: Int = Diff.threshold) -> Diff? {
        guard a.width == b.width, a.height == b.height else { return nil }
        let w = a.width, h = a.height
        let ba = boxBlur(a.pixels, width: w, height: h, radius: blur)
        let bb = boxBlur(b.pixels, width: w, height: h, radius: blur)
        var out = [UInt8](repeating: 0, count: a.pixels.count)
        var ink = 0, bad = 0
        for p in 0..<(w * h) {
            let i = p * 4
            var d = 0
            var isInk = false
            for c in 0..<3 {
                let va = Int(ba[i + c]), vb = Int(bb[i + c])
                d = max(d, abs(va - vb))
                if va < 245 || vb < 245 { isInk = true }
            }
            if isInk { ink += 1 }
            if isInk && d > threshold {
                bad += 1
                out[i] = 230; out[i + 1] = 30; out[i + 2] = 30
            } else {
                let lum = (Double(a.pixels[i]) * 3 + Double(a.pixels[i + 1]) * 6 + Double(a.pixels[i + 2])) / 10
                let faded = clamped(200 + lum * 55 / 255)
                out[i] = faded; out[i + 1] = faded; out[i + 2] = faded
            }
            out[i + 3] = 255
        }
        return Diff(ink: ink, differing: bad, image: Bitmap(width: w, height: h, pixels: out))
    }

    /// Separable box blur of the RGB channels, edges clamped. Alpha comes out as 0, as in the page.
    static func boxBlur(_ src: [UInt8], width w: Int, height h: Int, radius r: Int) -> [UInt8] {
        guard r > 0 else { return src }
        let k = Double(2 * r + 1)
        var tmp = [Float](repeating: 0, count: src.count)
        var out = [UInt8](repeating: 0, count: src.count)
        for y in 0..<h {
            for x in 0..<w {
                for c in 0..<3 {
                    var s = 0.0
                    for i in -r...r {
                        let xx = min(w - 1, max(0, x + i))
                        s += Double(src[(y * w + xx) * 4 + c])
                    }
                    tmp[(y * w + x) * 4 + c] = Float(s / k)
                }
            }
        }
        for y in 0..<h {
            for x in 0..<w {
                for c in 0..<3 {
                    var s = 0.0
                    for i in -r...r {
                        let yy = min(h - 1, max(0, y + i))
                        s += Double(tmp[(yy * w + x) * 4 + c])
                    }
                    out[(y * w + x) * 4 + c] = clamped(s / k)
                }
            }
        }
        return out
    }

    /// JavaScript's Uint8ClampedArray conversion: clamp to 0...255, round half to even.
    static func clamped(_ value: Double) -> UInt8 {
        guard !value.isNaN else { return 0 }
        return UInt8(min(255, max(0, value)).rounded(.toNearestOrEven))
    }
}
