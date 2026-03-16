import SwiftUI
import AppKit

@main
struct SmokeLauncherApp: App {
    @StateObject private var runtimeManager = RuntimeManager()
    @StateObject private var bottleManager = BottleManager()
    @StateObject private var steamManager = SteamManager()
    @StateObject private var gameManager = GameManager()

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        try? PathProvider.ensureDirectories()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(runtimeManager)
                .environmentObject(bottleManager)
                .environmentObject(steamManager)
                .environmentObject(gameManager)
                .onAppear {
                    appDelegate.runtimeManager = runtimeManager
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 900, height: 620)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Library") {
                Button("Add Game...") {
                    NotificationCenter.default.post(name: .addGame, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    var runtimeManager: RuntimeManager?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let rm = runtimeManager, rm.isDownloading else {
            return .terminateNow
        }
        // Save resume data synchronously before allowing the app to quit
        rm.prepareForTermination()
        return .terminateNow
    }
}

extension Notification.Name {
    static let addGame = Notification.Name("smoke.addGame")
}
