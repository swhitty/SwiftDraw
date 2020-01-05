//
//  LayerTree.Image.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 3/6/17.
//  Copyright 2020 WhileLoop Pty Ltd. All rights reserved.
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

extension LayerTree {
  enum Image: Equatable {
    case jpeg(data: Data)
    case png(data: Data)
    
    init?(mimeType: String, data: Data) {
      guard data.count > 0 else { return nil }
      
      switch mimeType {
      case "image/png":
        self = .png(data: data)
      case "image/jpeg":
        self = .jpeg(data: data)
      case "image/jpg":
        self = .jpeg(data: data)
      default:
        return nil
      }
    }
  }
}
