//
//  URL+Data.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 28/2/17.
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

extension URL {

  init?(maybeData string: String) {
    guard string.hasPrefix("data:") else {
      self.init(string: string)
      return
    }

    var removed =  string.replacingOccurrences(of: "\t", with: "")
    removed =  removed.replacingOccurrences(of: "\n", with: "")
    removed =  removed.replacingOccurrences(of: " ", with: "")

    self.init(string: removed)
  }


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

    let mime = String(txt[schemeRange.upperBound..<mimeRange.lowerBound])
    let base64 = String(txt[encodingRange.upperBound..<txt.endIndex])

    guard !mime.isEmpty, !base64.isEmpty,
      let data = Data(base64Encoded: base64) else {
        return nil
    }

    return (mime, data)
  }
}
