//
//  SVG.swift
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

import Foundation

#if compiler(<5.9)
#warning("SwiftDraw will soon remove support for Swift 5.8")
#endif

#if canImport(CoreGraphics)
import CoreGraphics

public struct SVG: Hashable {
    public private(set) var size: CGSize

    // Array of commands that render the image
    // see: Renderer.swift
    var commands: [RendererCommand<CGTypes>]

    public init?(fileURL url: URL, options: SVG.Options = .default) {
        do {
            let svg = try DOM.SVG.parse(fileURL: url)
            self.init(dom: svg, options: options)
        } catch {
            XMLParser.logParsingError(for: error, filename: url.lastPathComponent, parsing: nil)
            return nil
        }
    }

    public init?(named name: String, in bundle: Bundle = Bundle.main, options: SVG.Options = .default) {
        guard let url = bundle.url(forResource: name, withExtension: nil) else { return nil }
        self.init(fileURL: url, options: options)
    }

    public init?(xml: String, options: SVG.Options = .default) {
        guard let data = xml.data(using: .utf8) else { return nil }
        self.init(data: data)
    }

    public init?(data: Data, options: SVG.Options = .default) {
        guard let svg = try? DOM.SVG.parse(data: data) else { return nil }
        self.init(dom: svg, options: options)
    }

    public struct Options: OptionSet {
        public let rawValue: Int
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let hideUnsupportedFilters = Options(rawValue: 1 << 0)

        public static let `default`: Options = []
    }
}

public extension SVG {

    func sized(_ s: CGSize) -> SVG {
        guard size != s else { return self }

        let sx = s.width / size.width
        let sy = s.height / size.height

        var copy = self
        copy.commands.insert(.scale(sx: sx, sy: sy), at: 0)
        copy.size = s
        return copy
    }

    func scaled(_ factor: CGFloat) -> SVG {
        scaled(x: factor, y: factor)
    }

    func scaled(x: CGFloat, y: CGFloat) -> SVG {
        var copy = self

        copy.commands.insert(.scale(sx: x, sy: y), at: 0)
        copy.size = CGSize(
            width: size.width * x,
            height: size.height * y
        )
        return copy
    }

    func translated(tx: CGFloat, ty: CGFloat) -> SVG {
        var copy = self
        copy.commands.insert(.translate(tx: tx, ty: ty), at: 0)
        return copy
    }

    func expanded(_ padding: CGFloat) -> SVG {
        expanded(top: padding, left: padding, bottom: padding, right: padding)
    }

    func expanded(top: CGFloat = 0,
                  left: CGFloat = 0,
                  bottom: CGFloat = 0,
                  right: CGFloat = 0) -> SVG {
        var copy = self
        copy.commands.insert(.translate(tx: left, ty: top), at: 0)
        copy.size.width += left + right
        copy.size.height += top + bottom
        return copy
    }
}

extension SVG {

    init(dom: DOM.SVG, options: Options) {
        self.size = CGSize(width: dom.width, height: dom.height)

        //To create the draw commands;
        // - XML is parsed into DOM.SVG
        // - DOM.SVG is converted into a LayerTree
        // - LayerTree is converted into RenderCommands
        // - RenderCommands are performed by Renderer (drawn to CGContext)
        let layer = LayerTree.Builder(svg: dom).makeLayer()
        let generator = LayerTree.CommandGenerator(provider: CGProvider(),
                                                   size: LayerTree.Size(dom.width, dom.height),
                                                   options: options)

        let optimizer = LayerTree.CommandOptimizer<CGTypes>()
        commands = optimizer.optimizeCommands(
            generator.renderCommands(for: layer)
        )
    }
}

@available(*, unavailable, renamed: "SVG")
public enum Image { }

#else

public struct SVG {
    public let size: CGSize

    init(dom: DOM.SVG, options: Options) {
        size = CGSize(width: dom.width, height: dom.height)
    }

    public struct Options: OptionSet {
        public let rawValue: Int
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let hideUnsupportedFilters = Options(rawValue: 1 << 0)

        public static let `default`: Options = []
    }
}

public extension SVG {

    func pngData(size: CGSize? = nil, scale: CGFloat = 1) -> Data? {
        return nil
    }

    func jpegData(size: CGSize? = nil, scale: CGFloat = 1, compressionQuality quality: CGFloat = 1) -> Data? {
        return nil
    }

    func pdfData(size: CGSize? = nil) -> Data? {
        return nil
    }

    static func pdfData(fileURL url: URL, size: CGSize? = nil) throws -> Data {
        throw DOM.Error.missing("not implemented")
    }

    func sized(_ s: CGSize) -> SVG { self }

    func scaled(_ factor: CGFloat) -> SVG { self }

    func scaled(x: CGFloat, y: CGFloat) -> SVG { self }

    func translated(tx: CGFloat, ty: CGFloat) -> SVG { self }

    func expanded(_ padding: CGFloat) -> SVG { self }

    func expanded(top: CGFloat = 0,
                  left: CGFloat = 0,
                  bottom: CGFloat = 0,
                  right: CGFloat = 0) -> SVG { self }
}
#endif

public extension SVG {

    mutating func size(_ s: CGSize) {
        self = sized(s)
    }

    mutating func scale(_ factor: CGFloat) {
        self = scaled(factor)
    }

    mutating func scale(x: CGFloat, y: CGFloat) {
        self = scaled(x: x, y: y)
    }

    mutating func translate(tx: CGFloat, ty: CGFloat) {
        self = translated(tx: tx, ty: ty)
    }

    mutating func expand(_ padding: CGFloat) {
        self = expanded(padding)
    }

    mutating func expand(top: CGFloat = 0,
                         left: CGFloat = 0,
                         bottom: CGFloat = 0,
                         right: CGFloat = 0) {
        self = expanded(top: top, left: left, bottom: bottom, right: right)
    }
}
