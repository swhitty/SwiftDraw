//
//  CommandLine.Arguments.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 7/12/18.
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

extension CommandLine {

  enum Modifier: String {
    case format
    case output
    case size
    case scale

    static func parse(from string: String) -> Modifier? {
      guard string.hasPrefix("--") else {
        return nil
      }

      return Modifier(rawValue: String(string.dropFirst(2)))
    }
  }

  static func parseModifiers(from args: [String]) throws -> [Modifier: String] {
    var args = args
    var modifiers = [Modifier: String]()
    while let pair = args.takePair() {
      if let modifier = Modifier.parse(from: pair.0), modifiers.keys.contains(modifier) == false  {
        modifiers[modifier] = pair.1
      } else {
        throw Error.invalid
      }
    }

    guard args.isEmpty else {
      throw CommandLine.Error.invalid
    }

    return modifiers
  }

  public enum Error: Swift.Error {
    case invalid
  }
}

private extension Array where Element == String {

  mutating func takePair() -> (String, String)? {
    guard count > 1 else {
      return nil
    }

    let pair = (self[0], self[1])
    removeFirst(2)
    return pair
  }
}
