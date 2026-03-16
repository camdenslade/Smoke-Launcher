import Foundation

struct Game: Identifiable, Codable, Hashable {
    let id: UUID
    var displayName: String
    var exePath: URL
    var bottleID: UUID
    var steamAppID: String?
    var lastPlayedAt: Date?
    var launchArgs: [String]

    init(displayName: String, exePath: URL, bottleID: UUID) {
        self.id = UUID()
        self.displayName = displayName
        self.exePath = exePath
        self.bottleID = bottleID
        self.launchArgs = []
    }
}

struct DetectedGame: Identifiable {
    let id = UUID()
    let name: String
    let exePath: URL
    let bottleID: UUID
    let steamAppID: String?

    func toGame() -> Game {
        var g = Game(displayName: name, exePath: exePath, bottleID: bottleID)
        g.steamAppID = steamAppID
        return g
    }
}

struct LaunchConfig {
    let bottle: Bottle
    let game: Game
    var resolvedEnv: [String: String]
}
