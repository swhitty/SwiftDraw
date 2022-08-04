//
//  XML.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 31/12/16.
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

extension XML {
    struct Formatter {

        var spaces: Int = 4

        func encodeRootElement(_ element: XML.Element) -> String {
            """
            <?xml version="1.0" encoding="UTF-8"?>
            \(encodeElement(element))
            """
        }

        func encodeElement(_ element: XML.Element, indent: Int = 0) -> String {
            let start = encodeElementStart(element, indent: indent)

            if let innerText = element.innerText {
                let end = encodeElementEnd(element, indent: 0)
                return "\(start)\(innerText)\(end)"
            } else if element.children.isEmpty {
                return String(start.dropLast()) + " />"
            } else {
                let end = encodeElementEnd(element, indent: indent)
                var lines = [start]
                for child in element.children {
                    lines.append(encodeElement(child, indent: indent + 1))
                }
                lines.append(end)
                return lines.joined(separator: "\n")
            }
        }

        private func encodeElementStart(_ element: XML.Element, indent: Int) -> String {
            let attributes = encodeAttributes(element.attributes)

            if attributes.isEmpty {
                return "\(encodeIndent(indent))<\(element.name)>"
            } else {
                return "\(encodeIndent(indent))<\(element.name) \(attributes)>"
            }
        }

        private func encodeElementEnd(_ element: XML.Element, indent: Int) -> String {
            "\(encodeIndent(indent))</\(element.name)>"
        }

        private func encodeAttributes(_ attributes: [String: String]) -> String {
            var atts = [String]()
            for key in attributes.keys.sorted(by: Self.attributeSort) {
                atts.append("\(key)=\"\(encodeString(attributes[key]!))\"")
            }
            return atts.joined(separator: " ")
        }

        private static func attributeSort(lhs: String, rhs: String) -> Bool {
            if lhs == "id" {
                return true
            } else if rhs == "id" {
                return false
            }
            return lhs < rhs
        }

        private func encodeString(_ string: String) -> String {
            string
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "\"", with: "&quot;")
                //.replacingOccurrences(of: "\'", with: "&apos;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
        }

        private func encodeIndent(_ indent: Int) -> String {
            String(repeating: " ", count: indent * spaces)
        }
    }
}
