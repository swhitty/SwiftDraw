//
//  TextOutputStream+StandardError.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 17/8/22.
//  Copyright 2022 Simon Whitty
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

package extension TextOutputStream where Self == StandardErrorStream {
    static var standardError: Self {
        get {
            StandardErrorStream.shared
        }
        set {
            StandardErrorStream.shared = newValue
        }
    }
}

package struct StandardErrorStream: TextOutputStream {

#if compiler(<6.0)
    fileprivate static var shared = StandardErrorStream()
#else
    nonisolated(unsafe)
    fileprivate static var shared = StandardErrorStream()
#endif

    package func write(_ string: String) {
        if #available(macOS 10.15.4, iOS 13.4, tvOS 13.4, watchOS 6.2, *) {
            try! FileHandle.standardError.write(contentsOf: string.data(using: .utf8)!)
        } else {
            FileHandle.standardError.write(string.data(using: .utf8)!)
        }
    }
}
