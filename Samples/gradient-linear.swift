extension UIImage {
  static func svgGradientRadial(size: CGSize = CGSize(width: 480.0, height: 352.0)) -> UIImage {
    let f = UIGraphicsImageRendererFormat.preferred()
    f.opaque = false
    let scale = CGSize(width: size.width / 480.0, height: size.height / 352.0)
    return UIGraphicsImageRenderer(size: size, format: f).image {
      drawSVG(in: $0.cgContext, scale: scale)
    }
  }

  private static func drawSVG(in ctx: CGContext, scale: CGSize) {
    let baseCTM = ctx.ctm
    ctx.scaleBy(x: scale.width, y: scale.height)
    let patternDraw: CGPatternDrawPatternCallback = { _, ctx in
      let rgb = CGColorSpaceCreateDeviceRGB()
      let color1 = CGColor(colorSpace: rgb, components: [0.2509804, 0.2509804, 0.2509804, 1.0])!
      ctx.setFillColor(color1)
      ctx.fill(CGRect(x: 0.0, y: 0.0, width: 32.0, height: 32.0))
      let color2 = CGColor(colorSpace: rgb, components: [0.16078432, 0.16078432, 0.16078432, 1.0])!
      ctx.setFillColor(color2)
      ctx.fill(CGRect(x: 32.0, y: 0.0, width: 32.0, height: 32.0))
      ctx.fill(CGRect(x: 0.0, y: 32.0, width: 32.0, height: 32.0))
      ctx.setFillColor(color1)
      ctx.fill(CGRect(x: 32.0, y: 32.0, width: 32.0, height: 32.0))
    }
    var patternCallback = CGPatternCallbacks(version: 0, drawPattern: patternDraw, releaseInfo: nil)
    let pattern = CGPattern(
      info: nil,
      bounds: CGRect(x: 0.0, y: 0.0, width: 64.0, height: 64.0),
      matrix: ctx.ctm.concatenating(baseCTM.inverted()),
      xStep: 64.0,
      yStep: 64.0,
      tiling: .constantSpacing,
      isColored: true,
      callbacks: &patternCallback
    )!
    ctx.setFillColorSpace(CGColorSpace(patternBaseSpace: nil)!)
    var patternAlpha : CGFloat = 1.0
    ctx.setFillPattern(pattern, colorComponents: &patternAlpha)
    ctx.fill(CGRect(x: 0.0, y: 0.0, width: 480.0, height: 352.0))
    ctx.saveGState()
    let path = CGPath(
      ellipseIn: CGRect(x: 160.0, y: 96.0, width: 160.0, height: 160.0),
      transform: nil
    )
    ctx.addPath(path)
    ctx.clip()
    ctx.setAlpha(1.0)
    let rgb = CGColorSpaceCreateDeviceRGB()
    let color1 = CGColor(colorSpace: rgb, components: [1.0, 0.84313726, 0.0, 1.0])!
    let color2 = CGColor(colorSpace: rgb, components: [1.0, 0.0, 0.0, 1.0])!
    var locations: [CGFloat] = [0.1, 0.95]
    let gradient = CGGradient(
      colorsSpace: rgb,
      colors: [color1, color2] as CFArray,
      locations: &locations
    )!
    ctx.drawLinearGradient(gradient,
                       start: CGPoint(x: 160.0, y: 256.0),
                       end: CGPoint(x: 320.0, y: 256.0),
                       options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
    ctx.restoreGState()
  }
}