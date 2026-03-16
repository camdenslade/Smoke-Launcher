import Foundation

struct SteamBuild: Codable {
    var version: String
    var downloadURL: URL
    var pinnedAt: Date
    var installedPath: URL

    static let stableURL = URL(string: "https://media.steampowered.com/client/installer/SteamSetup.exe")!
}
