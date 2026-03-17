import Foundation

struct Game: Identifiable, Codable, Hashable {
    let id: UUID
    var displayName: String
    var exePath: URL
    var bottleID: UUID
    var steamAppID: String?
    var lastPlayedAt: Date?
    var totalPlayTime: TimeInterval
    var launchArgs: [String]

    init(displayName: String, exePath: URL, bottleID: UUID) {
        self.id = UUID()
        self.displayName = displayName
        self.exePath = exePath
        self.bottleID = bottleID
        self.totalPlayTime = 0
        self.launchArgs = []
    }

    var formattedPlayTime: String {
        guard totalPlayTime > 0 else { return "0m" }
        let hours = Int(totalPlayTime) / 3600
        let minutes = (Int(totalPlayTime) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(max(1, minutes))m"
    }
}

// Backward-compatible decoding so existing saved games without totalPlayTime still load.
extension Game {
    enum CodingKeys: String, CodingKey {
        case id, displayName, exePath, bottleID, steamAppID, lastPlayedAt, totalPlayTime, launchArgs
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decode(UUID.self, forKey: .id)
        displayName  = try c.decode(String.self, forKey: .displayName)
        exePath      = try c.decode(URL.self, forKey: .exePath)
        bottleID     = try c.decode(UUID.self, forKey: .bottleID)
        steamAppID   = try c.decodeIfPresent(String.self, forKey: .steamAppID)
        lastPlayedAt = try c.decodeIfPresent(Date.self, forKey: .lastPlayedAt)
        totalPlayTime = (try c.decodeIfPresent(TimeInterval.self, forKey: .totalPlayTime)) ?? 0
        launchArgs   = (try c.decodeIfPresent([String].self, forKey: .launchArgs)) ?? []
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
