//
//  LogSink.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 26/8/26.
//  Copyright 2026 Simon Whitty
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

/// Destination for the diagnostic messages emitted while parsing and rendering.
///
/// Messages are written to the standard streams by default, matching the output
/// of previous versions. `SwiftDraw.Log` is the public facade of this sink.
package enum LogSink {

    package enum Level: Int, Comparable, Hashable, CaseIterable, Sendable {
        case info
        case warning
        case error

        package static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    package typealias Handler = @Sendable (Level, String) -> Void

    /// Receives every message emitted while parsing and rendering.
    ///
    /// Defaults to `standardStreams()`. Assign once during startup; the property
    /// is safe to access from multiple threads but messages emitted while it is
    /// being replaced may reach either handler.
    package static var handler: Handler {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _handler
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _handler = newValue
        }
    }

    /// Writes `info` messages to standard output and everything else to standard error.
    /// - Parameter minimumLevel: messages below this level are discarded.
    package static func standardStreams(minimumLevel: Level = .info) -> Handler {
        makeHandler(
            minimumLevel: minimumLevel,
            standardOutput: { print($0) },
            standardError: { print($0, to: &.standardError) }
        )
    }

    package static func makeHandler(
        minimumLevel: Level,
        standardOutput: @escaping @Sendable (String) -> Void,
        standardError: @escaping @Sendable (String) -> Void
    ) -> Handler {
        { level, message in
            guard level >= minimumLevel else { return }
            switch level {
            case .info:
                standardOutput(message)
            case .warning:
                standardError("Warning: \(message)")
            case .error:
                standardError(message)
            }
        }
    }

    private nonisolated(unsafe) static var _handler: Handler = standardStreams()
    private static let lock = NSLock()
}

package extension LogSink {

    /// Emits a message that forms part of the expected output, such as the
    /// alignment insets reported by the SF Symbol renderer.
    static func info(_ message: String) {
        handler(.info, message)
    }

    /// Emits a message about content that was rendered in a degraded way.
    /// The `Warning:` prefix is applied by the handler.
    static func warning(_ message: String) {
        handler(.warning, message)
    }

    /// Emits a message about content that could not be parsed or encoded.
    static func error(_ message: String) {
        handler(.error, message)
    }
}
