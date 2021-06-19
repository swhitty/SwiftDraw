//
//  Image+CGText.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 15/6/21.
//  Copyright 2021 Simon Whitty
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

public extension CGTextRenderer {

  static func render(named name: String, in bundle: Bundle = Bundle.main) -> String? {
    guard let url = bundle.url(forResource: name, withExtension: nil) else { return nil }
    return render(fileURL: url)
  }

  static func render(fileURL: URL) -> String? {
    guard let svg = try? DOM.SVG.parse(fileURL: fileURL) else {
      return nil
    }
    return cgCodeText(url: fileURL, svg: svg)
  }

  private static func cgCodeText(url: URL, svg: DOM.SVG) -> String {
    let layer = LayerTree.Builder(svg: svg).makeLayer()
    let size = LayerTree.Size(svg.width, svg.height)
    let generator = LayerTree.CommandGenerator(provider: CGTextProvider(),
                                               size: size)
    
    let optimizer = LayerTree.CommandOptimizer<CGTextTypes>(options: [.skipRedundantState, .skipInitialSaveState])
    let commands = optimizer.optimizeCommands(
      generator.renderCommands(for: layer)
    )

    let identifier = url.lastPathComponent
      .replacingOccurrences(of: ".\(url.pathExtension)", with: "")
      .replacingOccurrences(of: "-", with: " ")
      .capitalized
      .replacingOccurrences(of: " ", with: "")

    let renderer = CGTextRenderer(name:"svg\(identifier)", size: size)
    renderer.perform(commands)
    
    return renderer.makeText()
  }
}
