//
//  Image+UIImage.swift
//  SwiftVG
//
//  Created by Simon Whitty on 24/5/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

import UIKit

extension UIImage {
    public class func svgNamed(_ name: String,
                               in bundle: Bundle = Bundle.main) -> UIImage? {
        
        guard let url = bundle.url(forResource: name, withExtension: nil),
              let image = Image(fileURL: url) else {
            return nil
        }
        
        return image.rasterize()
    }
}

public extension Image {
    func rasterize() -> UIImage {
        return rasterize(with: size)
    }
    
    func rasterize(with size: CGSize) -> UIImage {
        let f = UIGraphicsImageRendererFormat.default()
        f.opaque = false
        f.prefersExtendedRange = false
        let r = UIGraphicsImageRenderer(size: size, format: f)
        
        let commands = self.commands
        
        return r.image{
            let renderer = CoreGraphicsRenderer(context: $0.cgContext)
            renderer.perform(commands)
        }
    }
}
