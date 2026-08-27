//
//  Log.swift
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

import SwiftDrawDOM

/// Destination for the diagnostic messages emitted while parsing and rendering.
///
/// Messages are written to the standard streams by default, matching the output
/// of previous versions. Embedders can route them into their own logging system:
///
/// ```swift
/// Log.handler = { level, message in
///     logger.log(level: level == .error ? .error : .warning, "\(message)")
/// }
/// ```
///
/// Or silence them entirely:
///
/// ```swift
/// Log.handler = Log.silent
/// ```
public enum Log {

    public enum Level: Int, Comparable, Hashable, CaseIterable, Sendable {
        case info
        case warning
        case error

        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    public typealias Handler = @Sendable (Level, String) -> Void

    /// Receives every message emitted while parsing and rendering.
    ///
    /// Defaults to `standardStreams()`. Assign once during startup; the property
    /// is safe to access from multiple threads but messages emitted while it is
    /// being replaced may reach either handler.
    public static var handler: Handler {
        get {
            let handler = LogSink.handler
            return { handler($0.sink, $1) }
        }
        set {
            LogSink.handler = { newValue(Level($0), $1) }
        }
    }

    /// Writes `info` messages to standard output and everything else to standard error.
    ///
    /// `warning` messages are prefixed with `Warning:`.
    /// - Parameter minimumLevel: messages below this level are discarded.
    public static func standardStreams(minimumLevel: Level = .info) -> Handler {
        let handler = LogSink.standardStreams(minimumLevel: minimumLevel.sink)
        return { handler($0.sink, $1) }
    }

    /// Discards every message.
    public static let silent: Handler = { _, _ in }
}

public extension Log {

    /// Emits a message that forms part of the expected output.
    static func info(_ message: String) {
        LogSink.info(message)
    }

    /// Emits a message about content that was handled in a degraded way.
    /// The `Warning:` prefix is applied by the handler.
    static func warning(_ message: String) {
        LogSink.warning(message)
    }

    /// Emits a message about content that could not be handled.
    static func error(_ message: String) {
        LogSink.error(message)
    }
}

private extension Log.Level {

    var sink: LogSink.Level {
        switch self {
        case .info: .info
        case .warning: .warning
        case .error: .error
        }
    }

    init(_ level: LogSink.Level) {
        switch level {
        case .info: self = .info
        case .warning: self = .warning
        case .error: self = .error
        }
    }
}
