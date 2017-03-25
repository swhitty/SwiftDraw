//
//  ImageView.swift
//  SwiftVG
//
//  Created by Simon Whitty on 25/3/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

import UIKit
    
extension UIImage {
    
    class func svgNamed(_ name: String,
                        in bundle: Bundle = Bundle.main) -> UIImage? {
        guard let svg = ImageRenderer.svgNamed(name, in: bundle) else { return nil }
        return image(from: svg)
    }
    
    class func image(from svg: DOM.Svg) -> UIImage {
        let size = CGSize(width: svg.width, height: svg.height)
        let f = UIGraphicsImageRendererFormat.default()
        f.opaque = true
        f.prefersExtendedRange = false
        let r = UIGraphicsImageRenderer(size: size, format: f)
        
        return r.image{
            ImageRenderer().draw(svg, in: $0.cgContext)
        }
    }
    
    

}



