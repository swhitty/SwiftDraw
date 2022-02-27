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
            extension UIImage {
              static func svgImage(size: CGSize = CGSize(width: 100.0, height: 100.0)) -> UIImage {
                let f = UIGraphicsImageRendererFormat.preferred()
                f.opaque = false
                let scale = CGSize(width: size.width / 100.0, height: size.height / 100.0)
                return UIGraphicsImageRenderer(size: size, format: f).image {
                  drawSVG(in: $0.cgContext, scale: scale)
                }
              }

              private static func drawSVG(in ctx: CGContext, scale: CGSize) {
                ctx.scaleBy(x: scale.width, y: scale.height)
                let rgb = CGColorSpaceCreateDeviceRGB()
                let color1 = CGColor(colorSpace: rgb, components: [0.0, 0.0, 0.0, 1.0])!
                ctx.setFillColor(color1)
                let path = CGMutablePath()
                path.addLines(between: [
                  CGPoint(x: 0.0, y: 0.0),
                  CGPoint(x: 100.0, y: 100.0)
                ])
                ctx.addPath(path)
                ctx.fillPath(using: .evenOdd)
                ctx.setLineCap(.butt)
                ctx.setLineJoin(.miter)
                ctx.setLineWidth(1.0)
                ctx.setMiterLimit(4.0)
                ctx.setStrokeColor(color1)
                ctx.addPath(path)
                ctx.strokePath()
                let path1 = CGMutablePath()
                path1.addLines(between: [
                  CGPoint(x: 100.0, y: 0.0),
                  CGPoint(x: 0.0, y: 100.0)
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
        print(code)
        XCTAssertEqual(
            code,
            """
            extension UIImage {
              static func svgImage(size: CGSize = CGSize(width: 512.0, height: 512.0)) -> UIImage {
                let f = UIGraphicsImageRendererFormat.preferred()
                f.opaque = false
                let scale = CGSize(width: size.width / 512.0, height: size.height / 512.0)
                return UIGraphicsImageRenderer(size: size, format: f).image {
                  drawSVG(in: $0.cgContext, scale: scale)
                }
              }

              private static func drawSVG(in ctx: CGContext, scale: CGSize) {
                ctx.scaleBy(x: scale.width, y: scale.height)
                ctx.scaleBy(x: 1.0039216, y: 1.0039216)
                ctx.saveGState()
                let path = CGMutablePath()
                path.move(to: CGPoint(x: 358.161, y: 40.149))
                path.addCurve(to: CGPoint(x: 318.014, y: 143.034),
                               control1: CGPoint(x: 331.605, y: 66.705),
                               control2: CGPoint(x: 318.557, y: 102.92799))
                path.addCurve(to: CGPoint(x: 344.613, y: 169.633),
                               control1: CGPoint(x: 317.814, y: 157.83),
                               control2: CGPoint(x: 329.81702, y: 169.833))
                path.addCurve(to: CGPoint(x: 447.49802, y: 129.486),
                               control1: CGPoint(x: 384.719, y: 169.09),
                               control2: CGPoint(x: 420.94202, y: 156.04199))
                path.addCurve(to: CGPoint(x: 487.64502, y: 26.60099),
                               control1: CGPoint(x: 474.05402, y: 102.92999),
                               control2: CGPoint(x: 487.10202, y: 66.70699))
                path.addCurve(to: CGPoint(x: 461.04602, y: 0.0019893646),
                               control1: CGPoint(x: 487.84503, y: 11.804991),
                               control2: CGPoint(x: 475.842, y: -0.19800949))
                path.addCurve(to: CGPoint(x: 358.161, y: 40.148987),
                               control1: CGPoint(x: 420.94003, y: 0.54498935),
                               control2: CGPoint(x: 384.717, y: 13.592989))
                path.closeSubpath()
                ctx.addPath(path)
                ctx.clip()
                ctx.setAlpha(1.0)
                let rgb = CGColorSpaceCreateDeviceRGB()
                let color1 = CGColor(colorSpace: rgb, components: [0.63529414, 0.9019608, 0.18039216, 1.0])!
                let color2 = CGColor(colorSpace: rgb, components: [0.03529412, 0.654902, 0.42745098, 1.0])!
                let color3 = CGColor(colorSpace: rgb, components: [0.003921569, 0.48235294, 0.30588236, 1.0])!
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
                               control2: CGPoint(x: 441.93198, y: 0.99899995))
                path1.addCurve(to: CGPoint(x: 447.624, y: 26.601),
                               control1: CGPoint(x: 441.678, y: 6.885),
                               control2: CGPoint(x: 447.767, y: 16.028))
                path1.addCurve(to: CGPoint(x: 407.477, y: 129.48601),
                               control1: CGPoint(x: 447.081, y: 66.707),
                               control2: CGPoint(x: 434.033, y: 102.93))
                path1.addCurve(to: CGPoint(x: 332.84497, y: 167.037),
                               control1: CGPoint(x: 387.32498, y: 149.638),
                               control2: CGPoint(x: 361.603, y: 162.00401))
                path1.addCurve(to: CGPoint(x: 344.61197, y: 169.633),
                               control1: CGPoint(x: 336.39496, y: 168.75),
                               control2: CGPoint(x: 340.38898, y: 169.69))
                path1.addCurve(to: CGPoint(x: 447.49698, y: 129.486),
                               control1: CGPoint(x: 384.71796, y: 169.09),
                               control2: CGPoint(x: 420.94098, y: 156.04199))
                path1.addCurve(to: CGPoint(x: 487.64398, y: 26.60099),
                               control1: CGPoint(x: 474.05298, y: 102.92999),
                               control2: CGPoint(x: 487.10098, y: 66.70699))
                path1.addCurve(to: CGPoint(x: 461.046, y: 0.0019893646),
                               control1: CGPoint(x: 487.84497, y: 11.804991),
                               control2: CGPoint(x: 475.84198, y: -0.19800949))
                path1.closeSubpath()
                ctx.addPath(path1)
                ctx.clip()
                ctx.setAlpha(1.0)
                var locations1: [CGFloat] = [0.0, 0.7542, 1.0]
                let gradient1 = CGGradient(
                  colorsSpace: rgb,
                  colors: [color1, color2, color3] as CFArray,
                  locations: &locations1
                )!
                ctx.drawLinearGradient(gradient1,
                                   start: CGPoint(x: 189.125, y: 84.818),
                                   end: CGPoint(x: 519.599, y: 84.818),
                                   options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
                ctx.restoreGState()
                ctx.saveGState()
                let path2 = CGMutablePath()
                path2.move(to: CGPoint(x: 318.012, y: 194.555))
                path2.addCurve(to: CGPoint(x: 300.512, y: 177.055),
                               control1: CGPoint(x: 308.347, y: 194.555),
                               control2: CGPoint(x: 300.512, y: 186.71999))
                path2.addLine(to: CGPoint(x: 300.512, y: 156.454))
                path2.addCurve(to: CGPoint(x: 254.983, y: 46.536995),
                               control1: CGPoint(x: 300.512, y: 114.933),
                               control2: CGPoint(x: 284.343, y: 75.896996))
                path2.addLine(to: CGPoint(x: 251.439, y: 42.991997))
                path2.addCurve(to: CGPoint(x: 251.44, y: 18.243998),
                               control1: CGPoint(x: 244.605, y: 36.157997),
                               control2: CGPoint(x: 244.60599, y: 25.076996))
                path2.addCurve(to: CGPoint(x: 276.189, y: 18.244997),
                               control1: CGPoint(x: 258.27402, y: 11.407997),
                               control2: CGPoint(x: 269.355, y: 11.410997))
                path2.addLine(to: CGPoint(x: 279.732, y: 21.788998))
                path2.addCurve(to: CGPoint(x: 321.01498, y: 83.573),
                               control1: CGPoint(x: 297.505, y: 39.562996),
                               control2: CGPoint(x: 311.396, y: 60.350998))
                path2.addCurve(to: CGPoint(x: 335.512, y: 156.454),
                               control1: CGPoint(x: 330.63498, y: 106.797),
                               control2: CGPoint(x: 335.512, y: 131.317))
                path2.addLine(to: CGPoint(x: 335.512, y: 177.055))
                path2.addCurve(to: CGPoint(x: 318.012, y: 194.555),
                               control1: CGPoint(x: 335.512, y: 186.71999),
                               control2: CGPoint(x: 327.677, y: 194.555))
                path2.closeSubpath()
                ctx.addPath(path2)
                ctx.clip()
                ctx.setAlpha(1.0)
                let color4 = CGColor(colorSpace: rgb, components: [0.654902, 0.60784316, 0.654902, 1.0])!
                let color5 = CGColor(colorSpace: rgb, components: [0.47843137, 0.42745098, 0.4745098, 1.0])!
                let color6 = CGColor(colorSpace: rgb, components: [0.40784314, 0.36862746, 0.40784314, 1.0])!
                var locations2: [CGFloat] = [0.0, 0.7487, 1.0]
                let gradient2 = CGGradient(
                  colorsSpace: rgb,
                  colors: [color4, color5, color6] as CFArray,
                  locations: &locations2
                )!
                ctx.drawLinearGradient(gradient2,
                                   start: CGPoint(x: 246.314, y: 103.837),
                                   end: CGPoint(x: 335.512, y: 103.837),
                                   options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
                ctx.restoreGState()
                ctx.saveGState()
                let path3 = CGMutablePath()
                path3.move(to: CGPoint(x: 508.651, y: 259.44))
                path3.addLine(to: CGPoint(x: 486.152, y: 393.318))
                path3.addCurve(to: CGPoint(x: 413.245, y: 497.70898),
                               control1: CGPoint(x: 477.939, y: 438.35),
                               control2: CGPoint(x: 450.505, y: 475.767))
                path3.addCurve(to: CGPoint(x: 339.328, y: 506.18597),
                               control1: CGPoint(x: 390.977, y: 510.823),
                               control2: CGPoint(x: 364.231, y: 513.09296))
                path3.addCurve(to: CGPoint(x: 318.67902, y: 503.42697),
                               control1: CGPoint(x: 332.898, y: 504.40298),
                               control2: CGPoint(x: 325.94, y: 503.42697))
                path3.addCurve(to: CGPoint(x: 298.03003, y: 506.18597),
                               control1: CGPoint(x: 311.419, y: 503.42697),
                               control2: CGPoint(x: 304.46002, y: 504.40198))
                path3.addCurve(to: CGPoint(x: 224.11304, y: 497.70898),
                               control1: CGPoint(x: 273.127, y: 513.09296),
                               control2: CGPoint(x: 246.38103, y: 510.82297))
                path3.addCurve(to: CGPoint(x: 151.20604, y: 393.318),
                               control1: CGPoint(x: 186.85304, y: 475.767),
                               control2: CGPoint(x: 159.42004, y: 438.349))
                path3.addLine(to: CGPoint(x: 128.70905, y: 259.44))
                path3.addCurve(to: CGPoint(x: 182.45605, y: 156.522),
                               control1: CGPoint(x: 121.57504, y: 216.981),
                               control2: CGPoint(x: 143.20804, y: 174.252))
                path3.addCurve(to: CGPoint(x: 221.49306, y: 148.119),
                               control1: CGPoint(x: 194.43605, y: 151.119),
                               control2: CGPoint(x: 207.68605, y: 148.119))
                path3.addCurve(to: CGPoint(x: 237.10806, y: 149.388),
                               control1: CGPoint(x: 226.62706, y: 148.119),
                               control2: CGPoint(x: 231.83905, y: 148.52301))
                path3.addCurve(to: CGPoint(x: 318.68106, y: 155.984),
                               control1: CGPoint(x: 264.10706, y: 153.791),
                               control2: CGPoint(x: 291.39407, y: 155.984))
                path3.addCurve(to: CGPoint(x: 400.25406, y: 149.388),
                               control1: CGPoint(x: 345.96805, y: 155.984),
                               control2: CGPoint(x: 373.25507, y: 153.79199))
                path3.addCurve(to: CGPoint(x: 454.90506, y: 156.522),
                               control1: CGPoint(x: 419.65704, y: 146.215),
                               control2: CGPoint(x: 438.46405, y: 149.1))
                path3.addCurve(to: CGPoint(x: 508.65106, y: 259.44),
                               control1: CGPoint(x: 494.15207, y: 174.252),
                               control2: CGPoint(x: 515.78503, y: 216.98001))
                path3.closeSubpath()
                ctx.addPath(path3)
                ctx.clip()
                ctx.setAlpha(1.0)
                let color7 = CGColor(colorSpace: rgb, components: [0.99607843, 0.6, 0.627451, 1.0])!
                let color8 = CGColor(colorSpace: rgb, components: [0.99607843, 0.39215687, 0.43529412, 1.0])!
                let color9 = CGColor(colorSpace: rgb, components: [0.89411765, 0.12156863, 0.1764706, 1.0])!
                var locations3: [CGFloat] = [0.0, 0.593, 1.0]
                let gradient3 = CGGradient(
                  colorsSpace: rgb,
                  colors: [color7, color8, color9] as CFArray,
                  locations: &locations3
                )!
                ctx.drawLinearGradient(gradient3,
                                   start: CGPoint(x: 149.353, y: 329.056),
                                   end: CGPoint(x: 490.041, y: 329.056),
                                   options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
                ctx.restoreGState()
                ctx.saveGState()
                let path4 = CGMutablePath()
                path4.move(to: CGPoint(x: 297.965, y: 444.898))
                path4.addLine(to: CGPoint(x: 131.982, y: 278.915))
                path4.addLine(to: CGPoint(x: 151.208, y: 393.31702))
                path4.addCurve(to: CGPoint(x: 224.11499, y: 497.709),
                               control1: CGPoint(x: 159.42099, y: 438.34903),
                               control2: CGPoint(x: 186.855, y: 475.76602))
                path4.addCurve(to: CGPoint(x: 240.49399, y: 505.178),
                               control1: CGPoint(x: 229.35399, y: 500.794),
                               control2: CGPoint(x: 234.842, y: 503.27103))
                path4.addCurve(to: CGPoint(x: 289.29797, y: 483.987),
                               control1: CGPoint(x: 257.386, y: 501.026),
                               control2: CGPoint(x: 273.856, y: 494.09702))
                path4.addCurve(to: CGPoint(x: 297.96497, y: 444.898),
                               control1: CGPoint(x: 303.93198, y: 474.406),
                               control2: CGPoint(x: 308.18396, y: 455.118))
                path4.closeSubpath()
                ctx.addPath(path4)
                ctx.clip()
                ctx.setAlpha(1.0)
                var locations4: [CGFloat] = [0.0, 0.593, 1.0]
                let gradient4 = CGGradient(
                  colorsSpace: rgb,
                  colors: [color7, color8, color9] as CFArray,
                  locations: &locations4
                )!
                ctx.drawLinearGradient(gradient4,
                                   start: CGPoint(x: 67.0, y: 392.046),
                                   end: CGPoint(x: 435.067, y: 392.046),
                                   options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
                ctx.restoreGState()
                ctx.saveGState()
                let path5 = CGMutablePath()
                path5.move(to: CGPoint(x: 454.904, y: 156.522))
                path5.addCurve(to: CGPoint(x: 400.253, y: 149.388),
                               control1: CGPoint(x: 438.462, y: 149.099),
                               control2: CGPoint(x: 419.656, y: 146.215))
                path5.addCurve(to: CGPoint(x: 395.33798, y: 150.138),
                               control1: CGPoint(x: 398.617, y: 149.655),
                               control2: CGPoint(x: 396.97598, y: 149.888))
                path5.addCurve(to: CGPoint(x: 414.88397, y: 156.522),
                               control1: CGPoint(x: 402.12698, y: 151.565),
                               control2: CGPoint(x: 408.675, y: 153.718))
                path5.addCurve(to: CGPoint(x: 468.63098, y: 259.44),
                               control1: CGPoint(x: 454.13196, y: 174.252),
                               control2: CGPoint(x: 475.76498, y: 216.981))
                path5.addLine(to: CGPoint(x: 446.132, y: 393.318))
                path5.addCurve(to: CGPoint(x: 373.22498, y: 497.71),
                               control1: CGPoint(x: 437.91898, y: 438.35),
                               control2: CGPoint(x: 410.485, y: 475.767))
                path5.addCurve(to: CGPoint(x: 346.72098, y: 507.953),
                               control1: CGPoint(x: 364.90497, y: 502.60898),
                               control2: CGPoint(x: 355.96097, y: 505.994))
                path5.addCurve(to: CGPoint(x: 413.245, y: 497.71),
                               control1: CGPoint(x: 369.447, y: 512.539),
                               control2: CGPoint(x: 393.166, y: 509.535))
                path5.addCurve(to: CGPoint(x: 486.15198, y: 393.318),
                               control1: CGPoint(x: 450.505, y: 475.768),
                               control2: CGPoint(x: 477.938, y: 438.34998))
                path5.addLine(to: CGPoint(x: 508.65097, y: 259.44))
                path5.addCurve(to: CGPoint(x: 454.90396, y: 156.522),
                               control1: CGPoint(x: 515.785, y: 216.98001),
                               control2: CGPoint(x: 494.15198, y: 174.252))
                path5.closeSubpath()
                ctx.addPath(path5)
                ctx.clip()
                ctx.setAlpha(1.0)
                let color10 = CGColor(colorSpace: rgb, components: [0.76862746, 0.09803922, 0.14901961, 1.0])!
                var locations5: [CGFloat] = [0.0, 0.7043, 1.0]
                let gradient5 = CGGradient(
                  colorsSpace: rgb,
                  colors: [color8, color9, color10] as CFArray,
                  locations: &locations5
                )!
                ctx.drawLinearGradient(gradient5,
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
                path6.addCurve(to: CGPoint(x: 38.136017, y: 453.299),
                               control1: CGPoint(x: 190.38, y: 532.371),
                               control2: CGPoint(x: 92.977005, y: 508.14))
                path6.addCurve(to: CGPoint(x: 47.108017, y: 261.27002),
                               control1: CGPoint(x: -17.527985, y: 397.635),
                               control2: CGPoint(x: -10.308983, y: 329.47))
                path6.addCurve(to: CGPoint(x: 83.82301, y: 255.76802),
                               control1: CGPoint(x: 57.431015, y: 249.00902),
                               control2: CGPoint(x: 74.53802, y: 246.48302))
                path6.closeSubpath()
                ctx.addPath(path6)
                ctx.clip()
                ctx.setAlpha(1.0)
                let color11 = CGColor(colorSpace: rgb, components: [1.0, 0.9764706, 0.8745098, 1.0])!
                let color12 = CGColor(colorSpace: rgb, components: [1.0, 0.88235295, 0.46666667, 1.0])!
                let color13 = CGColor(colorSpace: rgb, components: [0.99607843, 0.69411767, 0.21568628, 1.0])!
                var locations6: [CGFloat] = [0.0, 0.593, 1.0]
                let gradient6 = CGGradient(
                  colorsSpace: rgb,
                  colors: [color11, color12, color13] as CFArray,
                  locations: &locations6
                )!
                ctx.drawLinearGradient(gradient6,
                                   start: CGPoint(x: 8.0, y: 380.08),
                                   end: CGPoint(x: 260.642, y: 380.08),
                                   options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
                ctx.restoreGState()
                ctx.saveGState()
                let path7 = CGMutablePath()
                path7.move(to: CGPoint(x: 272.954, y: 444.898))
                path7.addLine(to: CGPoint(x: 83.824005, y: 255.768))
                path7.addCurve(to: CGPoint(x: 56.330006, y: 253.697),
                               control1: CGPoint(x: 76.964005, y: 248.908),
                               control2: CGPoint(x: 65.838005, y: 248.502))
                path7.addCurve(to: CGPoint(x: 58.813007, y: 255.768),
                               control1: CGPoint(x: 57.205006, y: 254.309),
                               control2: CGPoint(x: 58.038006, y: 254.99301))
                path7.addLine(to: CGPoint(x: 96.796005, y: 293.751))
                path7.addCurve(to: CGPoint(x: 120.552, y: 362.629),
                               control1: CGPoint(x: 90.323006, y: 313.54),
                               control2: CGPoint(x: 99.108, y: 341.186))
                path7.addCurve(to: CGPoint(x: 169.491, y: 388.119),
                               control1: CGPoint(x: 135.44301, y: 377.52),
                               control2: CGPoint(x: 153.325, y: 386.307))
                path7.addCurve(to: CGPoint(x: 210.45999, y: 407.414),
                               control1: CGPoint(x: 184.948, y: 389.85098),
                               control2: CGPoint(x: 199.462, y: 396.416))
                path7.addLine(to: CGPoint(x: 247.944, y: 444.898))
                path7.addCurve(to: CGPoint(x: 239.276, y: 483.987),
                               control1: CGPoint(x: 258.164, y: 455.118),
                               control2: CGPoint(x: 253.912, y: 474.405))
                path7.addCurve(to: CGPoint(x: 162.48401, y: 509.553),
                               control1: CGPoint(x: 215.39, y: 499.625),
                               control2: CGPoint(x: 189.049, y: 507.668))
                path7.addCurve(to: CGPoint(x: 264.28702, y: 483.987),
                               control1: CGPoint(x: 197.283, y: 511.979),
                               control2: CGPoint(x: 232.904, y: 504.53302))
                path7.addCurve(to: CGPoint(x: 272.954, y: 444.898),
                               control1: CGPoint(x: 278.92102, y: 474.406),
                               control2: CGPoint(x: 283.173, y: 455.118))
                path7.closeSubpath()
                ctx.addPath(path7)
                ctx.clip()
                ctx.setAlpha(1.0)
                var locations7: [CGFloat] = [0.0, 1.0]
                let gradient7 = CGGradient(
                  colorsSpace: rgb,
                  colors: [color12, color13] as CFArray,
                  locations: &locations7
                )!
                ctx.drawLinearGradient(gradient7,
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
                               control2: CGPoint(x: 131.55899, y: 353.086))
                path8.closeSubpath()
                ctx.addPath(path8)
                ctx.clip()
                ctx.setAlpha(1.0)
                var locations8: [CGFloat] = [0.0, 0.7487, 1.0]
                let gradient8 = CGGradient(
                  colorsSpace: rgb,
                  colors: [color4, color5, color6] as CFArray,
                  locations: &locations8
                )!
                ctx.drawLinearGradient(gradient8,
                                   start: CGPoint(x: 112.416, y: 341.873),
                                   end: CGPoint(x: 164.335, y: 341.873),
                                   options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
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
        return try render(data: data)
    }

}
