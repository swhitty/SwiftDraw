//
//  Image.swift
//  SwiftVG
//
//  Created by Simon Whitty on 24/5/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

import CoreGraphics
import Foundation


@objc(SVGImage)
public final class Image: NSObject {
    public let size: CGSize
    let commands: [RendererCommand<CoreGraphicsProvider>]
    
    public init?(fileURL url: URL) {
        guard let element = try? XML.SAXParser.parse(contentsOf: url),
              let svg = try? XMLParser().parseSvg(element) else {
                return nil
        }
        
        size = CGSize(width: svg.width, height: svg.height)
        commands = Builder().createCommands(for: svg,
                                            with: CoreGraphicsProvider(),
                                            isFlipped: Image.isFlipped)
    }
    
    public func render(in context: CGContext) {
        let renderer = CoreGraphicsRenderer(context: context)
        renderer.perform(commands)
    }
    
    //TODO: flip the context in the render method
    static var isFlipped: Bool {
        #if os(macOS)
            return false
        #else
            return true
        #endif
    }
}
