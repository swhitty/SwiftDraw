import Foundation
import Subprocess
import Synchronization
import System

struct ToolError: Error, CustomStringConvertible {
    var description: String
    init(_ description: String) { self.description = description }
}

struct ProcessOutput {
    var success: Bool
    var status: String
    var stdout: String
    var stderr: String

    /// The most useful line of stderr (or stdout) for explaining a failure.
    var reason: String {
        let lines = (stderr + "\n" + stdout).split(whereSeparator: \.isNewline).map {
            $0.trimmingCharacters(in: .whitespaces)
        }.filter { !$0.isEmpty }
        let line =
            lines.first { $0.localizedCaseInsensitiveContains("error") || $0.hasPrefix("Failure") } ?? lines.first
            ?? status
        return line.count > 200 ? String(line.prefix(200)) + "…" : line
    }
}

/// Runs a program and collects its output.
func execute(_ executable: URL, _ arguments: [String], in directory: URL? = nil) async throws -> ProcessOutput {
    try await execute(.path(FilePath(executable.path)), arguments, in: directory)
}

func execute(_ executable: Executable, _ arguments: [String], in directory: URL? = nil) async throws -> ProcessOutput {
    let result = try await run(
        executable,
        arguments: Arguments(arguments),
        workingDirectory: directory.map { FilePath($0.path) },
        output: .string(limit: 16 << 20),
        error: .string(limit: 16 << 20)
    )
    return ProcessOutput(
        success: result.terminationStatus.isSuccess,
        status: "\(result.terminationStatus)",
        stdout: result.standardOutput,
        stderr: result.standardError
    )
}

/// Runs a program that must succeed, returning trimmed stdout. On failure prints its output and throws.
@discardableResult
func check(
    _ executable: Executable,
    _ arguments: [String],
    in directory: URL? = nil,
    label: String
) async throws -> String {
    let output = try await execute(executable, arguments, in: directory)
    guard output.success else {
        FileHandle.standardError.write(Data((output.stdout + output.stderr).utf8))
        throw ToolError("\(label) failed (\(output.status))")
    }
    return output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
}

@discardableResult
func git(_ args: [String], in dir: URL) async throws -> String {
    try await check(.name("git"), args, in: dir, label: "git \(args.first ?? "")")
}

func step(_ text: String) {
    FileHandle.standardError.write(Data("→ \(text)…\n".utf8))
}

/// Prints a progress counter on stderr when it's a terminal.
final class Progress: Sendable {
    private let label: String
    private let total: Int
    private let done = Mutex(0)
    private let isTTY = isatty(STDERR_FILENO) != 0

    init(_ label: String, total: Int) {
        self.label = label
        self.total = total
    }

    func tick() {
        guard isTTY else { return }
        let d = done.withLock {
            $0 += 1; return $0
        }
        let line = d >= total ? "\r\u{1B}[K" : "\r\(label)… \(d)/\(total)\u{1B}[K"
        FileHandle.standardError.write(Data(line.utf8))
    }
}

/// Maps `items` with at most `limit` running at once, keeping their order.
func concurrentMap<T: Sendable, R: Sendable>(
    _ items: [T],
    limit: Int = ProcessInfo.processInfo.activeProcessorCount,
    _ transform: @escaping @Sendable (T) async -> R
) async -> [R] {
    await withTaskGroup(of: (Int, R).self) { group in
        var results = [R?](repeating: nil, count: items.count)
        var next = 0
        func add() {
            let i = next, item = items[i]
            group.addTask { (i, await transform(item)) }
            next += 1
        }
        while next < min(limit, items.count) { add() }
        for await (i, r) in group {
            results[i] = r
            if next < items.count { add() }
        }
        return results.map { $0! }
    }
}
