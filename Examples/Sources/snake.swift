import SwiftUI

struct SnakeView: View {

  var body: some View {
    if isResizable {
      canvas
        .frame(idealWidth: 256.0, idealHeight: 256.0)
    } else {
      canvas
        .frame(width: 256.0, height: 256.0)
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
      let scale = CGSize(width: size.width / 256.0, height: size.height / 256.0)
      let svgUnitScale = 8 * min(scale.width, scale.height)
      context.withCGContext { ctx in
        ctx.scaleBy(x: scale.width, y: scale.height)
        ctx.saveGState()
        ctx.scaleBy(x: 8, y: 8)
        ctx.saveGState()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 19.56, y: 6))
        path.addCurve(to: CGPoint(x: 15.92, y: 4.3),
                       control1: CGPoint(x: 18.16, y: 6),
                       control2: CGPoint(x: 16.81, y: 5.39))
        path.addCurve(to: CGPoint(x: 15.83, y: 4.19),
                       control1: CGPoint(x: 15.89, y: 4.26),
                       control2: CGPoint(x: 15.86, y: 4.23))
        path.addCurve(to: CGPoint(x: 15.12, y: 4.11),
                       control1: CGPoint(x: 15.66, y: 3.97),
                       control2: CGPoint(x: 15.34, y: 3.93))
        path.addCurve(to: CGPoint(x: 15.05, y: 4.82),
                       control1: CGPoint(x: 14.91, y: 4.28),
                       control2: CGPoint(x: 14.88, y: 4.6))
        path.addCurve(to: CGPoint(x: 16.26, y: 6),
                       control1: CGPoint(x: 15.4, y: 5.27),
                       control2: CGPoint(x: 15.81, y: 5.67))
        path.addLine(to: CGPoint(x: 15.45, y: 6))
        path.addCurve(to: CGPoint(x: 14.93, y: 6.47),
                       control1: CGPoint(x: 15.18, y: 6),
                       control2: CGPoint(x: 14.95, y: 6.2))
        path.addCurve(to: CGPoint(x: 15.44, y: 7),
                       control1: CGPoint(x: 14.92, y: 6.76),
                       control2: CGPoint(x: 15.15, y: 7))
        path.addLine(to: CGPoint(x: 21.44, y: 7))
        path.addLine(to: CGPoint(x: 21.44, y: 6))
        path.addLine(to: CGPoint(x: 19.56, y: 6))
        path.closeSubpath()
        ctx.addPath(path)
        ctx.clip()
        ctx.setAlpha(1)
        let rgb = CGColorSpaceCreateDeviceRGB()
        let color1 = CGColor(colorSpace: rgb, components: [0.929, 0.11, 0.149, 1])!
        let color2 = CGColor(colorSpace: rgb, components: [0.929, 0.078, 0.322, 1])!
        let color3 = CGColor(colorSpace: rgb, components: [0.925, 0.035, 0.549, 1])!
        var locations: [CGFloat] = [0.0, 0.456, 1.0]
        let gradient = CGGradient(
          colorsSpace: rgb,
          colors: [color1, color2, color3] as CFArray,
          locations: &locations
        )!
        ctx.drawLinearGradient(gradient,
                       start: CGPoint(x: 21.44, y: 5.5),
                       end: CGPoint(x: 13.56, y: 5.5),
                       options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.translateBy(x: 18.48, y: 5.69)
        ctx.rotate(by: 2.07)
        ctx.scaleBy(x: 1.08, y: 2.36)
        ctx.setAlpha(1)
        let color4 = CGColor(colorSpace: rgb, components: [0.506, 0.235, 0.192, 1])!
        let color5 = CGColor(colorSpace: rgb, components: [0.506, 0.235, 0.192, 0])!
        var locations1: [CGFloat] = [0.0, 1.0]
        let gradient1 = CGGradient(
          colorsSpace: rgb,
          colors: [color4, color5] as CFArray,
          locations: &locations1
        )!
        ctx.drawRadialGradient(gradient1,
                       startCenter: CGPoint(x: 0, y: 0),
                       startRadius: 0,
                       endCenter: CGPoint(x: 0, y: 0),
                       endRadius: 1,
                       options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.setAlpha(1)
        ctx.drawLinearGradient(gradient1,
                       start: CGPoint(x: 17.96, y: 7.42),
                       end: CGPoint(x: 17.96, y: 6.67),
                       options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
        ctx.restoreGState()
        let color6 = CGColor(colorSpace: rgb, components: [0.275, 0.729, 0.604, 1])!
        ctx.setFillColor(color6)
        let path1 = CGMutablePath()
        path1.move(to: CGPoint(x: 29.77, y: 28.39))
        path1.addCurve(to: CGPoint(x: 22.86, y: 24.98),
                       control1: CGPoint(x: 28.12, y: 26.24),
                       control2: CGPoint(x: 25.57, y: 24.98))
        path1.addLine(to: CGPoint(x: 17.62, y: 24.98))
        path1.addCurve(to: CGPoint(x: 9.86, y: 22.8),
                       control1: CGPoint(x: 14.4, y: 24.98),
                       control2: CGPoint(x: 11.72, y: 24.23))
        path1.addCurve(to: CGPoint(x: 6.99, y: 16.37),
                       control1: CGPoint(x: 7.96, y: 21.34),
                       control2: CGPoint(x: 6.99, y: 19.18))
        path1.addCurve(to: CGPoint(x: 11.46, y: 11.94),
                       control1: CGPoint(x: 6.99, y: 13.91),
                       control2: CGPoint(x: 9, y: 11.92))
        path1.addCurve(to: CGPoint(x: 15.93, y: 16.38),
                       control1: CGPoint(x: 13.88, y: 11.96),
                       control2: CGPoint(x: 15.9, y: 13.96))
        path1.addLine(to: CGPoint(x: 15.93, y: 16.92))
        path1.addCurve(to: CGPoint(x: 18.76, y: 22.62),
                       control1: CGPoint(x: 15.93, y: 19.16),
                       control2: CGPoint(x: 16.96, y: 21.29))
        path1.addCurve(to: CGPoint(x: 22.94, y: 24),
                       control1: CGPoint(x: 19.94, y: 23.49),
                       control2: CGPoint(x: 21.38, y: 24))
        path1.addCurve(to: CGPoint(x: 29.98, y: 16.96),
                       control1: CGPoint(x: 26.82, y: 24),
                       control2: CGPoint(x: 29.98, y: 20.84))
        path1.addLine(to: CGPoint(x: 29.94, y: 4.81))
        path1.addCurve(to: CGPoint(x: 27.12, y: 2),
                       control1: CGPoint(x: 29.94, y: 3.26),
                       control2: CGPoint(x: 28.68, y: 2))
        path1.addLine(to: CGPoint(x: 17.56, y: 2))
        path1.addCurve(to: CGPoint(x: 16.94, y: 2.63),
                       control1: CGPoint(x: 17.21, y: 2),
                       control2: CGPoint(x: 16.93, y: 2.28))
        path1.addCurve(to: CGPoint(x: 22.31, y: 8),
                       control1: CGPoint(x: 16.94, y: 5.6),
                       control2: CGPoint(x: 19.34, y: 8))
        path1.addLine(to: CGPoint(x: 24.61, y: 8))
        path1.addCurve(to: CGPoint(x: 24.92, y: 8.31),
                       control1: CGPoint(x: 24.78, y: 8),
                       control2: CGPoint(x: 24.92, y: 8.14))
        path1.addLine(to: CGPoint(x: 24.96, y: 16.96))
        path1.addCurve(to: CGPoint(x: 22.98, y: 18.98),
                       control1: CGPoint(x: 24.96, y: 18.06),
                       control2: CGPoint(x: 24.08, y: 18.95))
        path1.addCurve(to: CGPoint(x: 20.93, y: 16.94),
                       control1: CGPoint(x: 21.85, y: 19.01),
                       control2: CGPoint(x: 20.93, y: 18.07))
        path1.addLine(to: CGPoint(x: 20.93, y: 16.2))
        path1.addCurve(to: CGPoint(x: 11.41, y: 6.93),
                       control1: CGPoint(x: 20.84, y: 11.07),
                       control2: CGPoint(x: 16.56, y: 6.93))
        path1.addCurve(to: CGPoint(x: 1.98, y: 16.71),
                       control1: CGPoint(x: 6.09, y: 6.93),
                       control2: CGPoint(x: 1.88, y: 11.39))
        path1.addCurve(to: CGPoint(x: 6.8, y: 26.78),
                       control1: CGPoint(x: 2.06, y: 20.94),
                       control2: CGPoint(x: 3.73, y: 24.41))
        path1.addCurve(to: CGPoint(x: 17.62, y: 30),
                       control1: CGPoint(x: 9.55, y: 28.89),
                       control2: CGPoint(x: 13.28, y: 30))
        path1.addLine(to: CGPoint(x: 28.98, y: 30))
        path1.addCurve(to: CGPoint(x: 29.77, y: 28.39),
                       control1: CGPoint(x: 29.81, y: 30),
                       control2: CGPoint(x: 30.28, y: 29.05))
        path1.closeSubpath()
        ctx.addPath(path1)
        ctx.fillPath()
        ctx.saveGState()
        ctx.addPath(path1)
        ctx.clip()
        ctx.setAlpha(1)
        let color7 = CGColor(colorSpace: rgb, components: [0.522, 0.588, 0.855, 1])!
        let color8 = CGColor(colorSpace: rgb, components: [0.522, 0.588, 0.855, 0])!
        var locations2: [CGFloat] = [0.0, 1.0]
        let gradient2 = CGGradient(
          colorsSpace: rgb,
          colors: [color7, color8] as CFArray,
          locations: &locations2
        )!
        ctx.drawLinearGradient(gradient2,
                       start: CGPoint(x: 15.98, y: 30.69),
                       end: CGPoint(x: 15.98, y: 27.75),
                       options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(path1)
        ctx.clip()
        ctx.translateBy(x: 19.42, y: 8.56)
        ctx.rotate(by: 2.18)
        ctx.scaleBy(x: 22.59, y: 29.2)
        ctx.setAlpha(1)
        var locations3: [CGFloat] = [0.854353, 1.0]
        let gradient3 = CGGradient(
          colorsSpace: rgb,
          colors: [color8, color7] as CFArray,
          locations: &locations3
        )!
        ctx.drawRadialGradient(gradient3,
                       startCenter: CGPoint(x: 0, y: 0),
                       startRadius: 0,
                       endCenter: CGPoint(x: 0, y: 0),
                       endRadius: 1,
                       options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(path1)
        ctx.clip()
        ctx.translateBy(x: 8.98, y: 19.31)
        ctx.rotate(by: 3)
        ctx.scaleBy(x: 3.85, y: 8.42)
        ctx.setAlpha(1)
        let color9 = CGColor(colorSpace: rgb, components: [0.341, 0.831, 0.576, 1])!
        let color10 = CGColor(colorSpace: rgb, components: [0.341, 0.831, 0.576, 0])!
        var locations4: [CGFloat] = [0.0, 1.0]
        let gradient4 = CGGradient(
          colorsSpace: rgb,
          colors: [color9, color10] as CFArray,
          locations: &locations4
        )!
        ctx.drawRadialGradient(gradient4,
                       startCenter: CGPoint(x: 0, y: 0),
                       startRadius: 0,
                       endCenter: CGPoint(x: 0, y: 0),
                       endRadius: 1,
                       options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(path1)
        ctx.clip()
        ctx.translateBy(x: 15.04, y: 23.75)
        ctx.rotate(by: 1.69)
        ctx.scaleBy(x: 2.71, y: 7.3)
        ctx.setAlpha(1)
        ctx.drawRadialGradient(gradient4,
                       startCenter: CGPoint(x: 0, y: 0),
                       startRadius: 0,
                       endCenter: CGPoint(x: 0, y: 0),
                       endRadius: 1,
                       options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(path1)
        ctx.clip()
        ctx.translateBy(x: 30.48, y: 27)
        ctx.rotate(by: 2.62)
        ctx.scaleBy(x: 4.48, y: 5.51)
        ctx.setAlpha(1)
        let color11 = CGColor(colorSpace: rgb, components: [0.349, 0.851, 0.576, 1])!
        let color12 = CGColor(colorSpace: rgb, components: [0.349, 0.851, 0.576, 0])!
        var locations5: [CGFloat] = [0.0, 1.0]
        let gradient5 = CGGradient(
          colorsSpace: rgb,
          colors: [color11, color12] as CFArray,
          locations: &locations5
        )!
        ctx.drawRadialGradient(gradient5,
                       startCenter: CGPoint(x: 0, y: 0),
                       startRadius: 0,
                       endCenter: CGPoint(x: 0, y: 0),
                       endRadius: 1,
                       options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(path1)
        ctx.clip()
        ctx.translateBy(x: 29.98, y: 2.56)
        ctx.rotate(by: 2.27)
        ctx.scaleBy(x: 6.41, y: 6.52)
        ctx.setAlpha(1)
        let color13 = CGColor(colorSpace: rgb, components: [0.392, 0.902, 0.604, 1])!
        let color14 = CGColor(colorSpace: rgb, components: [0.392, 0.902, 0.604, 0])!
        var locations6: [CGFloat] = [0.0, 1.0]
        let gradient6 = CGGradient(
          colorsSpace: rgb,
          colors: [color13, color14] as CFArray,
          locations: &locations6
        )!
        ctx.drawRadialGradient(gradient6,
                       startCenter: CGPoint(x: 0, y: 0),
                       startRadius: 0,
                       endCenter: CGPoint(x: 0, y: 0),
                       endRadius: 1,
                       options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(path1)
        ctx.clip()
        ctx.translateBy(x: 21.1, y: 11.56)
        ctx.rotate(by: 2.52)
        ctx.scaleBy(x: 4.21, y: 6.5)
        ctx.setAlpha(1)
        ctx.drawRadialGradient(gradient4,
                       startCenter: CGPoint(x: 0, y: 0),
                       startRadius: 0,
                       endCenter: CGPoint(x: 0, y: 0),
                       endRadius: 1,
                       options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(path1)
        ctx.clip()
        ctx.setAlpha(1)
        ctx.drawLinearGradient(gradient4,
                       start: CGPoint(x: 24.67, y: 1.12),
                       end: CGPoint(x: 24.67, y: 6.06),
                       options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(path1)
        ctx.clip()
        ctx.translateBy(x: 13.48, y: 12.72)
        ctx.rotate(by: 1.99)
        ctx.scaleBy(x: 5.89, y: 6.22)
        ctx.setAlpha(1)
        let color15 = CGColor(colorSpace: rgb, components: [0.263, 0.69, 0.588, 1])!
        let color16 = CGColor(colorSpace: rgb, components: [0.263, 0.69, 0.588, 0])!
        var locations7: [CGFloat] = [0.0, 0.957444]
        let gradient7 = CGGradient(
          colorsSpace: rgb,
          colors: [color15, color16] as CFArray,
          locations: &locations7
        )!
        ctx.drawRadialGradient(gradient7,
                       startCenter: CGPoint(x: 0, y: 0),
                       startRadius: 0,
                       endCenter: CGPoint(x: 0, y: 0),
                       endRadius: 1,
                       options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(path1)
        ctx.clip()
        ctx.translateBy(x: 12.1, y: 14.03)
        ctx.rotate(by: 1.82)
        ctx.scaleBy(x: 4.19, y: 4.73)
        ctx.setAlpha(1)
        var locations8: [CGFloat] = [0.0, 0.957444]
        let gradient8 = CGGradient(
          colorsSpace: rgb,
          colors: [color7, color8] as CFArray,
          locations: &locations8
        )!
        ctx.drawRadialGradient(gradient8,
                       startCenter: CGPoint(x: 0, y: 0),
                       startRadius: 0,
                       endCenter: CGPoint(x: 0, y: 0),
                       endRadius: 1,
                       options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(path1)
        ctx.clip()
        ctx.translateBy(x: 22.7, y: 8.59)
        ctx.rotate(by: 2.87)
        ctx.scaleBy(x: 3.5, y: 2.11)
        ctx.setAlpha(1)
        ctx.drawRadialGradient(gradient8,
                       startCenter: CGPoint(x: 0, y: 0),
                       startRadius: 0,
                       endCenter: CGPoint(x: 0, y: 0),
                       endRadius: 1,
                       options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(path1)
        ctx.clip()
        ctx.translateBy(x: 23.42, y: 18.56)
        ctx.rotate(by: -1.57)
        ctx.scaleBy(x: 3.28, y: 4.66)
        ctx.setAlpha(1)
        let color17 = CGColor(colorSpace: rgb, components: [0.235, 0.702, 0.451, 1])!
        let color18 = CGColor(colorSpace: rgb, components: [0.235, 0.702, 0.451, 0])!
        var locations9: [CGFloat] = [0.0, 1.0]
        let gradient9 = CGGradient(
          colorsSpace: rgb,
          colors: [color17, color18] as CFArray,
          locations: &locations9
        )!
        ctx.drawRadialGradient(gradient9,
                       startCenter: CGPoint(x: 0, y: 0),
                       startRadius: 0,
                       endCenter: CGPoint(x: 0, y: 0),
                       endRadius: 1,
                       options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(path1)
        ctx.clip()
        ctx.translateBy(x: 25.01, y: 14.34)
        ctx.rotate(by: -3.14)
        ctx.scaleBy(x: 2.41, y: 6.84)
        ctx.setAlpha(1)
        ctx.drawRadialGradient(gradient9,
                       startCenter: CGPoint(x: 0, y: 0),
                       startRadius: 0,
                       endCenter: CGPoint(x: 0, y: 0),
                       endRadius: 1,
                       options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(path1)
        ctx.clip()
        ctx.translateBy(x: 19.13, y: 7.91)
        ctx.rotate(by: -0.83)
        ctx.scaleBy(x: 3.85, y: 8.25)
        ctx.setAlpha(1)
        let color19 = CGColor(colorSpace: rgb, components: [0.255, 0.647, 0.569, 1])!
        let color20 = CGColor(colorSpace: rgb, components: [0.255, 0.647, 0.569, 0])!
        var locations10: [CGFloat] = [0.0, 1.0]
        let gradient10 = CGGradient(
          colorsSpace: rgb,
          colors: [color19, color20] as CFArray,
          locations: &locations10
        )!
        ctx.drawRadialGradient(gradient10,
                       startCenter: CGPoint(x: 0, y: 0),
                       startRadius: 0,
                       endCenter: CGPoint(x: 0, y: 0),
                       endRadius: 1,
                       options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
        ctx.restoreGState()
        ctx.restoreGState()
      }

      // filter0 uses an SVG standard deviation of 0.75 viewBox units.
      context.drawLayer { context in
        context.addFilter(.blur(radius: 0.75 * svgUnitScale))
        context.withCGContext { ctx in
          ctx.scaleBy(x: scale.width, y: scale.height)
          ctx.scaleBy(x: 8, y: 8)
          let path2 = CGMutablePath()
          path2.move(to: CGPoint(x: 21.33, y: 4.59))
          path2.addCurve(to: CGPoint(x: 18.36, y: 3.05),
                         control1: CGPoint(x: 19.72, y: 4.59),
                         control2: CGPoint(x: 18.77, y: 3.7))
          path2.addCurve(to: CGPoint(x: 18.56, y: 2.72),
                         control1: CGPoint(x: 18.26, y: 2.9),
                         control2: CGPoint(x: 18.38, y: 2.72))
          path2.addLine(to: CGPoint(x: 27.57, y: 2.72))
          path2.addCurve(to: CGPoint(x: 27.82, y: 2.97),
                         control1: CGPoint(x: 27.71, y: 2.72),
                         control2: CGPoint(x: 27.82, y: 2.83))
          path2.addLine(to: CGPoint(x: 27.82, y: 4.34))
          path2.addCurve(to: CGPoint(x: 27.57, y: 4.59),
                         control1: CGPoint(x: 27.82, y: 4.48),
                         control2: CGPoint(x: 27.71, y: 4.59))
          path2.addLine(to: CGPoint(x: 21.33, y: 4.59))
          path2.closeSubpath()
          ctx.addPath(path2)
          ctx.clip()
          ctx.setAlpha(1)
          let rgb = CGColorSpaceCreateDeviceRGB()
          let color21 = CGColor(colorSpace: rgb, components: [0.278, 0.827, 0.553, 1])!
          let color22 = CGColor(colorSpace: rgb, components: [0.278, 0.827, 0.553, 0])!
          var locations11: [CGFloat] = [0.0, 1.0]
          let gradient11 = CGGradient(
            colorsSpace: rgb,
            colors: [color21, color22] as CFArray,
            locations: &locations11
          )!
          ctx.drawLinearGradient(gradient11,
                         start: CGPoint(x: 25.18, y: 4.59),
                         end: CGPoint(x: 8.53, y: 4.59),
                         options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
        }
      }

      context.withCGContext { ctx in
        ctx.scaleBy(x: scale.width, y: scale.height)
        ctx.saveGState()
        ctx.scaleBy(x: 8, y: 8)
        let rgb = CGColorSpaceCreateDeviceRGB()
        ctx.saveGState()
        let path3 = CGMutablePath()
        path3.move(to: CGPoint(x: 23.48, y: 6.03))
        path3.addCurve(to: CGPoint(x: 22.94, y: 5.49),
                       control1: CGPoint(x: 23.18, y: 6.03),
                       control2: CGPoint(x: 22.94, y: 5.79))
        path3.addLine(to: CGPoint(x: 22.94, y: 4.54))
        path3.addCurve(to: CGPoint(x: 23.48, y: 4),
                       control1: CGPoint(x: 22.94, y: 4.24),
                       control2: CGPoint(x: 23.18, y: 4))
        path3.addCurve(to: CGPoint(x: 24.02, y: 4.54),
                       control1: CGPoint(x: 23.78, y: 4),
                       control2: CGPoint(x: 24.02, y: 4.24))
        path3.addLine(to: CGPoint(x: 24.02, y: 5.49))
        path3.addCurve(to: CGPoint(x: 23.48, y: 6.03),
                       control1: CGPoint(x: 24.02, y: 5.79),
                       control2: CGPoint(x: 23.78, y: 6.03))
        path3.closeSubpath()
        ctx.addPath(path3)
        ctx.clip()
        ctx.setAlpha(1)
        let color23 = CGColor(colorSpace: rgb, components: [0.349, 0.298, 0.31, 1])!
        let color24 = CGColor(colorSpace: rgb, components: [0.224, 0.157, 0.2, 1])!
        var locations12: [CGFloat] = [0.225, 1.0]
        let gradient12 = CGGradient(
          colorsSpace: rgb,
          colors: [color23, color24] as CFArray,
          locations: &locations12
        )!
        ctx.drawLinearGradient(gradient12,
                       start: CGPoint(x: 24.02, y: 4.89),
                       end: CGPoint(x: 23.39, y: 4.89),
                       options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(path3)
        ctx.clip()
        ctx.setAlpha(1)
        let color25 = CGColor(colorSpace: rgb, components: [0.286, 0.157, 0.278, 1])!
        let color26 = CGColor(colorSpace: rgb, components: [0.333, 0.176, 0.322, 0])!
        var locations13: [CGFloat] = [0.0, 1.0]
        let gradient13 = CGGradient(
          colorsSpace: rgb,
          colors: [color25, color26] as CFArray,
          locations: &locations13
        )!
        ctx.drawLinearGradient(gradient13,
                       start: CGPoint(x: 24.19, y: 5.94),
                       end: CGPoint(x: 24.19, y: 4.97),
                       options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(path3)
        ctx.clip()
        ctx.translateBy(x: 23.6, y: 5.17)
        ctx.rotate(by: -1.85)
        ctx.scaleBy(x: 1.2, y: 1.36)
        ctx.setAlpha(1)
        let color27 = CGColor(colorSpace: rgb, components: [0.349, 0.298, 0.31, 0])!
        var locations14: [CGFloat] = [0.813951, 1.0]
        let gradient14 = CGGradient(
          colorsSpace: rgb,
          colors: [color27, color23] as CFArray,
          locations: &locations14
        )!
        ctx.drawRadialGradient(gradient14,
                       startCenter: CGPoint(x: 0, y: 0),
                       startRadius: 0,
                       endCenter: CGPoint(x: 0, y: 0),
                       endRadius: 1,
                       options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
        ctx.restoreGState()
        ctx.saveGState()
        let path4 = CGMutablePath()
        path4.move(to: CGPoint(x: 4.04, y: 16.42))
        path4.addCurve(to: CGPoint(x: 3.04, y: 15.42),
                       control1: CGPoint(x: 4.04, y: 15.87),
                       control2: CGPoint(x: 3.59, y: 15.42))
        path4.addLine(to: CGPoint(x: 2.04, y: 15.42))
        path4.addCurve(to: CGPoint(x: 1.98, y: 16.71),
                       control1: CGPoint(x: 1.99, y: 15.85),
                       control2: CGPoint(x: 1.97, y: 16.28))
        path4.addCurve(to: CGPoint(x: 2.01, y: 17.42),
                       control1: CGPoint(x: 1.98, y: 16.95),
                       control2: CGPoint(x: 2, y: 17.18))
        path4.addLine(to: CGPoint(x: 3.04, y: 17.42))
        path4.addCurve(to: CGPoint(x: 4.04, y: 16.42),
                       control1: CGPoint(x: 3.6, y: 17.42),
                       control2: CGPoint(x: 4.04, y: 16.97))
        path4.closeSubpath()
        ctx.addPath(path4)
        ctx.clip()
        ctx.setAlpha(1)
        let color28 = CGColor(colorSpace: rgb, components: [0.706, 0.733, 0.239, 1])!
        let color29 = CGColor(colorSpace: rgb, components: [0.663, 0.714, 0.243, 1])!
        var locations15: [CGFloat] = [0.0, 1.0]
        let gradient15 = CGGradient(
          colorsSpace: rgb,
          colors: [color28, color29] as CFArray,
          locations: &locations15
        )!
        ctx.drawLinearGradient(gradient15,
                       start: CGPoint(x: 4.67, y: 16.42),
                       end: CGPoint(x: 1.98, y: 16.42),
                       options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
        ctx.restoreGState()
        ctx.saveGState()
        let path5 = CGMutablePath()
        path5.move(to: CGPoint(x: 4.67, y: 11.34))
        path5.addLine(to: CGPoint(x: 3.81, y: 10.84))
        path5.addCurve(to: CGPoint(x: 2.81, y: 12.57),
                       control1: CGPoint(x: 3.42, y: 11.38),
                       control2: CGPoint(x: 3.09, y: 11.96))
        path5.addLine(to: CGPoint(x: 3.67, y: 13.07))
        path5.addCurve(to: CGPoint(x: 5.04, y: 12.7),
                       control1: CGPoint(x: 4.15, y: 13.35),
                       control2: CGPoint(x: 4.76, y: 13.18))
        path5.addCurve(to: CGPoint(x: 4.67, y: 11.34),
                       control1: CGPoint(x: 5.32, y: 12.23),
                       control2: CGPoint(x: 5.15, y: 11.62))
        path5.closeSubpath()
        ctx.addPath(path5)
        ctx.clip()
        ctx.setAlpha(1)
        let color30 = CGColor(colorSpace: rgb, components: [0.663, 0.745, 0.235, 1])!
        let color31 = CGColor(colorSpace: rgb, components: [0.694, 0.745, 0.212, 1])!
        var locations16: [CGFloat] = [0.0, 1.0]
        let gradient16 = CGGradient(
          colorsSpace: rgb,
          colors: [color30, color31] as CFArray,
          locations: &locations16
        )!
        ctx.drawLinearGradient(gradient16,
                       start: CGPoint(x: 3.35, y: 11.34),
                       end: CGPoint(x: 5.38, y: 12.72),
                       options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
        ctx.restoreGState()
        ctx.saveGState()
        let path6 = CGMutablePath()
        path6.move(to: CGPoint(x: 7.76, y: 9.99))
        path6.addCurve(to: CGPoint(x: 8.13, y: 8.62),
                       control1: CGPoint(x: 8.24, y: 9.71),
                       control2: CGPoint(x: 8.4, y: 9.1))
        path6.addLine(to: CGPoint(x: 7.61, y: 7.74))
        path6.addCurve(to: CGPoint(x: 5.88, y: 8.75),
                       control1: CGPoint(x: 7, y: 8.02),
                       control2: CGPoint(x: 6.42, y: 8.36))
        path6.addLine(to: CGPoint(x: 6.39, y: 9.63))
        path6.addCurve(to: CGPoint(x: 7.76, y: 9.99),
                       control1: CGPoint(x: 6.67, y: 10.11),
                       control2: CGPoint(x: 7.28, y: 10.27))
        path6.closeSubpath()
        ctx.addPath(path6)
        ctx.clip()
        ctx.setAlpha(1)
        let color32 = CGColor(colorSpace: rgb, components: [0.69, 0.792, 0.278, 1])!
        let color33 = CGColor(colorSpace: rgb, components: [0.71, 0.776, 0.216, 1])!
        var locations17: [CGFloat] = [0.0, 1.0]
        let gradient17 = CGGradient(
          colorsSpace: rgb,
          colors: [color32, color33] as CFArray,
          locations: &locations17
        )!
        ctx.drawLinearGradient(gradient17,
                       start: CGPoint(x: 6.67, y: 7.97),
                       end: CGPoint(x: 8.04, y: 10.13),
                       options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
        ctx.restoreGState()
        ctx.saveGState()
        let path7 = CGMutablePath()
        path7.move(to: CGPoint(x: 10.47, y: 6.98))
        path7.addLine(to: CGPoint(x: 10.47, y: 8))
        path7.addCurve(to: CGPoint(x: 11.47, y: 9),
                       control1: CGPoint(x: 10.47, y: 8.55),
                       control2: CGPoint(x: 10.92, y: 9))
        path7.addCurve(to: CGPoint(x: 12.47, y: 8),
                       control1: CGPoint(x: 12.02, y: 9),
                       control2: CGPoint(x: 12.47, y: 8.55))
        path7.addLine(to: CGPoint(x: 12.47, y: 6.99))
        path7.addCurve(to: CGPoint(x: 11.42, y: 6.93),
                       control1: CGPoint(x: 12.12, y: 6.95),
                       control2: CGPoint(x: 11.77, y: 6.93))
        path7.addCurve(to: CGPoint(x: 10.47, y: 6.98),
                       control1: CGPoint(x: 11.1, y: 6.93),
                       control2: CGPoint(x: 10.78, y: 6.95))
        path7.closeSubpath()
        ctx.addPath(path7)
        ctx.clip()
        ctx.setAlpha(1)
        let color34 = CGColor(colorSpace: rgb, components: [0.698, 0.808, 0.271, 1])!
        let color35 = CGColor(colorSpace: rgb, components: [0.741, 0.812, 0.259, 1])!
        var locations18: [CGFloat] = [0.0, 1.0]
        let gradient18 = CGGradient(
          colorsSpace: rgb,
          colors: [color34, color35] as CFArray,
          locations: &locations18
        )!
        ctx.drawLinearGradient(gradient18,
                       start: CGPoint(x: 11.47, y: 6.46),
                       end: CGPoint(x: 11.47, y: 9),
                       options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
        ctx.restoreGState()
        ctx.saveGState()
        let path8 = CGMutablePath()
        path8.move(to: CGPoint(x: 27.93, y: 17.24))
        path8.addCurve(to: CGPoint(x: 28.93, y: 18.24),
                       control1: CGPoint(x: 27.93, y: 17.79),
                       control2: CGPoint(x: 28.38, y: 18.24))
        path8.addLine(to: CGPoint(x: 29.86, y: 18.24))
        path8.addCurve(to: CGPoint(x: 29.98, y: 16.96),
                       control1: CGPoint(x: 29.94, y: 17.83),
                       control2: CGPoint(x: 29.98, y: 17.4))
        path8.addLine(to: CGPoint(x: 29.98, y: 16.24))
        path8.addLine(to: CGPoint(x: 28.93, y: 16.24))
        path8.addCurve(to: CGPoint(x: 27.93, y: 17.24),
                       control1: CGPoint(x: 28.38, y: 16.24),
                       control2: CGPoint(x: 27.93, y: 16.69))
        path8.closeSubpath()
        ctx.addPath(path8)
        ctx.clip()
        ctx.setAlpha(1)
        let color36 = CGColor(colorSpace: rgb, components: [0.784, 0.875, 0.31, 1])!
        let color37 = CGColor(colorSpace: rgb, components: [0.812, 0.898, 0.298, 1])!
        var locations19: [CGFloat] = [0.0, 1.0]
        let gradient19 = CGGradient(
          colorsSpace: rgb,
          colors: [color36, color37] as CFArray,
          locations: &locations19
        )!
        ctx.drawLinearGradient(gradient19,
                       start: CGPoint(x: 27.35, y: 17.24),
                       end: CGPoint(x: 30.2, y: 17.24),
                       options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
        ctx.restoreGState()
        ctx.saveGState()
        let path9 = CGMutablePath()
        path9.move(to: CGPoint(x: 29.96, y: 12))
        path9.addLine(to: CGPoint(x: 28.93, y: 12))
        path9.addCurve(to: CGPoint(x: 27.93, y: 13),
                       control1: CGPoint(x: 28.38, y: 12),
                       control2: CGPoint(x: 27.93, y: 12.45))
        path9.addCurve(to: CGPoint(x: 28.93, y: 14),
                       control1: CGPoint(x: 27.93, y: 13.55),
                       control2: CGPoint(x: 28.38, y: 14))
        path9.addLine(to: CGPoint(x: 29.97, y: 14))
        path9.addLine(to: CGPoint(x: 29.96, y: 12))
        path9.closeSubpath()
        ctx.addPath(path9)
        ctx.clip()
        ctx.setAlpha(1)
        ctx.drawLinearGradient(gradient19,
                       start: CGPoint(x: 27.36, y: 13),
                       end: CGPoint(x: 30.19, y: 13),
                       options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
        ctx.restoreGState()
        ctx.saveGState()
        let path10 = CGMutablePath()
        path10.move(to: CGPoint(x: 29.95, y: 8))
        path10.addLine(to: CGPoint(x: 28.93, y: 8))
        path10.addCurve(to: CGPoint(x: 27.93, y: 9),
                       control1: CGPoint(x: 28.38, y: 8),
                       control2: CGPoint(x: 27.93, y: 8.45))
        path10.addCurve(to: CGPoint(x: 28.93, y: 10),
                       control1: CGPoint(x: 27.93, y: 9.55),
                       control2: CGPoint(x: 28.38, y: 10))
        path10.addLine(to: CGPoint(x: 29.96, y: 10))
        path10.addLine(to: CGPoint(x: 29.95, y: 8))
        path10.closeSubpath()
        ctx.addPath(path10)
        ctx.clip()
        ctx.setAlpha(1)
        ctx.drawLinearGradient(gradient19,
                       start: CGPoint(x: 27.36, y: 9),
                       end: CGPoint(x: 30.18, y: 9),
                       options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
        ctx.restoreGState()
        ctx.restoreGState()
      }

      context.drawLayer { context in
        context.addFilter(.blur(radius: svgUnitScale))
        context.withCGContext { ctx in
          ctx.scaleBy(x: scale.width, y: scale.height)
          ctx.scaleBy(x: 8, y: 8)
          ctx.setLineCap(.round)
          ctx.setLineJoin(.miter)
          ctx.setLineWidth(1)
          ctx.setMiterLimit(4)
          let rgb = CGColorSpaceCreateDeviceRGB()
          let color38 = CGColor(colorSpace: rgb, components: [0.341, 0.878, 0.639, 1])!
          ctx.setStrokeColor(color38)
          let path11 = CGMutablePath()
          path11.move(to: CGPoint(x: 11.18, y: 10.13))
          path11.addCurve(to: CGPoint(x: 5.21, y: 17.07),
                          control1: CGPoint(x: 9.62, y: 10.13),
                          control2: CGPoint(x: 4.68, y: 10.88))
          path11.addCurve(to: CGPoint(x: 14.13, y: 26.31),
                          control1: CGPoint(x: 5.74, y: 23.25),
                          control2: CGPoint(x: 9.57, y: 25.34))
          path11.addCurve(to: CGPoint(x: 22.37, y: 26.88),
                          control1: CGPoint(x: 16.68, y: 26.85),
                          control2: CGPoint(x: 20.53, y: 26.88))
          ctx.addPath(path11)
          ctx.strokePath()
        }
      }

      context.drawLayer { context in
        context.addFilter(.blur(radius: svgUnitScale / 2))
        context.withCGContext { ctx in
          ctx.scaleBy(x: scale.width, y: scale.height)
          ctx.scaleBy(x: 8, y: 8)
          ctx.setLineCap(.round)
          ctx.setLineJoin(.miter)
          ctx.setLineWidth(1)
          ctx.setMiterLimit(4)
          let path12 = CGMutablePath()
          path12.move(to: CGPoint(x: 28.85, y: 28.75))
          path12.addCurve(to: CGPoint(x: 22.88, y: 26.88),
                          control1: CGPoint(x: 28.1, y: 28.08),
                          control2: CGPoint(x: 25.39, y: 26.88))
          path12.addCurve(to: CGPoint(x: 18.74, y: 26.88),
                          control1: CGPoint(x: 20.53, y: 26.88),
                          control2: CGPoint(x: 19.73, y: 26.88))
          ctx.addPath(path12)
          ctx.replacePathWithStrokedPath()
          ctx.clip()
          ctx.setAlpha(1)
          let rgb = CGColorSpaceCreateDeviceRGB()
          let color39 = CGColor(colorSpace: rgb, components: [0.373, 0.859, 0.643, 1])!
          let color40 = CGColor(colorSpace: rgb, components: [0.373, 0.859, 0.643, 0])!
          var locations20: [CGFloat] = [0.0, 1.0]
          let gradient20 = CGGradient(
            colorsSpace: rgb,
            colors: [color39, color40] as CFArray,
            locations: &locations20
          )!
          ctx.drawLinearGradient(gradient20,
                          start: CGPoint(x: 28.08, y: 26.88),
                          end: CGPoint(x: 19.24, y: 26.88),
                          options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
        }
      }

      context.drawLayer { context in
        context.addFilter(.blur(radius: svgUnitScale))
        context.withCGContext { ctx in
          ctx.scaleBy(x: scale.width, y: scale.height)
          ctx.scaleBy(x: 8, y: 8)
          ctx.setLineCap(.round)
          ctx.setLineJoin(.miter)
          ctx.setLineWidth(1)
          ctx.setMiterLimit(4)
          let rgb = CGColorSpaceCreateDeviceRGB()
          let color41 = CGColor(colorSpace: rgb, components: [0.314, 0.902, 0.608, 1])!
          ctx.setStrokeColor(color41)
          let path13 = CGMutablePath()
          path13.move(to: CGPoint(x: 14.1, y: 9.19))
          path13.addCurve(to: CGPoint(x: 19.29, y: 16.44),
                          control1: CGPoint(x: 15.83, y: 9.4),
                          control2: CGPoint(x: 19.29, y: 11.06))
          path13.addCurve(to: CGPoint(x: 24.34, y: 21.67),
                          control1: CGPoint(x: 19.29, y: 21.19),
                          control2: CGPoint(x: 22.43, y: 21.89))
          path13.addCurve(to: CGPoint(x: 28.23, y: 15.75),
                          control1: CGPoint(x: 26.24, y: 21.45),
                          control2: CGPoint(x: 28.23, y: 20.19))
          path13.addCurve(to: CGPoint(x: 28.23, y: 4.44),
                          control1: CGPoint(x: 28.23, y: 12.2),
                          control2: CGPoint(x: 28.23, y: 6.73))
          ctx.addPath(path13)
          ctx.strokePath()
        }
      }
    }
  }
}
