//
//  LayerTree.Layer.swift
//  SwiftDraw
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

extension LayerTree {
  final class Layer: Equatable {
    var contents: [Contents] = []
    var opacity: Float = 1.0
    var transform: [Transform] = []
    var clip: [Shape] = []
    var mask: Layer?
    
    enum Contents: Equatable {
      case shape(Shape, StrokeAttributes, FillAttributes)
      case image(Image)
      case text(String, Point, TextAttributes)
      case layer(Layer)
    }
    
    func appendContents(_ contents: Contents) {
      switch contents {
      case .layer(let l):
        guard l.contents.isEmpty == false else { return }
        
        //if layer is simple, we can ignore all other properties
        if let simple = l.simpleContents {
          self.contents.append(simple)
        } else {
          self.contents.append(.layer(l))
        }
      default:
        self.contents.append(contents)
      }
    }
    
    var simpleContents: Contents? {
      guard self.contents.count == 1,
        let first = self.contents.first,
        opacity == 1.0,
        transform == [],
        clip == [],
        mask == nil else { return nil }
      
      return first
    }
    
    static func ==(lhs: Layer, rhs: Layer) -> Bool {
      return lhs.contents == rhs.contents &&
        lhs.opacity == rhs.opacity &&
        lhs.transform == rhs.transform &&
        lhs.clip == rhs.clip &&
        lhs.mask == rhs.mask
    }
  }
  
  struct StrokeAttributes: Equatable {
    var color: Color
    var width: Float
    var cap: LineCap
    var join: LineJoin
    var miterLimit: Float
  }
  
  struct FillAttributes: Equatable {
    var fill: Fill = .color(.none)
    var opacity: Float = 1.0
    var rule: FillRule
    
    init(color: Color, rule: FillRule) {
      self.fill = .color(color)
      self.rule = rule
    }
    
    init(pattern: Pattern, rule: FillRule, opacity: Float) {
      self.fill = .pattern(pattern)
      self.rule = rule
      self.opacity = opacity
    }
    
    init(gradient: Gradient, rule: FillRule, opacity: Float) {
      self.fill = .gradient(gradient)
      self.rule = rule
      self.opacity = opacity
    }
    
    enum Fill: Equatable {
      case color(Color)
      case pattern(Pattern)
      case gradient(Gradient)
    }
  }
  
  struct TextAttributes: Equatable {
    var color: Color
    var fontName: String
    var size: Float
  }
}
