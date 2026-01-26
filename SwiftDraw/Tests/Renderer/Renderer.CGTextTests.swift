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
                ctx.fillPath()
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
                ctx.fillPath()
                ctx.addPath(path1)
                ctx.strokePath()
              }
            }
            """
        )
    }

    func testSwiftUICode() throws {
        let code = try CGTextRenderer.render(svgNamed: "lines.svg", api: .swiftUI)
        XCTAssertEqual(
            code,
            """
            import SwiftUI

            struct ImageView: View {

              var body: some View {
                if isResizable {
                  canvas
                    .frame(idealWidth: 100.0, idealHeight: 100.0)
                } else {
                  canvas
                    .frame(width: 100.0, height: 100.0)
                }
              }

              private var isResizable = false

              func resizable() -> Self {
                 var copy = self 
                 copy.isResizable = true
                 return copy
              }

              var canvas: some View {
                Canvas(
                  opaque: false,
                  colorMode: .linear,
                  rendersAsynchronously: false
                ) { context, size in
                  let scale = CGSize(width: size.width / 100.0, height: size.height / 100.0)                                  
                  context.withCGContext { ctx in
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
                    ctx.fillPath()
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
                    ctx.fillPath()
                    ctx.addPath(path1)
                    ctx.strokePath()    
                  }
                }
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
                ctx.scaleBy(x: 1, y: 1)
                ctx.saveGState()
                let path = CGMutablePath()
                path.move(to: CGPoint(x: 358.16, y: 40.15))
                path.addCurve(to: CGPoint(x: 318.01, y: 143.03),
                               control1: CGPoint(x: 331.61, y: 66.71),
                               control2: CGPoint(x: 318.56, y: 102.93))
                path.addCurve(to: CGPoint(x: 344.61, y: 169.63),
                               control1: CGPoint(x: 317.81, y: 157.83),
                               control2: CGPoint(x: 329.82, y: 169.83))
                path.addCurve(to: CGPoint(x: 447.5, y: 129.49),
                               control1: CGPoint(x: 384.72, y: 169.09),
                               control2: CGPoint(x: 420.94, y: 156.04))
                path.addCurve(to: CGPoint(x: 487.65, y: 26.6),
                               control1: CGPoint(x: 474.05, y: 102.93),
                               control2: CGPoint(x: 487.1, y: 66.71))
                path.addCurve(to: CGPoint(x: 461.05, y: 0),
                               control1: CGPoint(x: 487.85, y: 11.8),
                               control2: CGPoint(x: 475.84, y: -0.2))
                path.addCurve(to: CGPoint(x: 358.16, y: 40.15),
                               control1: CGPoint(x: 420.94, y: 0.54),
                               control2: CGPoint(x: 384.72, y: 13.59))
                path.closeSubpath()
                ctx.addPath(path)
                ctx.clip()
                ctx.setAlpha(1)
                let rgb = CGColorSpaceCreateDeviceRGB()
                let color1 = CGColor(colorSpace: rgb, components: [0.635, 0.902, 0.18, 1])!
                let color2 = CGColor(colorSpace: rgb, components: [0.035, 0.655, 0.427, 1])!
                let color3 = CGColor(colorSpace: rgb, components: [0.004, 0.482, 0.306, 1])!
                var locations: [CGFloat] = [0.0, 0.7542, 1.0]
                let gradient = CGGradient(
                  colorsSpace: rgb,
                  colors: [color1, color2, color3] as CFArray,
                  locations: &locations
                )!
                ctx.drawLinearGradient(gradient,
                                   start: CGPoint(x: 316.6, y: 84.82),
                                   end: CGPoint(x: 490.77, y: 84.82),
                                   options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
                ctx.restoreGState()
                ctx.saveGState()
                let path1 = CGMutablePath()
                path1.move(to: CGPoint(x: 461.05, y: 0))
                path1.addCurve(to: CGPoint(x: 432.79, y: 2.6),
                               control1: CGPoint(x: 451.38, y: 0.13),
                               control2: CGPoint(x: 441.93, y: 1))
                path1.addCurve(to: CGPoint(x: 447.62, y: 26.6),
                               control1: CGPoint(x: 441.68, y: 6.89),
                               control2: CGPoint(x: 447.77, y: 16.03))
                path1.addCurve(to: CGPoint(x: 407.48, y: 129.49),
                               control1: CGPoint(x: 447.08, y: 66.71),
                               control2: CGPoint(x: 434.03, y: 102.93))
                path1.addCurve(to: CGPoint(x: 332.84, y: 167.04),
                               control1: CGPoint(x: 387.32, y: 149.64),
                               control2: CGPoint(x: 361.6, y: 162))
                path1.addCurve(to: CGPoint(x: 344.61, y: 169.63),
                               control1: CGPoint(x: 336.39, y: 168.75),
                               control2: CGPoint(x: 340.39, y: 169.69))
                path1.addCurve(to: CGPoint(x: 447.5, y: 129.49),
                               control1: CGPoint(x: 384.72, y: 169.09),
                               control2: CGPoint(x: 420.94, y: 156.04))
                path1.addCurve(to: CGPoint(x: 487.64, y: 26.6),
                               control1: CGPoint(x: 474.05, y: 102.93),
                               control2: CGPoint(x: 487.1, y: 66.71))
                path1.addCurve(to: CGPoint(x: 461.05, y: 0),
                               control1: CGPoint(x: 487.84, y: 11.8),
                               control2: CGPoint(x: 475.84, y: -0.2))
                path1.closeSubpath()
                ctx.addPath(path1)
                ctx.clip()
                ctx.setAlpha(1)
                ctx.drawLinearGradient(gradient,
                                   start: CGPoint(x: 189.12, y: 84.82),
                                   end: CGPoint(x: 519.6, y: 84.82),
                                   options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
                ctx.restoreGState()
                ctx.saveGState()
                let path2 = CGMutablePath()
                path2.move(to: CGPoint(x: 318.01, y: 194.55))
                path2.addCurve(to: CGPoint(x: 300.51, y: 177.05),
                               control1: CGPoint(x: 308.35, y: 194.55),
                               control2: CGPoint(x: 300.51, y: 186.72))
                path2.addLine(to: CGPoint(x: 300.51, y: 156.45))
                path2.addCurve(to: CGPoint(x: 254.98, y: 46.54),
                               control1: CGPoint(x: 300.51, y: 114.93),
                               control2: CGPoint(x: 284.34, y: 75.9))
                path2.addLine(to: CGPoint(x: 251.44, y: 42.99))
                path2.addCurve(to: CGPoint(x: 251.44, y: 18.24),
                               control1: CGPoint(x: 244.6, y: 36.16),
                               control2: CGPoint(x: 244.61, y: 25.08))
                path2.addCurve(to: CGPoint(x: 276.19, y: 18.24),
                               control1: CGPoint(x: 258.27, y: 11.41),
                               control2: CGPoint(x: 269.36, y: 11.41))
                path2.addLine(to: CGPoint(x: 279.73, y: 21.79))
                path2.addCurve(to: CGPoint(x: 321.01, y: 83.57),
                               control1: CGPoint(x: 297.51, y: 39.56),
                               control2: CGPoint(x: 311.4, y: 60.35))
                path2.addCurve(to: CGPoint(x: 335.51, y: 156.45),
                               control1: CGPoint(x: 330.63, y: 106.8),
                               control2: CGPoint(x: 335.51, y: 131.32))
                path2.addLine(to: CGPoint(x: 335.51, y: 177.05))
                path2.addCurve(to: CGPoint(x: 318.01, y: 194.55),
                               control1: CGPoint(x: 335.51, y: 186.72),
                               control2: CGPoint(x: 327.68, y: 194.55))
                path2.closeSubpath()
                ctx.addPath(path2)
                ctx.clip()
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
                                   start: CGPoint(x: 246.31, y: 103.84),
                                   end: CGPoint(x: 335.51, y: 103.84),
                                   options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
                ctx.restoreGState()
                ctx.saveGState()
                let path3 = CGMutablePath()
                path3.move(to: CGPoint(x: 508.65, y: 259.44))
                path3.addLine(to: CGPoint(x: 486.15, y: 393.32))
                path3.addCurve(to: CGPoint(x: 413.24, y: 497.71),
                               control1: CGPoint(x: 477.94, y: 438.35),
                               control2: CGPoint(x: 450.51, y: 475.77))
                path3.addCurve(to: CGPoint(x: 339.33, y: 506.19),
                               control1: CGPoint(x: 390.98, y: 510.82),
                               control2: CGPoint(x: 364.23, y: 513.09))
                path3.addCurve(to: CGPoint(x: 318.68, y: 503.43),
                               control1: CGPoint(x: 332.9, y: 504.4),
                               control2: CGPoint(x: 325.94, y: 503.43))
                path3.addCurve(to: CGPoint(x: 298.03, y: 506.19),
                               control1: CGPoint(x: 311.42, y: 503.43),
                               control2: CGPoint(x: 304.46, y: 504.4))
                path3.addCurve(to: CGPoint(x: 224.11, y: 497.71),
                               control1: CGPoint(x: 273.13, y: 513.09),
                               control2: CGPoint(x: 246.38, y: 510.82))
                path3.addCurve(to: CGPoint(x: 151.21, y: 393.32),
                               control1: CGPoint(x: 186.85, y: 475.77),
                               control2: CGPoint(x: 159.42, y: 438.35))
                path3.addLine(to: CGPoint(x: 128.71, y: 259.44))
                path3.addCurve(to: CGPoint(x: 182.46, y: 156.52),
                               control1: CGPoint(x: 121.58, y: 216.98),
                               control2: CGPoint(x: 143.21, y: 174.25))
                path3.addCurve(to: CGPoint(x: 221.49, y: 148.12),
                               control1: CGPoint(x: 194.44, y: 151.12),
                               control2: CGPoint(x: 207.69, y: 148.12))
                path3.addCurve(to: CGPoint(x: 237.11, y: 149.39),
                               control1: CGPoint(x: 226.63, y: 148.12),
                               control2: CGPoint(x: 231.84, y: 148.52))
                path3.addCurve(to: CGPoint(x: 318.68, y: 155.98),
                               control1: CGPoint(x: 264.11, y: 153.79),
                               control2: CGPoint(x: 291.39, y: 155.98))
                path3.addCurve(to: CGPoint(x: 400.25, y: 149.39),
                               control1: CGPoint(x: 345.97, y: 155.98),
                               control2: CGPoint(x: 373.26, y: 153.79))
                path3.addCurve(to: CGPoint(x: 454.91, y: 156.52),
                               control1: CGPoint(x: 419.66, y: 146.21),
                               control2: CGPoint(x: 438.46, y: 149.1))
                path3.addCurve(to: CGPoint(x: 508.65, y: 259.44),
                               control1: CGPoint(x: 494.15, y: 174.25),
                               control2: CGPoint(x: 515.79, y: 216.98))
                path3.closeSubpath()
                ctx.addPath(path3)
                ctx.clip()
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
                                   start: CGPoint(x: 149.35, y: 329.06),
                                   end: CGPoint(x: 490.04, y: 329.06),
                                   options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
                ctx.restoreGState()
                ctx.saveGState()
                let path4 = CGMutablePath()
                path4.move(to: CGPoint(x: 297.96, y: 444.9))
                path4.addLine(to: CGPoint(x: 131.98, y: 278.92))
                path4.addLine(to: CGPoint(x: 151.21, y: 393.32))
                path4.addCurve(to: CGPoint(x: 224.11, y: 497.71),
                               control1: CGPoint(x: 159.42, y: 438.35),
                               control2: CGPoint(x: 186.85, y: 475.77))
                path4.addCurve(to: CGPoint(x: 240.49, y: 505.18),
                               control1: CGPoint(x: 229.35, y: 500.79),
                               control2: CGPoint(x: 234.84, y: 503.27))
                path4.addCurve(to: CGPoint(x: 289.3, y: 483.99),
                               control1: CGPoint(x: 257.39, y: 501.03),
                               control2: CGPoint(x: 273.86, y: 494.1))
                path4.addCurve(to: CGPoint(x: 297.96, y: 444.9),
                               control1: CGPoint(x: 303.93, y: 474.41),
                               control2: CGPoint(x: 308.18, y: 455.12))
                path4.closeSubpath()
                ctx.addPath(path4)
                ctx.clip()
                ctx.setAlpha(1)
                ctx.drawLinearGradient(gradient2,
                                   start: CGPoint(x: 67, y: 392.05),
                                   end: CGPoint(x: 435.07, y: 392.05),
                                   options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
                ctx.restoreGState()
                ctx.saveGState()
                let path5 = CGMutablePath()
                path5.move(to: CGPoint(x: 454.9, y: 156.52))
                path5.addCurve(to: CGPoint(x: 400.25, y: 149.39),
                               control1: CGPoint(x: 438.46, y: 149.1),
                               control2: CGPoint(x: 419.66, y: 146.21))
                path5.addCurve(to: CGPoint(x: 395.34, y: 150.14),
                               control1: CGPoint(x: 398.62, y: 149.65),
                               control2: CGPoint(x: 396.98, y: 149.89))
                path5.addCurve(to: CGPoint(x: 414.88, y: 156.52),
                               control1: CGPoint(x: 402.13, y: 151.57),
                               control2: CGPoint(x: 408.67, y: 153.72))
                path5.addCurve(to: CGPoint(x: 468.63, y: 259.44),
                               control1: CGPoint(x: 454.13, y: 174.25),
                               control2: CGPoint(x: 475.76, y: 216.98))
                path5.addLine(to: CGPoint(x: 446.13, y: 393.32))
                path5.addCurve(to: CGPoint(x: 373.22, y: 497.71),
                               control1: CGPoint(x: 437.92, y: 438.35),
                               control2: CGPoint(x: 410.48, y: 475.77))
                path5.addCurve(to: CGPoint(x: 346.72, y: 507.95),
                               control1: CGPoint(x: 364.9, y: 502.61),
                               control2: CGPoint(x: 355.96, y: 505.99))
                path5.addCurve(to: CGPoint(x: 413.24, y: 497.71),
                               control1: CGPoint(x: 369.45, y: 512.54),
                               control2: CGPoint(x: 393.17, y: 509.54))
                path5.addCurve(to: CGPoint(x: 486.15, y: 393.32),
                               control1: CGPoint(x: 450.51, y: 475.77),
                               control2: CGPoint(x: 477.94, y: 438.35))
                path5.addLine(to: CGPoint(x: 508.65, y: 259.44))
                path5.addCurve(to: CGPoint(x: 454.9, y: 156.52),
                               control1: CGPoint(x: 515.78, y: 216.98),
                               control2: CGPoint(x: 494.15, y: 174.25))
                path5.closeSubpath()
                ctx.addPath(path5)
                ctx.clip()
                ctx.setAlpha(1)
                let color10 = CGColor(colorSpace: rgb, components: [0.769, 0.098, 0.149, 1])!
                var locations3: [CGFloat] = [0.0, 0.7043, 1.0]
                let gradient3 = CGGradient(
                  colorsSpace: rgb,
                  colors: [color8, color9, color10] as CFArray,
                  locations: &locations3
                )!
                ctx.drawLinearGradient(gradient3,
                                   start: CGPoint(x: 356.11, y: 329.05),
                                   end: CGPoint(x: 501.48, y: 329.05),
                                   options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
                ctx.restoreGState()
                ctx.saveGState()
                let path6 = CGMutablePath()
                path6.move(to: CGPoint(x: 272.95, y: 444.9))
                path6.addCurve(to: CGPoint(x: 264.29, y: 483.99),
                               control1: CGPoint(x: 283.17, y: 455.12),
                               control2: CGPoint(x: 278.92, y: 474.4))
                path6.addCurve(to: CGPoint(x: 38.14, y: 453.3),
                               control1: CGPoint(x: 190.38, y: 532.37),
                               control2: CGPoint(x: 92.98, y: 508.14))
                path6.addCurve(to: CGPoint(x: 47.11, y: 261.27),
                               control1: CGPoint(x: -17.53, y: 397.64),
                               control2: CGPoint(x: -10.31, y: 329.47))
                path6.addCurve(to: CGPoint(x: 83.82, y: 255.77),
                               control1: CGPoint(x: 57.43, y: 249.01),
                               control2: CGPoint(x: 74.54, y: 246.48))
                path6.closeSubpath()
                ctx.addPath(path6)
                ctx.clip()
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
                                   end: CGPoint(x: 260.64, y: 380.08),
                                   options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
                ctx.restoreGState()
                ctx.saveGState()
                let path7 = CGMutablePath()
                path7.move(to: CGPoint(x: 272.95, y: 444.9))
                path7.addLine(to: CGPoint(x: 83.82, y: 255.77))
                path7.addCurve(to: CGPoint(x: 56.33, y: 253.7),
                               control1: CGPoint(x: 76.96, y: 248.91),
                               control2: CGPoint(x: 65.84, y: 248.5))
                path7.addCurve(to: CGPoint(x: 58.81, y: 255.77),
                               control1: CGPoint(x: 57.21, y: 254.31),
                               control2: CGPoint(x: 58.04, y: 254.99))
                path7.addLine(to: CGPoint(x: 96.8, y: 293.75))
                path7.addCurve(to: CGPoint(x: 120.55, y: 362.63),
                               control1: CGPoint(x: 90.32, y: 313.54),
                               control2: CGPoint(x: 99.11, y: 341.19))
                path7.addCurve(to: CGPoint(x: 169.49, y: 388.12),
                               control1: CGPoint(x: 135.44, y: 377.52),
                               control2: CGPoint(x: 153.32, y: 386.31))
                path7.addCurve(to: CGPoint(x: 210.46, y: 407.41),
                               control1: CGPoint(x: 184.95, y: 389.85),
                               control2: CGPoint(x: 199.46, y: 396.42))
                path7.addLine(to: CGPoint(x: 247.94, y: 444.9))
                path7.addCurve(to: CGPoint(x: 239.28, y: 483.99),
                               control1: CGPoint(x: 258.16, y: 455.12),
                               control2: CGPoint(x: 253.91, y: 474.4))
                path7.addCurve(to: CGPoint(x: 162.48, y: 509.55),
                               control1: CGPoint(x: 215.39, y: 499.62),
                               control2: CGPoint(x: 189.05, y: 507.67))
                path7.addCurve(to: CGPoint(x: 264.29, y: 483.99),
                               control1: CGPoint(x: 197.28, y: 511.98),
                               control2: CGPoint(x: 232.9, y: 504.53))
                path7.addCurve(to: CGPoint(x: 272.95, y: 444.9),
                               control1: CGPoint(x: 278.92, y: 474.41),
                               control2: CGPoint(x: 283.17, y: 455.12))
                path7.closeSubpath()
                ctx.addPath(path7)
                ctx.clip()
                ctx.setAlpha(1)
                var locations5: [CGFloat] = [0.0, 1.0]
                let gradient5 = CGGradient(
                  colorsSpace: rgb,
                  colors: [color12, color13] as CFArray,
                  locations: &locations5
                )!
                ctx.drawLinearGradient(gradient5,
                                   start: CGPoint(x: 62.71, y: 380.08),
                                   end: CGPoint(x: 264.27, y: 380.08),
                                   options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
                ctx.restoreGState()
                ctx.saveGState()
                let path8 = CGMutablePath()
                path8.move(to: CGPoint(x: 126.33, y: 347.86))
                path8.addCurve(to: CGPoint(x: 126.33, y: 328.92),
                               control1: CGPoint(x: 121.1, y: 342.63),
                               control2: CGPoint(x: 121.1, y: 334.15))
                path8.addCurve(to: CGPoint(x: 145.26, y: 328.92),
                               control1: CGPoint(x: 131.56, y: 323.69),
                               control2: CGPoint(x: 140.04, y: 323.69))
                path8.addCurve(to: CGPoint(x: 154.61, y: 357.21),
                               control1: CGPoint(x: 150.49, y: 334.15),
                               control2: CGPoint(x: 159.84, y: 351.98))
                path8.addCurve(to: CGPoint(x: 126.33, y: 347.86),
                               control1: CGPoint(x: 149.38, y: 362.43),
                               control2: CGPoint(x: 131.56, y: 353.09))
                path8.closeSubpath()
                ctx.addPath(path8)
                ctx.clip()
                ctx.setAlpha(1)
                ctx.drawLinearGradient(gradient1,
                                   start: CGPoint(x: 112.42, y: 341.87),
                                   end: CGPoint(x: 164.34, y: 341.87),
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

    static func render(svgNamed name: String, in bundle: Bundle = .test, api: API = .uiKit, precision: Int = 2) throws -> String {
        let url = try bundle.url(forResource: name)
        let data = try Data(contentsOf: url)
        return try render(data: data, options: .default, api: api, precision: precision)
    }

}
