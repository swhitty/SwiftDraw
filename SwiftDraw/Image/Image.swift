//
//  Image.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 24/5/17.
//  Copyright 2017 Simon Whitty
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
