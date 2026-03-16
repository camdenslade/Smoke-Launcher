import Foundation
import Combine

@MainActor
final class BottleManager: ObservableObject {
    @Published var bottles: [Bottle] = []
    @Published var isWorking: Bool = false
    @Published var setupLog: [String] = []
    @Published var error: AppError?

    private let shell = ShellRunner()

    init() {
        try? load()
    }

    // MARK: - Bottle Creation

    func createBottle(name: String, arch: WineArch = .win64, winePath: String) async throws -> Bottle {
        // Return existing bottle if already created — prevents duplicates on repeated setup runs
        if let existing = bottles.first(where: { $0.name == name }) {
            appendLog("Bottle '\(name)' already exists, reusing.")
            return existing
        }

        isWorking = true
        setupLog = []
        defer { isWorking = false }

        let prefixPath = PathProvider.bottlePath(named: name)
        let fm = FileManager.default

        if !fm.fileExists(atPath: prefixPath.path) {
            try fm.createDirectory(at: prefixPath, withIntermediateDirectories: true)
        }

        let env = wineEnv(prefixPath: prefixPath, arch: arch)

        // Derive wineboot from the wine binary path (same directory, sibling binary)
        let winebootPath = URL(fileURLWithPath: winePath)
            .deletingLastPathComponent()
            .appendingPathComponent("wineboot")
            .path

        appendLog("Creating Wine prefix at \(prefixPath.path)...")
        for try await line in await shell.stream(winebootPath, args: ["--init"], env: env, allowingFailure: true) {
            appendLog(line)
        }

        // Disable the Wine crash debugger popup — when a Windows process crashes under Wine,
        // this prevents the "Wine Debugger" window from appearing.
        let wineregPath = URL(fileURLWithPath: winePath)
            .deletingLastPathComponent()
            .appendingPathComponent("wine")
            .path
        let regArgs = [
            "reg", "add",
            "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\AeDebug",
            "/v", "Auto", "/t", "REG_SZ", "/d", "0", "/f"
        ]
        for try await line in await shell.stream(wineregPath, args: regArgs, env: env, allowingFailure: true) {
            appendLog(line)
        }

        let bottle = Bottle(name: name, prefixPath: prefixPath, winePath: winePath, arch: arch)
        bottles.append(bottle)
        try save()
        appendLog("Bottle '\(name)' created.")
        return bottle
    }

    // MARK: - Winetricks

    func installWinetricks(into bottle: Bottle, components: [String]) async throws {
        // Use bundled winetricks first, fall back to system install
        let winetricksPath = PathProvider.winetricksScript
        let winetricks: String
        if FileManager.default.isExecutableFile(atPath: winetricksPath.path) {
            winetricks = winetricksPath.path
        } else if let found = ShellRunner.locate("winetricks") {
            winetricks = found
        } else {
            throw AppError.winetricksNotFound
        }

        isWorking = true
        defer { isWorking = false }

        let env = wineEnv(prefixPath: bottle.prefixPath, arch: bottle.arch, bottle: bottle)
        appendLog("Installing winetricks components: \(components.joined(separator: " "))")

        for try await line in await shell.stream(winetricks, args: components, env: env, allowingFailure: true) {
            appendLog(line)
        }
        appendLog("Winetricks installation complete.")
    }

    // MARK: - Settings

    func setDXVK(enabled: Bool, bottleID: UUID) {
        guard let idx = bottles.firstIndex(where: { $0.id == bottleID }) else { return }
        bottles[idx].dxvkEnabled = enabled
        try? save()
    }

    func setEsync(enabled: Bool, bottleID: UUID) {
        guard let idx = bottles.firstIndex(where: { $0.id == bottleID }) else { return }
        bottles[idx].esyncEnabled = enabled
        try? save()
    }

    // MARK: - Persistence

    func save() throws {
        let settings = BottleSettings(bottles: bottles, extraEnv: [:], winetricksComponents: [])
        let data = try JSONEncoder().encode(settings)
        try data.write(to: PathProvider.bottleSettingsFile, options: .atomic)
    }

    func load() throws {
        guard FileManager.default.fileExists(atPath: PathProvider.bottleSettingsFile.path) else { return }
        let data = try Data(contentsOf: PathProvider.bottleSettingsFile)
        let settings = try JSONDecoder().decode(BottleSettings.self, from: data)
        bottles = settings.bottles
    }

    func delete(_ bottle: Bottle) throws {
        try FileManager.default.removeItem(at: bottle.prefixPath)
        bottles.removeAll { $0.id == bottle.id }
        try save()
    }

    // MARK: - Helpers

    func wineEnv(prefixPath: URL, arch: WineArch, bottle: Bottle? = nil) -> [String: String] {
        PathProvider.wineEnvironment(prefixPath: prefixPath, arch: arch, bottle: bottle)
    }

    private func appendLog(_ line: String) {
        setupLog.append(line)
    }
}
