import Foundation
import Combine

// MARK: - Manifest

struct RuntimeManifest: Codable {
    var wineVersion: String
    var dxvkVersion: String
    var winetricksVersion: String
    var installedAt: Date
}

// MARK: - GitHub API types

private struct GHRelease: Decodable {
    let tagName: String
    let assets: [GHAsset]
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"; case assets
    }
}

private struct GHAsset: Decodable {
    let name: String
    let browserDownloadURL: URL
    enum CodingKeys: String, CodingKey {
        case name; case browserDownloadURL = "browser_download_url"
    }
}

// MARK: - RuntimeManager

@MainActor
final class RuntimeManager: ObservableObject {
    @Published var isInstalled: Bool = false
    @Published var isDownloading: Bool = false
    @Published var hasResumeData: Bool = false
    @Published var currentStep: String = ""
    @Published var overallProgress: Double = 0.0
    @Published var downloadBytesPerSec: Int64 = 0
    @Published var downloadETA: TimeInterval? = nil
    @Published var log: [String] = []
    @Published var error: String?
    @Published var manifest: RuntimeManifest?

    private let shell = ShellRunner()
    // Held so we can cancel + save resume data on app quit
    private var activeDownloadTask: URLSessionDownloadTask?
    private var activeSession: URLSession?

    init() {
        checkInstalled()
    }

    // MARK: - Public interface

    var winePath: String? { PathProvider.wineBinary?.path }

    func checkInstalled() {
        let manifestOK = (try? Data(contentsOf: PathProvider.runtimeManifest))
            .flatMap { try? JSONDecoder().decode(RuntimeManifest.self, from: $0) }
        let binaryOK = PathProvider.wineBinary != nil

        if let m = manifestOK, binaryOK {
            manifest = m
            isInstalled = true
        } else {
            isInstalled = false
            // Partial install detected — clean up so the next attempt starts fresh.
            // Skip cleanup only if we have resume data (user deliberately paused the download).
            let hasResume = FileManager.default.fileExists(atPath: PathProvider.wineResumeData.path)
            if !hasResume {
                cleanupPartialInstall()
            }
        }
        hasResumeData = FileManager.default.fileExists(atPath: PathProvider.wineResumeData.path)
    }

    /// Removes any half-extracted or partial runtime files left by a previous crashed/force-quit run.
    func cleanupPartialInstall() {
        let fm = FileManager.default
        var cleaned: [String] = []

        // 1. Partial Wine extraction — wineRootDir exists but binary is missing/incomplete
        if fm.fileExists(atPath: PathProvider.wineRootDir.path) {
            try? fm.removeItem(at: PathProvider.wineRootDir)
            try? fm.createDirectory(at: PathProvider.wineRootDir, withIntermediateDirectories: true)
            cleaned.append("partial Wine extraction")
        }

        // 2. Stale tarballs in /tmp left by a previous run (Wine and DXVK)
        let tmp = fm.temporaryDirectory
        let staleExtensions = ["tar.xz", "tar.gz"]
        if let items = try? fm.contentsOfDirectory(at: tmp, includingPropertiesForKeys: nil) {
            for item in items {
                let name = item.lastPathComponent
                guard staleExtensions.contains(where: { name.hasSuffix($0) }),
                      name.contains("wine") || name.contains("dxvk") else { continue }
                try? fm.removeItem(at: item)
                cleaned.append(item.lastPathComponent)
            }
        }

        // 3. Incomplete manifest
        if fm.fileExists(atPath: PathProvider.runtimeManifest.path) {
            try? fm.removeItem(at: PathProvider.runtimeManifest)
            cleaned.append("incomplete manifest")
        }

        if !cleaned.isEmpty {
            appendLog("Cleaned up incomplete install: \(cleaned.joined(separator: ", "))")
        }
    }

    func discardResumeData() {
        try? FileManager.default.removeItem(at: PathProvider.wineResumeData)
        hasResumeData = false
    }

    /// Called by the app delegate on quit — saves resume data so the next launch can continue.
    func prepareForTermination() {
        guard let task = activeDownloadTask else { return }
        // Synchronously cancel and capture resume data before the process exits.
        // We use a semaphore because we can't await here (called from sync context).
        let sem = DispatchSemaphore(value: 0)
        task.cancel(byProducingResumeData: { data in
            if let data {
                try? data.write(to: PathProvider.wineResumeData, options: .atomic)
            }
            sem.signal()
        })
        sem.wait()
        activeSession?.invalidateAndCancel()
    }

    func install() async {
        isDownloading = true
        log = []
        error = nil
        overallProgress = 0
        defer { isDownloading = false }

        do {
            // Step 1: Wine
            let (wineVersion, wineURL) = try await latestRelease(
                repo: "Gcenx/macOS_Wine_builds",
                assetFilter: { $0.hasSuffix("-osx64.tar.xz") && $0.contains("staging") }
            )
            appendLog("Found Wine Staging \(wineVersion)")
            currentStep = "Downloading Wine \(wineVersion)..."
            let wineTar = try await download(from: wineURL, progressOffset: 0.0, progressScale: 0.55)
            overallProgress = 0.55

            currentStep = "Extracting Wine..."
            appendLog("Extracting Wine archive...")
            try await extract(tar: wineTar, to: PathProvider.wineRootDir, flags: "-xJf")
            try FileManager.default.removeItem(at: wineTar)
            overallProgress = 0.65

            // Step 2: DXVK
            let (dxvkVersion, dxvkURL) = try await latestRelease(
                repo: "Gcenx/DXVK-macOS",
                assetFilter: { $0.hasSuffix("-builtin.tar.gz") }
            )
            appendLog("Found DXVK-macOS \(dxvkVersion)")
            currentStep = "Downloading DXVK \(dxvkVersion)..."
            let dxvkTar = try await download(from: dxvkURL, progressOffset: 0.65, progressScale: 0.15)
            overallProgress = 0.80

            currentStep = "Installing DXVK into Wine..."
            appendLog("Installing DXVK...")
            try await installDXVK(tarball: dxvkTar)
            try FileManager.default.removeItem(at: dxvkTar)
            overallProgress = 0.88

            // Step 3: winetricks
            currentStep = "Downloading winetricks..."
            appendLog("Downloading winetricks...")
            try await downloadWinetricks()
            overallProgress = 0.95

            // Persist manifest
            let m = RuntimeManifest(
                wineVersion: wineVersion,
                dxvkVersion: dxvkVersion,
                winetricksVersion: "20260125",
                installedAt: Date()
            )
            let data = try JSONEncoder().encode(m)
            try data.write(to: PathProvider.runtimeManifest, options: .atomic)
            manifest = m
            isInstalled = true
            overallProgress = 1.0
            currentStep = "Runtime ready"
            appendLog("All done. Wine \(wineVersion) + DXVK \(dxvkVersion) installed.")
        } catch {
            self.error = error.localizedDescription
            appendLog("[err] \(error.localizedDescription)")
        }
    }

    // MARK: - GitHub API

    private func latestRelease(repo: String, assetFilter: (String) -> Bool) async throws -> (String, URL) {
        let apiURL = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!
        var req = URLRequest(url: apiURL)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let (data, _) = try await URLSession.shared.data(for: req)
        let release = try JSONDecoder().decode(GHRelease.self, from: data)

        guard let asset = release.assets.first(where: { assetFilter($0.name) }) else {
            throw RuntimeError.assetNotFound(repo: repo)
        }
        return (release.tagName, asset.browserDownloadURL)
    }

    // MARK: - Download with progress

    private func download(from url: URL, progressOffset: Double, progressScale: Double) async throws -> URL {
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)

        downloadBytesPerSec = 0
        downloadETA = nil

        // Check for saved resume data from a previous interrupted download
        let resumeData: Data? = {
            guard let data = try? Data(contentsOf: PathProvider.wineResumeData) else { return nil }
            try? FileManager.default.removeItem(at: PathProvider.wineResumeData)
            hasResumeData = false
            return data
        }()

        if resumeData != nil {
            appendLog("Resuming interrupted download...")
        }

        // Speed window lives on the delegate queue — wrapped in a class so the
        // closure can mutate it without capturing a `var` across concurrency boundaries.
        final class SpeedWindow {
            var start = Date()
            var bytes: Int64 = 0
        }

        return try await withCheckedThrowingContinuation { continuation in
            let delegate = DownloadDelegate()
            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            activeSession = session

            let window = SpeedWindow()

            delegate.progressHandler = { [weak self] bytesWritten, totalWritten, totalExpected in
                guard let self else { return }
                window.bytes += bytesWritten
                let elapsed = Date().timeIntervalSince(window.start)
                if elapsed >= 0.5 {
                    let bps = Int64(Double(window.bytes) / elapsed)
                    window.start = Date()
                    window.bytes = 0
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.downloadBytesPerSec = bps
                        if bps > 0 && totalExpected > 0 {
                            self.downloadETA = TimeInterval(totalExpected - totalWritten) / Double(bps)
                        }
                        if totalExpected > 0 {
                            self.overallProgress = progressOffset + (Double(totalWritten) / Double(totalExpected)) * progressScale
                        }
                    }
                }
            }

            delegate.completionHandler = { [weak self] tempURL, response, error in
                self?.activeDownloadTask = nil
                self?.activeSession = nil
                session.invalidateAndCancel()

                if let error {
                    // Ignore cancellation errors — prepareForTermination already saved resume data
                    // and the app is quitting. Resuming the continuation here is harmless but
                    // avoids flashing an error in the UI on a slow quit.
                    let nsErr = error as NSError
                    if nsErr.domain == NSURLErrorDomain && nsErr.code == NSURLErrorCancelled {
                        return
                    }
                    continuation.resume(throwing: error)
                    return
                }
                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    continuation.resume(throwing: AppError.steamDownloadFailed(statusCode: http.statusCode))
                    return
                }
                guard let tempURL else {
                    continuation.resume(throwing: AppError.steamDownloadFailed(statusCode: -1))
                    return
                }
                do {
                    let fm = FileManager.default
                    if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
                    try fm.moveItem(at: tempURL, to: dest)
                    Task { @MainActor [weak self] in
                        self?.downloadBytesPerSec = 0
                        self?.downloadETA = nil
                    }
                    continuation.resume(returning: dest)
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            let task = resumeData != nil
                ? session.downloadTask(withResumeData: resumeData!)
                : session.downloadTask(with: url)
            activeDownloadTask = task
            task.resume()
        }
    }

    // MARK: - Extraction

    private func extract(tar: URL, to destination: URL, flags: String) async throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: destination.path) {
            try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        }
        for try await line in await shell.stream(
            "/usr/bin/tar",
            args: [flags, tar.path, "-C", destination.path],
            env: [:]
        ) {
            appendLog(line)
        }
    }

    // MARK: - DXVK install

    private func installDXVK(tarball: URL) async throws {
        // Extract to a temp dir, then copy DLLs into Wine's lib directories
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("dxvk_install")
        let fm = FileManager.default
        if fm.fileExists(atPath: tempDir.path) { try fm.removeItem(at: tempDir) }
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }

        for try await line in await shell.stream(
            "/usr/bin/tar", args: ["-xzf", tarball.path, "-C", tempDir.path], env: [:]
        ) { appendLog(line) }

        guard let wineBinDir = PathProvider.wineBinDir else {
            throw RuntimeError.wineNotExtracted
        }
        let wineLibDir = wineBinDir
            .deletingLastPathComponent()      // bin -> wine
            .appendingPathComponent("lib/wine")

        // Find the extracted DXVK folder
        guard let dxvkRoot = try? fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil).first else {
            throw RuntimeError.dxvkExtractionFailed
        }

        let copyMap: [(String, String)] = [
            ("x86_64-windows", "x86_64-windows"),
            ("i386-windows", "i386-windows"),
        ]
        for (src, dst) in copyMap {
            let srcDir = dxvkRoot.appendingPathComponent(src)
            let dstDir = wineLibDir.appendingPathComponent(dst)
            guard fm.fileExists(atPath: srcDir.path) else { continue }
            let dlls = try fm.contentsOfDirectory(at: srcDir, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "dll" }
            for dll in dlls {
                let dest = dstDir.appendingPathComponent(dll.lastPathComponent)
                if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
                try fm.copyItem(at: dll, to: dest)
                appendLog("DXVK: installed \(dll.lastPathComponent) → \(dst)/")
            }
        }
    }

    // MARK: - Winetricks

    private func downloadWinetricks() async throws {
        let url = URL(string: "https://raw.githubusercontent.com/Winetricks/winetricks/20260125/src/winetricks")!
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw RuntimeError.winetricksDownloadFailed(statusCode: http.statusCode)
        }
        try data.write(to: PathProvider.winetricksScript, options: .atomic)
        // Make executable
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: PathProvider.winetricksScript.path
        )
        appendLog("winetricks ready.")
    }

    // MARK: - Helpers

    private func appendLog(_ line: String) {
        log.append(line)
    }
}

// MARK: - Download delegate

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    var progressHandler: ((_ bytesWritten: Int64, _ totalWritten: Int64, _ totalExpected: Int64) -> Void)?
    var completionHandler: ((URL?, URLResponse?, Error?) -> Void)?

    // Called repeatedly as data arrives — totalBytesWritten is cumulative
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        progressHandler?(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        completionHandler?(location, downloadTask.response, nil)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            completionHandler?(nil, task.response, error)
        }
    }
}

// MARK: - Errors

enum RuntimeError: LocalizedError {
    case assetNotFound(repo: String)
    case wineNotExtracted
    case dxvkExtractionFailed
    case winetricksDownloadFailed(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .assetNotFound(let repo): return "No matching release asset found in \(repo)"
        case .wineNotExtracted: return "Wine was not extracted correctly — binary not found"
        case .dxvkExtractionFailed: return "DXVK archive extraction failed"
        case .winetricksDownloadFailed(let code): return "winetricks download failed with HTTP \(code)"
        }
    }
}
