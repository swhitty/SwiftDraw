//
//  Renderer.RendererCGTextTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 27/2/22.
//  Copyright 2022 WhileLoop Pty Ltd. All rights reserved.
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
import XCTest


final class RendererCGTextTests: XCTestCase {

    func testLinesCode() throws {
        let code = try CGTextRenderer.render(svgNamed: "lines.svg")
        XCTAssertEqual(
            code,
            """
            import CoreGraphics
            import UIKit

            extension UIImage {
              static func svgImage(size: CGSize = CGSize(width: 100.0, height: 100.0)) -> UIImage {
                let f = UIGraphicsImageRendererFormat.preferred()
                f.opaque = false
                let scale = CGSize(width: size.width / 100.0, height: size.height / 100.0)
                return UIGraphicsImageRenderer(size: size, format: f).image {
                  drawImage(in: $0.cgContext, scale: scale)
                }
              }

              private static func drawImage(in ctx: CGContext, scale: CGSize) {
                ctx.scaleBy(x: scale.width, y: scale.height)
                let rgb = CGColorSpaceCreateDeviceRGB()
                let color1 = CGColor(colorSpace: rgb, components: [0, 0, 0, 1])!
                ctx.setFillColor(color1)
                let path = CGMutablePath()
                path.addLines(between: [
                  CGPoint(x: 0, y: 0),
                  CGPoint(x: 100, y: 100)
                ])
                ctx.addPath(path)
                ctx.fillPath(using: .evenOdd)
                ctx.setLineCap(.butt)
                ctx.setLineJoin(.miter)
                ctx.setLineWidth(1)
                ctx.setMiterLimit(4)
                ctx.setStrokeColor(color1)
                ctx.addPath(path)
                ctx.strokePath()
                let path1 = CGMutablePath()
                path1.addLines(between: [
                  CGPoint(x: 100, y: 0),
                  CGPoint(x: 0, y: 100)
                ])
                ctx.addPath(path1)
                ctx.fillPath(using: .evenOdd)
                ctx.addPath(path1)
                ctx.strokePath()
              }
            }
            """
        )
    }

    func testGradientAppleCode() throws {
        let code = try CGTextRenderer.render(svgNamed: "gradient-apple.svg")
        XCTAssertEqual(
            code,
            """
            import CoreGraphics
            import UIKit

            extension UIImage {
              static func svgImage(size: CGSize = CGSize(width: 512.0, height: 512.0)) -> UIImage {
                let f = UIGraphicsImageRendererFormat.preferred()
                f.opaque = false
                let scale = CGSize(width: size.width / 512.0, height: size.height / 512.0)
                return UIGraphicsImageRenderer(size: size, format: f).image {
                  drawImage(in: $0.cgContext, scale: scale)
                }
              }

              private static func drawImage(in ctx: CGContext, scale: CGSize) {
                ctx.scaleBy(x: scale.width, y: scale.height)
                ctx.saveGState()
                ctx.scaleBy(x: 1.00392, y: 1.00392)
                ctx.saveGState()
                let path = CGMutablePath()
                path.move(to: CGPoint(x: 358.161, y: 40.149))
                path.addCurve(to: CGPoint(x: 318.014, y: 143.034),
                               control1: CGPoint(x: 331.605, y: 66.705),
                               control2: CGPoint(x: 318.557, y: 102.928))
                path.addCurve(to: CGPoint(x: 344.613, y: 169.633),
                               control1: CGPoint(x: 317.814, y: 157.83),
                               control2: CGPoint(x: 329.817, y: 169.833))
                path.addCurve(to: CGPoint(x: 447.498, y: 129.486),
                               control1: CGPoint(x: 384.719, y: 169.09),
                               control2: CGPoint(x: 420.942, y: 156.042))
                path.addCurve(to: CGPoint(x: 487.645, y: 26.601),
                               control1: CGPoint(x: 474.054, y: 102.93),
                               control2: CGPoint(x: 487.102, y: 66.707))
                path.addCurve(to: CGPoint(x: 461.046, y: 0.00199),
                               control1: CGPoint(x: 487.845, y: 11.805),
                               control2: CGPoint(x: 475.842, y: -0.198))
                path.addCurve(to: CGPoint(x: 358.161, y: 40.149),
                               control1: CGPoint(x: 420.94, y: 0.545),
                               control2: CGPoint(x: 384.717, y: 13.593))
                path.closeSubpath()
                ctx.addPath(path)
                ctx.clip(using: .evenOdd)
                ctx.setAlpha(1)
                let rgb = CGColorSpaceCreateDeviceRGB()
                let color1 = CGColor(colorSpace: rgb, components: [0.635, 0.902, 0.18, 1])!
                let color2 = CGColor(colorSpace: rgb, components: [0.0353, 0.655, 0.427, 1])!
                let color3 = CGColor(colorSpace: rgb, components: [0.00392, 0.482, 0.306, 1])!
                var locations: [CGFloat] = [0.0, 0.7542, 1.0]
                let gradient = CGGradient(
                  colorsSpace: rgb,
                  colors: [color1, color2, color3] as CFArray,
                  locations: &locations
                )!
                ctx.drawLinearGradient(gradient,
                                   start: CGPoint(x: 316.598, y: 84.818),
                                   end: CGPoint(x: 490.768, y: 84.818),
                                   options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
                ctx.restoreGState()
                ctx.saveGState()
                let path1 = CGMutablePath()
                path1.move(to: CGPoint(x: 461.046, y: 0.002))
                path1.addCurve(to: CGPoint(x: 432.793, y: 2.598),
                               control1: CGPoint(x: 451.375, y: 0.133),
                               control2: CGPoint(x: 441.932, y: 0.999))
                path1.addCurve(to: CGPoint(x: 447.624, y: 26.601),
                               control1: CGPoint(x: 441.678, y: 6.885),
                               control2: CGPoint(x: 447.767, y: 16.028))
                path1.addCurve(to: CGPoint(x: 407.477, y: 129.486),
                               control1: CGPoint(x: 447.081, y: 66.707),
                               control2: CGPoint(x: 434.033, y: 102.93))
                path1.addCurve(to: CGPoint(x: 332.845, y: 167.037),
                               control1: CGPoint(x: 387.325, y: 149.638),
                               control2: CGPoint(x: 361.603, y: 162.00401))
                path1.addCurve(to: CGPoint(x: 344.612, y: 169.633),
                               control1: CGPoint(x: 336.395, y: 168.75),
                               control2: CGPoint(x: 340.389, y: 169.69))
                path1.addCurve(to: CGPoint(x: 447.497, y: 129.486),
                               control1: CGPoint(x: 384.718, y: 169.09),
                               control2: CGPoint(x: 420.941, y: 156.042))
                path1.addCurve(to: CGPoint(x: 487.644, y: 26.601),
                               control1: CGPoint(x: 474.053, y: 102.93),
                               control2: CGPoint(x: 487.101, y: 66.707))
                path1.addCurve(to: CGPoint(x: 461.046, y: 0.00199),
                               control1: CGPoint(x: 487.845, y: 11.805),
                               control2: CGPoint(x: 475.842, y: -0.198))
                path1.closeSubpath()
                ctx.addPath(path1)
                ctx.clip(using: .evenOdd)
                ctx.setAlpha(1)
                ctx.drawLinearGradient(gradient,
                                   start: CGPoint(x: 189.125, y: 84.818),
                                   end: CGPoint(x: 519.599, y: 84.818),
                                   options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
                ctx.restoreGState()
                ctx.saveGState()
                let path2 = CGMutablePath()
                path2.move(to: CGPoint(x: 318.012, y: 194.555))
                path2.addCurve(to: CGPoint(x: 300.512, y: 177.055),
                               control1: CGPoint(x: 308.347, y: 194.555),
                               control2: CGPoint(x: 300.512, y: 186.72))
                path2.addLine(to: CGPoint(x: 300.512, y: 156.454))
                path2.addCurve(to: CGPoint(x: 254.983, y: 46.537),
                               control1: CGPoint(x: 300.512, y: 114.933),
                               control2: CGPoint(x: 284.343, y: 75.897))
                path2.addLine(to: CGPoint(x: 251.439, y: 42.992))
                path2.addCurve(to: CGPoint(x: 251.44, y: 18.244),
                               control1: CGPoint(x: 244.605, y: 36.158),
                               control2: CGPoint(x: 244.606, y: 25.077))
                path2.addCurve(to: CGPoint(x: 276.189, y: 18.245),
                               control1: CGPoint(x: 258.274, y: 11.408),
                               control2: CGPoint(x: 269.355, y: 11.411))
                path2.addLine(to: CGPoint(x: 279.732, y: 21.789))
                path2.addCurve(to: CGPoint(x: 321.015, y: 83.573),
                               control1: CGPoint(x: 297.505, y: 39.563),
                               control2: CGPoint(x: 311.396, y: 60.351))
                path2.addCurve(to: CGPoint(x: 335.512, y: 156.454),
                               control1: CGPoint(x: 330.635, y: 106.797),
                               control2: CGPoint(x: 335.512, y: 131.317))
                path2.addLine(to: CGPoint(x: 335.512, y: 177.055))
                path2.addCurve(to: CGPoint(x: 318.012, y: 194.555),
                               control1: CGPoint(x: 335.512, y: 186.72),
                               control2: CGPoint(x: 327.677, y: 194.555))
                path2.closeSubpath()
                ctx.addPath(path2)
                ctx.clip(using: .evenOdd)
                ctx.setAlpha(1)
                let color4 = CGColor(colorSpace: rgb, components: [0.655, 0.608, 0.655, 1])!
                let color5 = CGColor(colorSpace: rgb, components: [0.478, 0.427, 0.475, 1])!
                let color6 = CGColor(colorSpace: rgb, components: [0.408, 0.369, 0.408, 1])!
                var locations1: [CGFloat] = [0.0, 0.7487, 1.0]
                let gradient1 = CGGradient(
                  colorsSpace: rgb,
                  colors: [color4, color5, color6] as CFArray,
                  locations: &locations1
                )!
                ctx.drawLinearGradient(gradient1,
                                   start: CGPoint(x: 246.314, y: 103.837),
                                   end: CGPoint(x: 335.512, y: 103.837),
                                   options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
                ctx.restoreGState()
                ctx.saveGState()
                let path3 = CGMutablePath()
                path3.move(to: CGPoint(x: 508.651, y: 259.44))
                path3.addLine(to: CGPoint(x: 486.152, y: 393.318))
                path3.addCurve(to: CGPoint(x: 413.245, y: 497.709),
                               control1: CGPoint(x: 477.939, y: 438.35),
                               control2: CGPoint(x: 450.505, y: 475.767))
                path3.addCurve(to: CGPoint(x: 339.328, y: 506.186),
                               control1: CGPoint(x: 390.977, y: 510.823),
                               control2: CGPoint(x: 364.231, y: 513.093))
                path3.addCurve(to: CGPoint(x: 318.679, y: 503.427),
                               control1: CGPoint(x: 332.898, y: 504.403),
                               control2: CGPoint(x: 325.94, y: 503.427))
                path3.addCurve(to: CGPoint(x: 298.03, y: 506.186),
                               control1: CGPoint(x: 311.419, y: 503.427),
                               control2: CGPoint(x: 304.46, y: 504.402))
                path3.addCurve(to: CGPoint(x: 224.113, y: 497.709),
                               control1: CGPoint(x: 273.127, y: 513.093),
                               control2: CGPoint(x: 246.381, y: 510.823))
                path3.addCurve(to: CGPoint(x: 151.206, y: 393.318),
                               control1: CGPoint(x: 186.853, y: 475.767),
                               control2: CGPoint(x: 159.42, y: 438.349))
                path3.addLine(to: CGPoint(x: 128.709, y: 259.44))
                path3.addCurve(to: CGPoint(x: 182.456, y: 156.522),
                               control1: CGPoint(x: 121.575, y: 216.981),
                               control2: CGPoint(x: 143.208, y: 174.252))
                path3.addCurve(to: CGPoint(x: 221.493, y: 148.119),
                               control1: CGPoint(x: 194.436, y: 151.119),
                               control2: CGPoint(x: 207.686, y: 148.119))
                path3.addCurve(to: CGPoint(x: 237.108, y: 149.388),
                               control1: CGPoint(x: 226.627, y: 148.119),
                               control2: CGPoint(x: 231.839, y: 148.523))
                path3.addCurve(to: CGPoint(x: 318.681, y: 155.984),
                               control1: CGPoint(x: 264.107, y: 153.791),
                               control2: CGPoint(x: 291.394, y: 155.984))
                path3.addCurve(to: CGPoint(x: 400.254, y: 149.388),
                               control1: CGPoint(x: 345.968, y: 155.984),
                               control2: CGPoint(x: 373.255, y: 153.792))
                path3.addCurve(to: CGPoint(x: 454.905, y: 156.522),
                               control1: CGPoint(x: 419.657, y: 146.215),
                               control2: CGPoint(x: 438.464, y: 149.1))
                path3.addCurve(to: CGPoint(x: 508.651, y: 259.44),
                               control1: CGPoint(x: 494.152, y: 174.252),
                               control2: CGPoint(x: 515.785, y: 216.98))
                path3.closeSubpath()
                ctx.addPath(path3)
                ctx.clip(using: .evenOdd)
                ctx.setAlpha(1)
                let color7 = CGColor(colorSpace: rgb, components: [0.996, 0.6, 0.627, 1])!
                let color8 = CGColor(colorSpace: rgb, components: [0.996, 0.392, 0.435, 1])!
                let color9 = CGColor(colorSpace: rgb, components: [0.894, 0.122, 0.176, 1])!
                var locations2: [CGFloat] = [0.0, 0.593, 1.0]
                let gradient2 = CGGradient(
                  colorsSpace: rgb,
                  colors: [color7, color8, color9] as CFArray,
                  locations: &locations2
                )!
                ctx.drawLinearGradient(gradient2,
                                   start: CGPoint(x: 149.353, y: 329.056),
                                   end: CGPoint(x: 490.041, y: 329.056),
                                   options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
                ctx.restoreGState()
                ctx.saveGState()
                let path4 = CGMutablePath()
                path4.move(to: CGPoint(x: 297.965, y: 444.898))
                path4.addLine(to: CGPoint(x: 131.982, y: 278.915))
                path4.addLine(to: CGPoint(x: 151.208, y: 393.317))
                path4.addCurve(to: CGPoint(x: 224.115, y: 497.709),
                               control1: CGPoint(x: 159.421, y: 438.349),
                               control2: CGPoint(x: 186.855, y: 475.766))
                path4.addCurve(to: CGPoint(x: 240.494, y: 505.178),
                               control1: CGPoint(x: 229.354, y: 500.794),
                               control2: CGPoint(x: 234.842, y: 503.271))
                path4.addCurve(to: CGPoint(x: 289.298, y: 483.987),
                               control1: CGPoint(x: 257.386, y: 501.026),
                               control2: CGPoint(x: 273.856, y: 494.097))
                path4.addCurve(to: CGPoint(x: 297.965, y: 444.898),
                               control1: CGPoint(x: 303.932, y: 474.406),
                               control2: CGPoint(x: 308.184, y: 455.118))
                path4.closeSubpath()
                ctx.addPath(path4)
                ctx.clip(using: .evenOdd)
                ctx.setAlpha(1)
                ctx.drawLinearGradient(gradient2,
                                   start: CGPoint(x: 67, y: 392.046),
                                   end: CGPoint(x: 435.067, y: 392.046),
                                   options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
                ctx.restoreGState()
                ctx.saveGState()
                let path5 = CGMutablePath()
                path5.move(to: CGPoint(x: 454.904, y: 156.522))
                path5.addCurve(to: CGPoint(x: 400.253, y: 149.388),
                               control1: CGPoint(x: 438.462, y: 149.099),
                               control2: CGPoint(x: 419.656, y: 146.215))
                path5.addCurve(to: CGPoint(x: 395.338, y: 150.138),
                               control1: CGPoint(x: 398.617, y: 149.655),
                               control2: CGPoint(x: 396.976, y: 149.888))
                path5.addCurve(to: CGPoint(x: 414.884, y: 156.522),
                               control1: CGPoint(x: 402.127, y: 151.565),
                               control2: CGPoint(x: 408.675, y: 153.718))
                path5.addCurve(to: CGPoint(x: 468.631, y: 259.44),
                               control1: CGPoint(x: 454.132, y: 174.252),
                               control2: CGPoint(x: 475.765, y: 216.981))
                path5.addLine(to: CGPoint(x: 446.132, y: 393.318))
                path5.addCurve(to: CGPoint(x: 373.225, y: 497.71),
                               control1: CGPoint(x: 437.919, y: 438.35),
                               control2: CGPoint(x: 410.485, y: 475.767))
                path5.addCurve(to: CGPoint(x: 346.721, y: 507.953),
                               control1: CGPoint(x: 364.905, y: 502.609),
                               control2: CGPoint(x: 355.961, y: 505.994))
                path5.addCurve(to: CGPoint(x: 413.245, y: 497.71),
                               control1: CGPoint(x: 369.447, y: 512.539),
                               control2: CGPoint(x: 393.166, y: 509.535))
                path5.addCurve(to: CGPoint(x: 486.152, y: 393.318),
                               control1: CGPoint(x: 450.505, y: 475.768),
                               control2: CGPoint(x: 477.938, y: 438.35))
                path5.addLine(to: CGPoint(x: 508.651, y: 259.44))
                path5.addCurve(to: CGPoint(x: 454.904, y: 156.522),
                               control1: CGPoint(x: 515.785, y: 216.98),
                               control2: CGPoint(x: 494.152, y: 174.252))
                path5.closeSubpath()
                ctx.addPath(path5)
                ctx.clip(using: .evenOdd)
                ctx.setAlpha(1)
                let color10 = CGColor(colorSpace: rgb, components: [0.769, 0.098, 0.149, 1])!
                var locations3: [CGFloat] = [0.0, 0.7043, 1.0]
                let gradient3 = CGGradient(
                  colorsSpace: rgb,
                  colors: [color8, color9, color10] as CFArray,
                  locations: &locations3
                )!
                ctx.drawLinearGradient(gradient3,
                                   start: CGPoint(x: 356.106, y: 329.055),
                                   end: CGPoint(x: 501.483, y: 329.055),
                                   options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
                ctx.restoreGState()
                ctx.saveGState()
                let path6 = CGMutablePath()
                path6.move(to: CGPoint(x: 272.954, y: 444.898))
                path6.addCurve(to: CGPoint(x: 264.286, y: 483.987),
                               control1: CGPoint(x: 283.174, y: 455.118),
                               control2: CGPoint(x: 278.922, y: 474.405))
                path6.addCurve(to: CGPoint(x: 38.136, y: 453.299),
                               control1: CGPoint(x: 190.38, y: 532.371),
                               control2: CGPoint(x: 92.977, y: 508.14))
                path6.addCurve(to: CGPoint(x: 47.108, y: 261.27),
                               control1: CGPoint(x: -17.528, y: 397.635),
                               control2: CGPoint(x: -10.309, y: 329.47))
                path6.addCurve(to: CGPoint(x: 83.823, y: 255.768),
                               control1: CGPoint(x: 57.431, y: 249.00902),
                               control2: CGPoint(x: 74.538, y: 246.483))
                path6.closeSubpath()
                ctx.addPath(path6)
                ctx.clip(using: .evenOdd)
                ctx.setAlpha(1)
                let color11 = CGColor(colorSpace: rgb, components: [1, 0.976, 0.875, 1])!
                let color12 = CGColor(colorSpace: rgb, components: [1, 0.882, 0.467, 1])!
                let color13 = CGColor(colorSpace: rgb, components: [0.996, 0.694, 0.216, 1])!
                var locations4: [CGFloat] = [0.0, 0.593, 1.0]
                let gradient4 = CGGradient(
                  colorsSpace: rgb,
                  colors: [color11, color12, color13] as CFArray,
                  locations: &locations4
                )!
                ctx.drawLinearGradient(gradient4,
                                   start: CGPoint(x: 8, y: 380.08),
                                   end: CGPoint(x: 260.642, y: 380.08),
                                   options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
                ctx.restoreGState()
                ctx.saveGState()
                let path7 = CGMutablePath()
                path7.move(to: CGPoint(x: 272.954, y: 444.898))
                path7.addLine(to: CGPoint(x: 83.824, y: 255.768))
                path7.addCurve(to: CGPoint(x: 56.33, y: 253.697),
                               control1: CGPoint(x: 76.964, y: 248.908),
                               control2: CGPoint(x: 65.838, y: 248.502))
                path7.addCurve(to: CGPoint(x: 58.813, y: 255.768),
                               control1: CGPoint(x: 57.205, y: 254.309),
                               control2: CGPoint(x: 58.038, y: 254.993))
                path7.addLine(to: CGPoint(x: 96.796, y: 293.751))
                path7.addCurve(to: CGPoint(x: 120.552, y: 362.629),
                               control1: CGPoint(x: 90.323, y: 313.54),
                               control2: CGPoint(x: 99.108, y: 341.186))
                path7.addCurve(to: CGPoint(x: 169.491, y: 388.119),
                               control1: CGPoint(x: 135.443, y: 377.52),
                               control2: CGPoint(x: 153.325, y: 386.307))
                path7.addCurve(to: CGPoint(x: 210.46, y: 407.414),
                               control1: CGPoint(x: 184.948, y: 389.851),
                               control2: CGPoint(x: 199.462, y: 396.416))
                path7.addLine(to: CGPoint(x: 247.944, y: 444.898))
                path7.addCurve(to: CGPoint(x: 239.276, y: 483.987),
                               control1: CGPoint(x: 258.164, y: 455.118),
                               control2: CGPoint(x: 253.912, y: 474.405))
                path7.addCurve(to: CGPoint(x: 162.484, y: 509.553),
                               control1: CGPoint(x: 215.39, y: 499.625),
                               control2: CGPoint(x: 189.049, y: 507.668))
                path7.addCurve(to: CGPoint(x: 264.287, y: 483.987),
                               control1: CGPoint(x: 197.283, y: 511.979),
                               control2: CGPoint(x: 232.904, y: 504.533))
                path7.addCurve(to: CGPoint(x: 272.954, y: 444.898),
                               control1: CGPoint(x: 278.921, y: 474.406),
                               control2: CGPoint(x: 283.173, y: 455.118))
                path7.closeSubpath()
                ctx.addPath(path7)
                ctx.clip(using: .evenOdd)
                ctx.setAlpha(1)
                var locations5: [CGFloat] = [0.0, 1.0]
                let gradient5 = CGGradient(
                  colorsSpace: rgb,
                  colors: [color12, color13] as CFArray,
                  locations: &locations5
                )!
                ctx.drawLinearGradient(gradient5,
                                   start: CGPoint(x: 62.712, y: 380.08),
                                   end: CGPoint(x: 264.266, y: 380.08),
                                   options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
                ctx.restoreGState()
                ctx.saveGState()
                let path8 = CGMutablePath()
                path8.move(to: CGPoint(x: 126.33, y: 347.857))
                path8.addCurve(to: CGPoint(x: 126.33, y: 328.922),
                               control1: CGPoint(x: 121.101, y: 342.628),
                               control2: CGPoint(x: 121.101, y: 334.151))
                path8.addCurve(to: CGPoint(x: 145.265, y: 328.922),
                               control1: CGPoint(x: 131.559, y: 323.693),
                               control2: CGPoint(x: 140.037, y: 323.693))
                path8.addCurve(to: CGPoint(x: 154.614, y: 357.206),
                               control1: CGPoint(x: 150.494, y: 334.151),
                               control2: CGPoint(x: 159.843, y: 351.977))
                path8.addCurve(to: CGPoint(x: 126.33, y: 347.857),
                               control1: CGPoint(x: 149.385, y: 362.435),
                               control2: CGPoint(x: 131.559, y: 353.086))
                path8.closeSubpath()
                ctx.addPath(path8)
                ctx.clip(using: .evenOdd)
                ctx.setAlpha(1)
                ctx.drawLinearGradient(gradient1,
                                   start: CGPoint(x: 112.416, y: 341.873),
                                   end: CGPoint(x: 164.335, y: 341.873),
                                   options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
                ctx.restoreGState()
                ctx.restoreGState()
              }
            }
            """
        )
    }
}

private extension CGTextRenderer {

    static func render(svgNamed name: String, in bundle: Bundle = .test) throws -> String {
        let url = try bundle.url(forResource: name)
        let data = try Data(contentsOf: url)
        return try render(data: data, options: .default)
    }

}
