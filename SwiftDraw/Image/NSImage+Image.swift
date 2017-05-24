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
    public class func svgNamed(_ name: String, in bundle: Bundle = Bundle.main) -> NSImage? {
        return Image(named: name, in: bundle)?.rasterize()
    }
}

public extension Image {
    func rasterize() -> NSImage {
        return rasterize(with: size)
    }
    
    func rasterize(with size: CGSize) -> NSImage {
        let imageSize = NSSize(width: size.width, height: size.height)
        
        let image = NSImage(size: imageSize, flipped: true) { rect in
            guard let ctx = NSGraphicsContext.current()?.cgContext else { return false }
            ctx.draw(self, in: CGRect(x: 0, y: 0, width: rect.size.width, height: rect.size.height))
            return true
        }
        
        return image
    }
}
