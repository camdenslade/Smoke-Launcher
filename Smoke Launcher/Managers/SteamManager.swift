import Foundation
import Combine

@MainActor
final class SteamManager: ObservableObject {
    @Published var pinnedBuild: SteamBuild?
    @Published var downloadProgress: Double = 0.0
    @Published var isInstalling: Bool = false
    @Published var isSteamRunning: Bool = false
    @Published var installLog: [String] = []
    @Published var error: AppError?

    private let shell = ShellRunner()

    init() {
        try? load()
    }

    // MARK: - Steam Installation

    func downloadAndInstall(into bottle: Bottle) async throws {
        isInstalling = true
        installLog = []
        defer { isInstalling = false }

        let installer = PathProvider.pinnedBuild.appendingPathComponent("SteamSetup.exe")
        let steamDir = bottle.prefixPath
            .appendingPathComponent("drive_c/Program Files (x86)/Steam")
        let steamuiDll = steamDir.appendingPathComponent("steamui.dll")

        // Step 1: Download installer
        if !FileManager.default.fileExists(atPath: installer.path) {
            appendLog("Downloading Steam installer...")
            try await downloadFile(from: SteamBuild.stableURL, to: installer)
            appendLog("Download complete.")
        } else {
            appendLog("Using cached Steam installer.")
        }

        let env = bottleEnv(bottle)

        // Step 2: Run installer (not silent — /S is unreliable under Wine)
        appendLog("Running Steam installer...")
        appendLog("A Steam installer window will appear — click through it. If Steam launches at the end and shows an error, dismiss it and return here.")
        for try await line in await shell.stream(
            bottle.winePath,
            args: [installer.path],
            env: env,
            allowingFailure: true
        ) {
            appendLog(line)
        }

        // Log Steam directory state post-installer
        logSteamDir(steamDir, label: "post-installer")

        // Between step 2 and 3: The installer may have launched Steam (via "Run Steam"
        // checkbox). That instance will fail with "steamui.dll not found" because the
        // client hasn't bootstrapped yet. Send -shutdown to kill it before we start our
        // own controlled bootstrap — Steam is single-instance, so two running copies
        // will fight each other.
        appendLog("Shutting down any installer-launched Steam...")
        let shutdownProcess = Process()
        shutdownProcess.executableURL = URL(fileURLWithPath: bottle.winePath)
        shutdownProcess.arguments = [steamDir.appendingPathComponent("Steam.exe").path, "-shutdown"]
        shutdownProcess.environment = mergedEnv(env)
        try? shutdownProcess.run()
        // Don't call waitUntilExit() — that blocks the MainActor. Just give it time.
        try await Task.sleep(nanoseconds: 4_000_000_000)
        appendLog("Shutdown done (running: \(shutdownProcess.isRunning))")

        // Step 3: First-run Steam bootstrap — Steam downloads steamui.dll and
        // the rest of its client on first launch. We must let this complete
        // BEFORE locking the version, otherwise steamui.dll won't exist.
        appendLog("steamui.dll exists: \(FileManager.default.fileExists(atPath: steamuiDll.path))")
        if !FileManager.default.fileExists(atPath: steamuiDll.path) {
            let steamExe = steamDir.appendingPathComponent("Steam.exe")
            appendLog("Steam.exe exists: \(FileManager.default.fileExists(atPath: steamExe.path))")
            appendLog("Steam.exe path: \(steamExe.path)")
            appendLog("Starting Steam for first-run update (downloading steamui.dll)...")
            appendLog("This may take a few minutes — Steam is downloading its components in the background.")

            let outPipe = Pipe()
            let bootstrapProcess = Process()
            bootstrapProcess.executableURL = URL(fileURLWithPath: bottle.winePath)
            // No -nostartupdialog — that flag can suppress the update download trigger
            bootstrapProcess.arguments = [steamExe.path, "-no-cef-sandbox", "-disable-gpu", "-silent"]
            var bootstrapEnv = mergedEnv(env)
            bootstrapEnv["WINEDEBUG"] = "err+all"  // Only real errors, not fixme noise
            bootstrapProcess.environment = bootstrapEnv
            bootstrapProcess.standardOutput = outPipe
            bootstrapProcess.standardError = outPipe

            // Stream bootstrap output in background (inherits MainActor — no Sendable issue)
            let outHandle = outPipe.fileHandleForReading
            Task { [weak self] in
                do {
                    for try await line in outHandle.bytes.lines {
                        self?.appendLog("[boot] \(line)")
                    }
                } catch { /* pipe closed on process exit — expected */ }
            }

            try bootstrapProcess.run()
            appendLog("Bootstrap pid=\(bootstrapProcess.processIdentifier) wine=\(bottle.winePath)")

            // Poll until steamui.dll appears (up to 8 minutes).
            // IMPORTANT: Steam self-restarts during bootstrap (first process downloads the
            // update and exits, second process installs it). Do NOT break when the original
            // process exits — keep polling until steamui.dll actually appears.
            let deadline = Date().addingTimeInterval(480)
            var pollCount = 0
            while !FileManager.default.fileExists(atPath: steamuiDll.path) {
                guard Date() < deadline else {
                    appendLog("Timed out. bootstrap running=\(bootstrapProcess.isRunning)")
                    logSteamDir(steamDir, label: "timeout")
                    searchForFile(named: "steamui.dll", under: steamDir)
                    break
                }
                try await Task.sleep(nanoseconds: 5_000_000_000)
                pollCount += 1
                let reason = bootstrapProcess.isRunning
                    ? "running"
                    : "exited(\(bootstrapProcess.terminationStatus),\(bootstrapProcess.terminationReason.rawValue))"
                appendLog("[\(pollCount)] bootstrap=\(reason) steamui.dll=\(FileManager.default.fileExists(atPath: steamuiDll.path))")
                // Log dir every 2 polls so we can see Steam writing files
                if pollCount % 2 == 0 { logSteamDir(steamDir, label: "poll-\(pollCount)") }
                // If original process exited AND dll still missing after 3 more polls, give up
                if !bootstrapProcess.isRunning && pollCount > 3 {
                    appendLog("Bootstrap exited and steamui.dll still absent after \(pollCount) polls — giving up.")
                    logSteamDir(steamDir, label: "after-exit")
                    searchForFile(named: "steamui.dll", under: steamDir)
                    break
                }
            }

            // Shut down any Steam still running (the self-restarted instance)
            if bootstrapProcess.isRunning { bootstrapProcess.terminate() }
            let shutdownAfter = Process()
            shutdownAfter.executableURL = URL(fileURLWithPath: bottle.winePath)
            shutdownAfter.arguments = [steamExe.path, "-shutdown"]
            shutdownAfter.environment = mergedEnv(env)
            try? shutdownAfter.run()
            try await Task.sleep(nanoseconds: 2_000_000_000)

            let dllFound = FileManager.default.fileExists(atPath: steamuiDll.path)
            appendLog("Bootstrap done. steamui.dll=\(dllFound)")
            guard dllFound else {
                throw AppError.steamDownloadFailed(statusCode: 0)  // steamui.dll never appeared
            }
        } else {
            appendLog("Steam components already present.")
        }

        // Step 4: Now it's safe to lock the version
        try pinAndLockVersion(in: bottle)

        let build = SteamBuild(
            version: "pinned",
            downloadURL: SteamBuild.stableURL,
            pinnedAt: Date(),
            installedPath: PathProvider.pinnedBuild
        )
        pinnedBuild = build
        try saveBuild(build)
        appendLog("Steam installed and version pinned.")
    }

    // MARK: - Version Pinning

    func pinAndLockVersion(in bottle: Bottle) throws {
        let cfgURL = PathProvider.steamCfg(in: bottle)
        let cfgDir = cfgURL.deletingLastPathComponent()

        let fm = FileManager.default
        if !fm.fileExists(atPath: cfgDir.path) {
            try fm.createDirectory(at: cfgDir, withIntermediateDirectories: true)
        }

        let content = """
        BootStrapperInhibitAll=Enable
        BootStrapperForceSelfUpdate=Disable
        """
        do {
            try content.write(to: cfgURL, atomically: true, encoding: .utf8)
        } catch {
            throw AppError.configWriteFailed(path: cfgURL.path, underlying: error)
        }
    }

    func isVersionPinned(in bottle: Bottle) -> Bool {
        let cfgURL = PathProvider.steamCfg(in: bottle)
        guard let content = try? String(contentsOf: cfgURL) else { return false }
        return content.contains("BootStrapperInhibitAll=Enable")
    }

    // MARK: - Steam Launch

    func launchSteamUI(in bottle: Bottle) async throws {
        let steamExe = bottle.prefixPath
            .appendingPathComponent("drive_c")
            .appendingPathComponent("Program Files (x86)")
            .appendingPathComponent("Steam")
            .appendingPathComponent("Steam.exe")

        guard FileManager.default.fileExists(atPath: steamExe.path) else {
            throw AppError.gameExeNotFound(path: steamExe.path)
        }
        let steamuiDll = steamExe.deletingLastPathComponent().appendingPathComponent("steamui.dll")
        appendLog("steamui.dll present: \(FileManager.default.fileExists(atPath: steamuiDll.path))")

        if !FileManager.default.fileExists(atPath: steamuiDll.path) {
            // steam.cfg with BootStrapperInhibitAll was written from a previous failed run.
            // It blocks Steam from downloading its own files. Remove it so Steam can recover.
            let cfgURL = PathProvider.steamCfg(in: bottle)
            if FileManager.default.fileExists(atPath: cfgURL.path) {
                appendLog("steamui.dll missing but steam.cfg exists — removing pin so Steam can update itself.")
                try? FileManager.default.removeItem(at: cfgURL)
            }
            // Clear the saved build record so setup shows again after this session
            try? FileManager.default.removeItem(at: PathProvider.steamBuildFile)
            pinnedBuild = nil
            appendLog("Launching Steam in recovery mode — it will download its components now. This may take a few minutes.")
        }

        appendLog("Launching: \(steamExe.path)")

        let env = bottleEnv(bottle)
        appendLog("Launching Steam UI...")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: bottle.winePath)
        process.arguments = [
            steamExe.path,
            "-disable-gpu",
            "-no-cef-sandbox",
            "-no-browser",
            "-noreactlogin",
            "-cefdisable",          // Prevents steamwebhelper.exe from being launched at all
        ]
        let fullEnv = mergedEnv(env)
        process.environment = fullEnv
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in self?.isSteamRunning = false }
        }
        try process.run()
        isSteamRunning = true
    }

    // MARK: - Persistence

    func load() throws {
        guard FileManager.default.fileExists(atPath: PathProvider.steamBuildFile.path) else { return }
        let data = try Data(contentsOf: PathProvider.steamBuildFile)
        pinnedBuild = try JSONDecoder().decode(SteamBuild.self, from: data)
    }

    private func saveBuild(_ build: SteamBuild) throws {
        let data = try JSONEncoder().encode(build)
        try data.write(to: PathProvider.steamBuildFile, options: .atomic)
    }

    // MARK: - Helpers

    private func downloadFile(from url: URL, to destination: URL) async throws {
        let fm = FileManager.default
        let dir = destination.deletingLastPathComponent()
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        let (tempURL, response) = try await URLSession.shared.download(from: url)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw AppError.steamDownloadFailed(statusCode: http.statusCode)
        }
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.moveItem(at: tempURL, to: destination)
    }

    private func bottleEnv(_ bottle: Bottle) -> [String: String] {
        PathProvider.wineEnvironment(prefixPath: bottle.prefixPath, arch: bottle.arch, bottle: bottle)
    }

    private func mergedEnv(_ overrides: [String: String]) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        for (k, v) in overrides { env[k] = v }
        return env
    }

    private func appendLog(_ line: String) {
        installLog.append(line)
    }

    private func searchForFile(named name: String, under root: URL) {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: nil) else { return }
        var found: [String] = []
        for case let url as URL in enumerator {
            if url.lastPathComponent.lowercased() == name.lowercased() {
                found.append(url.path)
            }
        }
        if found.isEmpty {
            appendLog("[search] \(name) not found anywhere under \(root.lastPathComponent)")
        } else {
            appendLog("[search] \(name) found at: \(found.joined(separator: ", "))")
        }
    }

    private func logSteamDir(_ dir: URL, label: String) {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: dir.path) else {
            appendLog("[\(label)] Steam dir missing or unreadable: \(dir.path)")
            return
        }
        let sorted = items.sorted()
        appendLog("[\(label)] Steam dir (\(sorted.count) items): \(sorted.prefix(20).joined(separator: ", "))")
    }
}
