import Foundation

actor ShellRunner {

    // MARK: - Streaming execution

    /// - Parameter allowingFailure: When true, non-zero exit codes are logged but do not throw.
    ///   Use this for Wine/winetricks/Steam which routinely exit non-zero even on success.
    func stream(
        _ command: String,
        args: [String] = [],
        env: [String: String] = [:],
        allowingFailure: Bool = false
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let process = Process()
            let outPipe = Pipe()
            let errPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: command)
            process.arguments = args
            process.environment = mergedEnv(env)
            process.standardOutput = outPipe
            process.standardError = errPipe

            let q = DispatchQueue(label: "smoke.shellrunner.io")

            func yield(_ data: Data, prefix: String = "") {
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                let lines = text.components(separatedBy: "\n")
                for line in lines where !line.isEmpty {
                    continuation.yield(prefix + line)
                }
            }

            outPipe.fileHandleForReading.readabilityHandler = { handle in
                q.async { yield(handle.availableData) }
            }
            errPipe.fileHandleForReading.readabilityHandler = { handle in
                // Wine/winetricks flood stderr with fixme:/err: noise — label it but keep it subtle
                q.async { yield(handle.availableData, prefix: "[wine] ") }
            }

            process.terminationHandler = { p in
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                q.async {
                    yield(outPipe.fileHandleForReading.readDataToEndOfFile())
                    yield(errPipe.fileHandleForReading.readDataToEndOfFile(), prefix: "[wine] ")
                    if p.terminationStatus == 0 || allowingFailure {
                        if p.terminationStatus != 0 {
                            continuation.yield("(exited \(p.terminationStatus) — continuing)")
                        }
                        continuation.finish()
                    } else {
                        let cmd = ([command] + args).joined(separator: " ")
                        continuation.finish(throwing: AppError.processLaunchFailed(
                            command: cmd, code: p.terminationStatus
                        ))
                    }
                }
            }

            do {
                try process.run()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }

    // MARK: - Fire-and-forget execution

    func run(
        _ command: String,
        args: [String] = [],
        env: [String: String] = [:],
        allowingFailure: Bool = false
    ) async throws -> String {
        var output = ""
        for try await line in stream(command, args: args, env: env, allowingFailure: allowingFailure) {
            output += line + "\n"
        }
        return output
    }

    // MARK: - Binary detection

    static func locate(_ binary: String, hints: [String] = []) -> String? {
        let candidates: [String] = hints + [
            "/opt/homebrew/bin/\(binary)",
            "/usr/local/bin/\(binary)",
            "/usr/bin/\(binary)",
            "/Applications/Game Porting Toolkit.app/Contents/Resources/wine/bin/\(binary)",
            "/Applications/Whisky.app/Contents/Resources/Libraries/Wine/bin/\(binary)",
        ]

        // Also check $PATH
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            for dir in pathEnv.components(separatedBy: ":") {
                let full = "\(dir)/\(binary)"
                if FileManager.default.isExecutableFile(atPath: full) {
                    return full
                }
            }
        }

        return candidates.first {
            FileManager.default.isExecutableFile(atPath: $0)
        }
    }

    // MARK: - Helpers

    private func mergedEnv(_ overrides: [String: String]) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        for (k, v) in overrides { env[k] = v }
        return env
    }
}
