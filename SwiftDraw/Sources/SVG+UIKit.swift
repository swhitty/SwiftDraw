//
//  SVG+UIKit.swift
//  SwiftDraw
//
//  Created by Daniel Sincere on 25/10/14.
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

#if canImport(UIKit)
public import UIKit

public extension UIGraphicsImageRendererContext {
  func draw(_ svg: SVG, in rect: CGRect? = nil)  {
    self.cgContext.draw(svg, in: rect )
  }
  
  func draw(_ svg: SVG, in rect: CGRect, byTiling: Bool) {
    self.cgContext.draw(svg, in: rect, byTiling: byTiling)
  }
  
  func draw(
    _ svg: SVG,
    in rect: CGRect,
    capInsets: (top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat),
    byTiling: Bool
  ) {
    self.cgContext.draw(svg, in: rect, capInsets: capInsets, byTiling: byTiling)
  }
}

#endif
