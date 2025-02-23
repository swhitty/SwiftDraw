//
//  MockRenderer.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 27/11/18.
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

import XCTest
@testable import SwiftDraw

final class MockRenderer: Renderer {
  
  typealias Types = LayerTreeTypes
  
  var operations = [String]()
  
  func pushState() {
    operations.append("pushState")
  }
  
  func popState() {
    operations.append("popState")
  }
  
  func pushTransparencyLayer() {
    operations.append("pushTransparencyLayer")
  }
  
  func popTransparencyLayer() {
    operations.append("popTransparencyLayer")
  }
  
  func concatenate(transform: LayerTree.Transform) {
    operations.append("concatenateTransform")
  }
  
  func translate(tx: LayerTree.Float, ty: LayerTree.Float) {
    operations.append("translate")
  }
  
  func rotate(angle: LayerTree.Float) {
    operations.append("rotate")
  }
  
  func scale(sx: LayerTree.Float, sy: LayerTree.Float) {
    operations.append("scale")
  }
  
  func setFill(color: LayerTree.Color) {
    operations.append("setFillColor")
  }
  
  func setFill(pattern: LayerTree.Pattern) {
    operations.append("setFillPattern")
  }
  
  func setStroke(color: LayerTree.Color) {
    operations.append("setStrokeColor")
  }
  
  func setLine(width: LayerTree.Float) {
    operations.append("setLineWidth")
  }
  
  func setLine(cap: LayerTree.LineCap) {
    operations.append("setLineCap")
  }
  
  func setLine(join: LayerTree.LineJoin) {
    operations.append("setLineJoin")
  }
  
  func setLine(miterLimit: LayerTree.Float) {
    operations.append("setLineMiterLimit")
  }

  func setClip(path: [LayerTree.Shape], rule: LayerTree.FillRule) {
    operations.append("setClip")
  }
  
  func setClip(mask: [AnyHashable], frame: LayerTree.Rect) {
    operations.append("setClipMask")
  }
  
  func setAlpha(_ alpha: LayerTree.Float) {
    operations.append("setAlpha")
  }
  
  func setBlend(mode: LayerTree.BlendMode) {
    operations.append("setBlendMode")
  }
  
  func stroke(path: [LayerTree.Shape]) {
    operations.append("strokePath")
  }

  func clipStrokeOutline(path: [LayerTree.Shape]) {
    operations.append("clipStrokeOutline")
  }
  
  func fill(path: [LayerTree.Shape], rule: LayerTree.FillRule) {
    operations.append("fillPath")
  }
  
  func draw(image: LayerTree.Image, in rect: LayerTree.Rect) {
    operations.append("drawImage")
  }

  func draw(linear gradient: LayerTree.Gradient, from start: LayerTree.Point, to end: LayerTree.Point) {
    operations.append("drawLinearGradient")
  }

  func draw(radial gradient: LayerTree.Gradient, startCenter: LayerTree.Point, startRadius: LayerTree.Float, endCenter: LayerTree.Point, endRadius: LayerTree.Float) {
    operations.append("drawRadialGradient")
  }
}
