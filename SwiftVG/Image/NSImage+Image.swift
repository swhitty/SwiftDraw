//
//  Image+NSImage.swift
//  SwiftVG
//
//  Created by Simon Whitty on 24/5/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

import AppKit

extension NSImage {
    public class func svgNamed(_ name: String,
                               in bundle: Bundle = Bundle.main) -> NSImage? {
        
        guard let url = bundle.url(forResource: name, withExtension: nil),
            let image = Image(fileURL: url) else {
                return nil
        }
        
        return image.rasterize()
    }
}

public extension Image {
    func rasterize() -> NSImage {
        return rasterize(with: size)
    }
    
    func rasterize(with size: CGSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        
        if let ctx = NSGraphicsContext.current()?.cgContext {
            let renderer = CoreGraphicsRenderer(context: ctx)
            renderer.perform(commands)
        }
        
        image.unlockFocus()
        return image
    }
}
