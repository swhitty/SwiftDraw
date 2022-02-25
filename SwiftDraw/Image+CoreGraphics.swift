//
//  Image.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 24/5/17.
//  Copyright 2020 Simon Whitty
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

#if canImport(CoreGraphics)
import CoreGraphics
import Foundation

public extension CGContext {

  func draw(_ image: Image, in rect: CGRect? = nil)  {
    let defaultRect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
    let renderer = CGRenderer(context: self)

    guard let rect = rect, rect != defaultRect else {
      renderer.perform(image.commands)
      return
    }

    let scale = CGSize(width: rect.width / image.size.width,
                       height: rect.height / image.size.height)
    draw(image.commands, in: rect, scale: scale)
  }

  fileprivate func draw(_ commands: [RendererCommand<CGTypes>], in rect: CGRect, scale: CGSize = CGSize(width: 1.0, height: 1.0)) {
    let renderer = CGRenderer(context: self)
    saveGState()
    translateBy(x: rect.origin.x, y: rect.origin.y)
    scaleBy(x: scale.width, y: scale.height)
    renderer.perform(commands)
    restoreGState()
  }
}

public extension Image {

  func pdfData(size: CGSize? = nil) -> Data? {
    let renderSize = size ?? self.size
    let data = NSMutableData()
    guard let consumer = CGDataConsumer(data: data as CFMutableData) else { return nil }

    var mediaBox = CGRect(x: 0.0, y: 0.0, width: renderSize.width, height: renderSize.height)

    guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }

    ctx.beginPage(mediaBox: &mediaBox)
    let flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: mediaBox.size.height)
    ctx.concatenate(flip)
    ctx.draw(self, in: mediaBox)
    ctx.endPage()
    ctx.closePDF()

    return data as Data
  }

  static func pdfData(fileURL url: URL, size: CGSize? = nil) throws -> Data {
    let svg = try DOM.SVG.parse(fileURL: url)
    let size = size ?? CGSize(width: CGFloat(svg.width), height: CGFloat(svg.height))
    let layer = LayerTree.Builder(svg: svg).makeLayer()
    var mediaBox = CGRect(origin: .zero, size: size)
    let generator = LayerTree.CommandGenerator(provider: CGProvider(supportsTransparencyLayers: false),
                                               size: LayerTree.Size(size))
    let commands = generator.renderCommands(for: layer)
    let data = NSMutableData()
    guard let consumer = CGDataConsumer(data: data as CFMutableData) else { throw Error.unknown }

    guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { throw Error.unknown  }

    ctx.beginPage(mediaBox: &mediaBox)
    let flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: mediaBox.size.height)
    ctx.concatenate(flip)

    let scale = CGSize(width: mediaBox.width / CGFloat(svg.width),
                       height: mediaBox.height / CGFloat(svg.height))
    ctx.draw(commands, in: mediaBox, scale: scale)
    ctx.endPage()
    ctx.closePDF()

    return data as Data
  }

  private enum Error: Swift.Error {
    case unknown
  }
}

private extension LayerTree.Size {

  init(_ size: CGSize) {
    self.width = LayerTree.Float(size.width)
    self.height = LayerTree.Float(size.height)
  }
}

#endif
