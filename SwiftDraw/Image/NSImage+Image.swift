//
//  Image+NSImage.swift
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
