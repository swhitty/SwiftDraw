//
//  Renderer.Types.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 14/6/17.
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

extension LayerTree {
  
  // Optimize a sequence of commands removing redundant entries
  
  final class CommandOptimizer<T: RendererTypes> {

    private var options: OptimizerOptions
    private var state: Stack<State>

    init(options: OptimizerOptions = .skipRedundantState) {
      self.options = options
      self.state = Stack(root: State())
    }

    func filterStateCommand(for command: RendererCommand<T>) -> RendererCommand<T>? {
      switch command {
      case .setFill(let color):
        if state.top.fill != color {
          state.top.fill = color
        } else {
          return nil
        }
      case .setStroke(let color):
        if state.top.stroke != color {
          state.top.stroke = color
        } else {
          return nil
        }
      case .setLineCap(let cap):
        if state.top.lineCap != cap {
          state.top.lineCap = cap
        } else {
          return nil
        }
      case .setLineJoin(let join):
        if state.top.lineJoin != join {
          state.top.lineJoin = join
        } else {
          return nil
        }
      case .setLine(width: let width):
        if state.top.lineWidth != width {
          state.top.lineWidth = width
        } else {
          return nil
        }
      case .setLineMiter(limit: let limit):
        if state.top.lineMiter != limit {
          state.top.lineMiter = limit
        } else {
          return nil
        }
      case .setBlend(mode: let mode):
        if state.top.blendMode != mode {
          state.top.blendMode = mode
        } else {
          return nil
        }
      case .pushState:
        state.push(state.top)
      case .popState:
        state.pop()
      default: break
      }
      
      return command
    }
    
    func optimizeCommands(_ commands: [RendererCommand<T>]) -> [RendererCommand<T>] {
      state = Stack<State>(root: State())

      var commands = commands

      if options.contains(.skipInitialSaveState),
         case .pushState = commands.first,
         case .popState = commands.last {
        commands = commands
          .dropFirst()
          .dropLast()
      }

      if options.contains(.skipRedundantState) {
        state = Stack(root: State())
        commands = commands.compactMap { filterStateCommand(for: $0) }
      }

      return commands
    }
    
    struct State {
      var fill: T.Color?
      var stroke: T.Color?
      var lineCap: T.LineCap?
      var lineJoin: T.LineJoin?
      var lineWidth: T.Float?
      var lineMiter: T.Float?
      var blendMode: T.BlendMode?
    }
  }
}

struct OptimizerOptions: OptionSet {
  let rawValue: Int
  init(rawValue: Int) {
    self.rawValue = rawValue
  }

  static let skipRedundantState = OptimizerOptions(rawValue: 1)
  static let skipInitialSaveState = OptimizerOptions(rawValue: 2)
}
