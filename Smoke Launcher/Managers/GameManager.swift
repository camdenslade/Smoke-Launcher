import Foundation
import Combine

@MainActor
final class GameManager: ObservableObject {
    @Published var games: [Game] = []
    @Published var runningGameID: UUID?
    @Published var error: AppError?

    private let shell = ShellRunner()

    init() {
        try? load()
    }

    // MARK: - Registration

    func register(game: Game) throws {
        guard FileManager.default.fileExists(atPath: game.exePath.path) else {
            throw AppError.gameExeNotFound(path: game.exePath.path)
        }
        games.append(game)
        try save()
    }

    func remove(_ game: Game) throws {
        games.removeAll { $0.id == game.id }
        try save()
    }

    func update(_ game: Game) throws {
        guard let idx = games.firstIndex(where: { $0.id == game.id }) else { return }
        games[idx] = game
        try save()
    }

    // MARK: - Launch

    func launch(_ game: Game, bottle: Bottle) -> AsyncThrowingStream<String, Error> {
        let config = buildConfig(game: game, bottle: bottle)

        return AsyncThrowingStream { continuation in
            Task {
                await MainActor.run { self.runningGameID = game.id }
                var games = await MainActor.run { self.games }
                if let idx = games.firstIndex(where: { $0.id == game.id }) {
                    games[idx].lastPlayedAt = Date()
                    await MainActor.run { self.games = games }
                    try? await MainActor.run { try self.save() }
                }

                let stream = await self.shell.stream(
                    bottle.winePath,
                    args: [game.exePath.path] + game.launchArgs,
                    env: config.resolvedEnv
                )

                do {
                    for try await line in stream {
                        continuation.yield(line)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }

                await MainActor.run { self.runningGameID = nil }
            }
        }
    }

    // MARK: - Steam Game Detection

    /// Scans steamapps/common in the bottle and returns games not yet in the library.
    func scanSteamGames(bottle: Bottle) -> [DetectedGame] {
        let steamappsDir = bottle.prefixPath
            .appendingPathComponent("drive_c/Program Files (x86)/Steam/steamapps")
        let commonDir = steamappsDir.appendingPathComponent("common")

        guard let gameDirs = try? FileManager.default.contentsOfDirectory(
            at: commonDir, includingPropertiesForKeys: [.isDirectoryKey]
        ).filter({ (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true })
        else { return [] }

        // Build installdir → appID map from .acf manifests
        let appIDMap = buildAppIDMap(steamappsDir: steamappsDir)

        // Backfill steamAppID for any existing games that are missing it
        backfillSteamAppIDs(appIDMap: appIDMap, commonDir: commonDir)

        let alreadyAdded = Set(games.map { $0.exePath.deletingLastPathComponent().path })

        return gameDirs.compactMap { dir -> DetectedGame? in
            guard !alreadyAdded.contains(dir.path) else { return nil }
            guard let exe = findMainExe(in: dir) else { return nil }
            let folderName = dir.lastPathComponent
            let appID = appIDMap[folderName.lowercased()]
            return DetectedGame(name: folderName, exePath: exe, bottleID: bottle.id, steamAppID: appID)
        }
        .sorted { $0.name < $1.name }
    }

    /// Updates steamAppID for existing library games that are missing it.
    private func backfillSteamAppIDs(appIDMap: [String: String], commonDir: URL) {
        var changed = false
        for i in games.indices where games[i].steamAppID == nil {
            let folderName = games[i].exePath.deletingLastPathComponent().lastPathComponent
            if let appID = appIDMap[folderName.lowercased()] {
                games[i].steamAppID = appID
                changed = true
            }
        }
        if changed { try? save() }
    }

    /// Parses appmanifest_*.acf files to build a map of installdir (lowercased) → appID.
    private func buildAppIDMap(steamappsDir: URL) -> [String: String] {
        guard let acfFiles = try? FileManager.default.contentsOfDirectory(
            at: steamappsDir, includingPropertiesForKeys: nil
        ).filter({ $0.pathExtension == "acf" }) else { return [:] }

        var map: [String: String] = [:]
        for acf in acfFiles {
            guard let content = try? String(contentsOf: acf, encoding: .utf8) else { continue }
            var appID: String?
            var installDir: String?
            for line in content.components(separatedBy: "\n") {
                let parts = line.trimmingCharacters(in: .whitespaces)
                    .components(separatedBy: "\t")
                    .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
                    .filter { !$0.isEmpty }
                guard parts.count >= 2 else { continue }
                switch parts[0].lowercased() {
                case "appid":     appID = parts[1]
                case "installdir": installDir = parts[1]
                default: break
                }
            }
            if let id = appID, let dir = installDir {
                map[dir.lowercased()] = id
            }
        }
        return map
    }

    private func findMainExe(in dir: URL) -> URL? {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.isRegularFileKey]
        ) else { return nil }

        let exes = contents.filter { $0.pathExtension.lowercased() == "exe" }
        if exes.isEmpty { return nil }

        // Prefer an exe matching the folder name (most common pattern)
        let folderName = dir.lastPathComponent.lowercased()
        let skipPatterns = ["unins", "setup", "install", "redist", "crash", "report", "helper", "launcher_fix"]

        let filtered = exes.filter { exe in
            let name = exe.deletingPathExtension().lastPathComponent.lowercased()
            return !skipPatterns.contains(where: { name.contains($0) })
        }

        return filtered.first(where: { $0.deletingPathExtension().lastPathComponent.lowercased() == folderName })
            ?? filtered.first
            ?? exes.first
    }

    // MARK: - Persistence

    func save() throws {
        let data = try JSONEncoder().encode(games)
        try data.write(to: PathProvider.gamesFile, options: .atomic)
    }

    func load() throws {
        guard FileManager.default.fileExists(atPath: PathProvider.gamesFile.path) else { return }
        let data = try Data(contentsOf: PathProvider.gamesFile)
        games = try JSONDecoder().decode([Game].self, from: data)
    }

    // MARK: - Helpers

    private func buildConfig(game: Game, bottle: Bottle) -> LaunchConfig {
        let env = PathProvider.wineEnvironment(prefixPath: bottle.prefixPath, arch: bottle.arch, bottle: bottle)
        return LaunchConfig(bottle: bottle, game: game, resolvedEnv: env)
    }
}
