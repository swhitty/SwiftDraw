//
//  URL.swift
//  SwiftVG
//
//  Created by Simon Whitty on 28/2/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

import Foundation

extension URL {
    var isDataURL: Bool {
        return scheme == "data"
    }
    
    var decodedData: (mimeType: String, data: Data)? {
        let txt = absoluteString
        guard let schemeRange = txt.range(of: "data:"),
            let mimeRange = txt.range(of: ";", options: [], range: schemeRange.upperBound..<txt.endIndex),
            let encodingRange = txt.range(of: "base64,", options: [], range: mimeRange.upperBound..<txt.endIndex) else {
                return nil
        }
        
        let mime = txt.substring(with: schemeRange.upperBound..<mimeRange.lowerBound)
        let base64 = txt.substring(with: encodingRange.upperBound..<txt.endIndex)
        
        guard mime.characters.count > 0,
              base64.characters.count > 0,
              let data = Data(base64Encoded: base64) else {
            return nil
        }

        return (mime, data)
    }
}
