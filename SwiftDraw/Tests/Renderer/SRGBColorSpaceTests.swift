//
//  SRGBColorSpaceTests.swift
//  SwiftDraw
//
//  Distributed under the permissive zlib license
//  Get the latest version from here:
//
//  https://github.com/swhitty/SwiftDraw
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

@testable import SwiftDraw
import Foundation
import Testing

/// SVG colours are sRGB (display-p3 stays Display P3) and nothing uses DeviceRGB,
/// so the destination alone decides the output space.
struct SRGBColorSpaceTests {

    @Test
    func generatedSwiftUsesSRGB() throws {
        let code = try CGTextRenderer.render(
            data: Data(
                #"""
                <svg width="10" height="10" xmlns="http://www.w3.org/2000/svg">
                    <linearGradient id="g">
                        <stop offset="0" stop-color="red" />
                        <stop offset="1" stop-color="blue" />
                    </linearGradient>
                    <rect width="5" height="10" fill="#ff8000" />
                    <rect x="5" width="5" height="10" fill="url(#g)" />
                </svg>
                """#.utf8
            ),
            options: .default,
            api: .uiKit,
            precision: 2
        )

        #expect(code.contains("let rgb = CGColorSpace(name: CGColorSpace.sRGB)!"))
        #expect(code.contains("colorsSpace: rgb,"))
        #expect(!code.contains("DeviceRGB"))
    }

    @Test
    func generatedSwiftKeepsDisplayP3() throws {
        let code = try CGTextRenderer.render(
            data: Data(
                #"""
                <svg width="10" height="10" xmlns="http://www.w3.org/2000/svg">
                    <rect width="10" height="10" fill="color(display-p3 1 0 0)" />
                </svg>
                """#.utf8
            ),
            options: .default,
            api: .uiKit,
            precision: 2
        )

        #expect(code.contains("let p3 = CGColorSpace(name: CGColorSpace.displayP3)!"))
        #expect(!code.contains("DeviceRGB"))
    }
}

#if canImport(CoreGraphics)
import CoreGraphics
import ImageIO

extension SRGBColorSpaceTests {

    @Test(arguments: [
        (LayerTree.Color.rgba(r: 1, g: 0.5, b: 0, a: 1, space: .srgb), CGColorSpace.sRGB as String),
        (.none, CGColorSpace.sRGB as String),
        (.rgba(r: 1, g: 0, b: 0, a: 1, space: .p3), CGColorSpace.displayP3 as String),
        (.gray(white: 0.5, a: 1), CGColorSpace.extendedGray as String),
    ])
    func createdColorSpace(color: LayerTree.Color, name: String) {
        let cg = CGProvider().createColor(from: color)
        #expect(cg.colorSpace?.name as String? == name)
    }

    @Test
    func extendedGrayMatchesSRGBPixels() throws {
        for white in stride(from: CGFloat(0), through: 1, by: 0.05) {
            let gray = CGProvider().createColor(from: .gray(white: Float(white), a: 1))
            let srgb = CGProvider().createColor(
                from: .rgba(r: Float(white), g: Float(white), b: Float(white), a: 1, space: .srgb)
            )
            #expect(try pixel(filling: gray) == pixel(filling: srgb))
        }
    }

    @Test
    func srgbGradientUsesSRGB() {
        let gradient = LayerTree.Gradient(stops: [
            .init(offset: 0, color: .rgba(r: 1, g: 0, b: 0, a: 1, space: .srgb), opacity: 1),
            .init(offset: 1, color: .rgba(r: 0, g: 0, b: 1, a: 1, space: .srgb), opacity: 1),
        ])
        #expect(CGProvider().createColorSpace(for: gradient.colorSpace).name == CGColorSpace.sRGB)
    }

    @Test
    func mixedGradientUsesDisplayP3() {
        // Display P3 holds every sRGB colour, so mixed stops share it.
        let gradient = LayerTree.Gradient(stops: [
            .init(offset: 0, color: .rgba(r: 1, g: 0, b: 0, a: 1, space: .srgb), opacity: 1),
            .init(offset: 1, color: .rgba(r: 0, g: 1, b: 0, a: 1, space: .p3), opacity: 1),
        ])
        #expect(CGProvider().createColorSpace(for: gradient.colorSpace).name == CGColorSpace.displayP3)
    }

    private func pixel(filling color: CGColor) throws -> [UInt8] {
        let ctx = try #require(
            CGContext(
                data: nil,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        ctx.setFillColor(color)
        ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        let data = try #require(ctx.data).assumingMemoryBound(to: UInt8.self)
        return (0..<4).map { data[$0] }
    }
}
#endif

#if canImport(AppKit) && !targetEnvironment(macCatalyst) || canImport(UIKit) && !os(watchOS)
import SwiftDrawDOM

extension SRGBColorSpaceTests {

    @Test(arguments: [ExportFormat.png, .jpeg])
    func exportedImageIsTaggedSRGB(format: ExportFormat) throws {
        let svg = try #require(
            SVG(
                xml: #"""
                    <svg width="4" height="4" xmlns="http://www.w3.org/2000/svg">
                        <rect width="4" height="4" fill="#ff0000" />
                    </svg>
                    """#
            )
        )
        let data = try format.data(of: svg)
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.colorSpace?.name == CGColorSpace.sRGB)
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        #expect(properties[kCGImagePropertyProfileName] as? String == "sRGB IEC61966-2.1")

        // read back in its own space: #ff0000 is stored as 255, 0, 0
        let ctx = try #require(
            CGContext(
                data: nil,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        let px = try #require(ctx.data).assumingMemoryBound(to: UInt8.self)
        #expect(px[0] >= 254 && px[1] <= 1 && px[2] <= 1)
    }

    enum ExportFormat: CustomTestStringConvertible {
        case png
        case jpeg

        var testDescription: String { self == .png ? "png" : "jpeg" }

        func data(of svg: SVG) throws -> Data {
            switch self {
            case .png: return try svg.pngData(scale: 1)
            case .jpeg: return try svg.jpegData(scale: 1)
            }
        }
    }
}

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit

extension SRGBColorSpaceTests {

    @Test(arguments: [false, true])
    func exportBitmapDrawsInSRGB(isOpaque: Bool) throws {
        let svg = try #require(SVG(xml: #"<svg width="1" height="1" xmlns="http://www.w3.org/2000/svg" />"#))
        let bitmap = try #require(svg.makeBitmap(width: 2, height: 2, isOpaque: isOpaque))
        #expect(bitmap.colorSpace == .sRGB)
        let ctx = try #require(NSGraphicsContext(bitmapImageRep: bitmap)?.cgContext)
        #expect(ctx.colorSpace?.name == CGColorSpace.sRGB)
    }
}
#endif

private extension SVG {
    init?(xml: String) {
        self.init(data: Data(xml.utf8))
    }
}
#endif
