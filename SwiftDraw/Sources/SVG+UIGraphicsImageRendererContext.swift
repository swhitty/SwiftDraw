//
//  SVG+UIGraphicsImageRendererContext.swift
//  SwiftDraw
//
//  Created by Daniel on 10/14/25.
//

#if canImport(UIKit)
public import CoreGraphics
public import UIKit

public extension UIGraphicsImageRendererContext {
  
  func draw(_ svg: SVG, in rect: CGRect? = nil)  {
    self.cgContext.draw(svg, in: rect)
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
