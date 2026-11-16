import Foundation
import SwiftDrawDiffCore

setvbuf(stdout, nil, _IOLBF, 0)

let options: Options
do {
    options = try Options.parse(Array(CommandLine.arguments.dropFirst()))
} catch {
    FileHandle.standardError.write(Data("swiftdraw-diff: \(error)\n\n\(Options.usage)\n".utf8))
    exit(2)
}

do {
    let session = try await Session.start(options)
    switch options.command {
    case .report: exit(try await Reporter(session: session).run())
    case .compare: exit(try await Comparer(session: session).run())
    }
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(2)
}
