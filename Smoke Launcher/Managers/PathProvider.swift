import Foundation

struct PathProvider {
    static let appSupport: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("SmokeLauncher")
    }()

    static let bottlesRoot: URL = appSupport.appendingPathComponent("bottles")
    static let steamClient: URL = appSupport.appendingPathComponent("steam_client")
    static let pinnedBuild: URL = steamClient.appendingPathComponent("pinned_build")
    static let configDir: URL = appSupport.appendingPathComponent("config")
    static let bottleSettingsFile: URL = configDir.appendingPathComponent("bottle_settings.json")
    static let gamesFile: URL = configDir.appendingPathComponent("games.json")
    static let backupsDirectory: URL = appSupport.appendingPathComponent("backups")
    static let steamBuildFile: URL = configDir.appendingPathComponent("steam_build.json")

    // Runtime - bundled Wine, DXVK, winetricks
    static let runtimeDir: URL = appSupport.appendingPathComponent("runtime")
    static let wineRootDir: URL = runtimeDir.appendingPathComponent("wine")
    static let winetricksScript: URL = runtimeDir.appendingPathComponent("winetricks")
    static let runtimeManifest: URL = configDir.appendingPathComponent("runtime.json")
    static let wineResumeData: URL = configDir.appendingPathComponent("wine_resume.bin")

    static let gptkWineBinary = URL(fileURLWithPath: "/Applications/Game Porting Toolkit.app/Contents/Resources/wine/bin/wine")
    static var gptkInstalled: Bool {
        FileManager.default.isExecutableFile(atPath: gptkWineBinary.path)
    }

    /// Prefers GPTK if installed (D3DMetal translation), otherwise uses bundled Wine.
    static var wineBinary: URL? {
        if gptkInstalled { return gptkWineBinary }
        let fm = FileManager.default
        guard let apps = try? fm.contentsOfDirectory(at: wineRootDir, includingPropertiesForKeys: nil)
            .filter({ $0.pathExtension == "app" })
        else { return nil }
        for app in apps {
            let candidate = app
                .appendingPathComponent("Contents/Resources/wine/bin/wine")
            if fm.isExecutableFile(atPath: candidate.path) { return candidate }
        }
        return nil
    }

    static var wineBinDir: URL? { wineBinary?.deletingLastPathComponent() }

    /// Base Wine environment for macOS. Use this everywhere - never build env vars ad-hoc.
    static func wineEnvironment(prefixPath: URL, arch: WineArch, bottle: Bottle? = nil) -> [String: String] {
        let existingPath = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin"
        var env: [String: String] = [
            "WINEPREFIX":               prefixPath.path,
            "WINEARCH":                 arch.rawValue,
            // MSync = macOS-native sync via Mach semaphores. No fd-limit issues.
            // ESync requires 500k file descriptors - macOS hard-caps at ~10k - "cannot allocate memory"
            "WINEMSYNC":                "1",
            "WINEESYNC":                "0",
            // Show only actionable error channels; suppress the fixme/trace flood
            "WINEDEBUG":                "err+module,err+seh,err+wgl,err+d3d,-fixme",
            // MoltenVK: recover lost device instead of crashing on GPU reset
            "MVK_CONFIG_RESUME_LOST_DEVICE": "1",
            // MoltenVK: faster descriptor binding (helps UE5/DX12 games)
            "MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS": "1",
            // MoltenVK: async queue submits for better throughput
            "MVK_CONFIG_SYNCHRONOUS_QUEUE_SUBMITS": "0",
        ]
        if let binDir = wineBinDir {
            env["PATH"] = "\(binDir.path):\(existingPath)"
        }
        if let b = bottle {
            // ESync: override MSync when user explicitly enables it
            if b.esyncEnabled {
                env["WINEMSYNC"] = "0"
                env["WINEESYNC"] = "1"
            }
            if b.dxvkEnabled {
                // Tell Wine to use the native (DXVK) d3d11/dxgi DLLs instead of wined3d
                env["WINEDLLOVERRIDES"] = "d3d11,d3d10core,dxgi=n"
                // Async shader compilation - reduces stutter on first render of each shader
                env["DXVK_ASYNC"] = "1"
                // Persist compiled shader cache between sessions
                let cacheDir = dxvkCache(in: b)
                env["DXVK_STATE_CACHE_PATH"] = cacheDir.path
            }
        }
        return env
    }

    static func bottlePath(named name: String) -> URL {
        bottlesRoot.appendingPathComponent(name)
    }

    static func steamCfg(in bottle: Bottle) -> URL {
        bottle.prefixPath
            .appendingPathComponent("drive_c")
            .appendingPathComponent("Program Files (x86)")
            .appendingPathComponent("Steam")
            .appendingPathComponent("steam.cfg")
    }

    static func dxvkCache(in bottle: Bottle) -> URL {
        bottle.prefixPath.appendingPathComponent("dxvk_cache")
    }

    static func ensureDirectories() throws {
        let fm = FileManager.default
        for dir in [appSupport, bottlesRoot, steamClient, pinnedBuild, configDir, runtimeDir, wineRootDir] {
            if !fm.fileExists(atPath: dir.path) {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }
}
