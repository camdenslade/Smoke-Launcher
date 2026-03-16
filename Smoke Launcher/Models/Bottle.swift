import Foundation

enum WineArch: String, Codable, CaseIterable {
    case win64, win32
}

struct Bottle: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var prefixPath: URL
    var winePath: String
    var arch: WineArch
    var dxvkEnabled: Bool
    var esyncEnabled: Bool
    var createdAt: Date

    init(name: String, prefixPath: URL, winePath: String, arch: WineArch = .win64) {
        self.id = UUID()
        self.name = name
        self.prefixPath = prefixPath
        self.winePath = winePath
        self.arch = arch
        self.dxvkEnabled = true
        self.esyncEnabled = true
        self.createdAt = Date()
    }
}

struct BottleSettings: Codable {
    var bottles: [Bottle]
    var extraEnv: [String: String]
    var winetricksComponents: [String]

    static let `default` = BottleSettings(
        bottles: [],
        extraEnv: [:],
        winetricksComponents: ["dxvk", "vcrun2022", "corefonts"]
    )
}
