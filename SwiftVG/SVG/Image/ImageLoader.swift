//
//  File.swift
//  SwiftVG
//
//  Created by Simon Whitty on 25/3/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

import Foundation

struct ImageLoader {
    
    static func svgNamed(_ name: String,
                         in bundle: Bundle = Bundle.main) -> DOM.Svg? {
        
        guard let url = bundle.url(forResource: name, withExtension: nil) else {
            return nil
        }
        
        return svgUrl(url)
    }
    
    static func svgUrl(_ url: URL) -> DOM.Svg? {
        guard let element = try? XML.SAXParser.parse(contentsOf: url),
              let svg = try? XMLParser().parseSvg(element) else {
                return nil
        }
        
        return svg
    }
    
}

