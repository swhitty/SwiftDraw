//
//  Renderer.CGText+Path.swift
//  SwiftDraw
//
//  Created by swhitty1 on 28/6/21.
//  Copyright © 2021 WhileLoop Pty Ltd. All rights reserved.
//

import Foundation

extension CGTextRenderer {

  func createOrGetPath(_ path: [LayerTree.Shape]) -> String {
    guard path.count == 1 else {
      fatalError("not yet supported")
    }
    let code = renderPath(from: path[0])
    return createOrGetPath(code)
  }

  func getSimpleRect(from path: [LayerTree.Shape]) -> String? {
    guard
      path.count == 1,
      case let .rect(rect, radii) = path[0],
      radii == .zero else {
      return nil
    }
  
    return renderRect(from: rect)
  }

  func getSimpleEllipse(from path: [LayerTree.Shape]) -> String? {
    guard
      path.count == 1,
      case let .ellipse(rect) = path[0] else {
      return nil
    }
  
    return renderRect(from: rect)
  }

  func getSimpleLine(from path: [LayerTree.Shape]) -> [LayerTree.Point]? {
    guard
      path.count == 1,
      case let .line(points) = path[0] else {
      return nil
    }
  
    return points
  }
  
  func renderPath(from shape: LayerTree.Shape) -> String {
    switch shape {
    case .line(let points):
      return renderLinePath(between: points)
      
    case .rect(let frame, let radii):
      return renderRectPath(frame: frame, radii: radii)
      
    case .ellipse(let frame):
      return renderEllipsePath(frame: frame)
      
    case .path(let path):
      return renderPath(from: path)
      
    case .polygon(let points):
      return renderPolygonPath(between: points)
    }
  }
  
  func renderFloat(from float: LayerTree.Float) -> LayerTree.Float {
    return float
  }
  
  private func renderPoint(from point: LayerTree.Point) -> String {
    return "CGPoint(x: \(point.x), y: \(point.y))"
  }
  
  private func renderSize(from size: LayerTree.Size) -> String {
    return "CGSize(width: \(size.width), height: \(size.height))"
  }
  
  private func renderRect(from rect: LayerTree.Rect) -> String {
    return "CGRect(x: \(rect.x), y: \(rect.y), width: \(rect.width), height: \(rect.height))"
  }
  
  func renderLinePath(between points: [LayerTree.Point]) -> String {
    """
    let path1 = CGMutablePath()
    path1.addLines(between: [
    \(points, indent: 2)
    ])
    """
  }
  
  func renderRectPath(frame: LayerTree.Rect, radii: LayerTree.Size) -> String {
    """
    let path1 = CGPath(
      roundedRect: \(renderRect(from: frame)),
      cornerWidth: \(renderFloat(from: radii.width)),
      cornerHeight: \(renderFloat(from: radii.height)),
      transform: nil
    )
    """
  }
  
  func renderPolygonPath(between points: [LayerTree.Point]) -> String {
    var lines: [String] = ["let path1 = CGMutablePath()"]
    lines.append("path1.addLines(between: [")
    for p in points {
      lines.append("  \(renderPoint(from: p)),")
    }
    lines.append("])")
    lines.append("path1.closeSubpath()")
    return lines.joined(separator: "\n")
  }
  
  func renderEllipsePath(frame: LayerTree.Rect) -> String {
    """
    let path1 = CGPath(
      ellipseIn: \(renderRect(from: frame)),
      transform: nil
    )
    """
  }

  func renderPath(from path: LayerTree.Path) -> String {
      Self.renderPath(from: path)
  }

  static func renderPath(from path: LayerTree.Path) -> String {
    func renderPoint(from point: LayerTree.Point) -> String {
      return "CGPoint(x: \(point.x), y: \(point.y))"
    }

    var lines: [String] = ["let path1 = CGMutablePath()"]
    for s in path.segments {
      switch s {
      case .move(let p):
        lines.append("path1.move(to: \(renderPoint(from: p)))")
      case .line(let p):
        lines.append("path1.addLine(to: \(renderPoint(from: p)))")
      case .cubic(let p, let cp1, let cp2):
        lines.append("""
        path1.addCurve(to: \(renderPoint(from: p)),
                       control1: \(renderPoint(from: cp1)),
                       control2: \(renderPoint(from: cp2)))
        """)
      case .close:
        lines.append("path1.closeSubpath()")
      }
    }
    return lines.joined(separator: "\n")
  }
}
