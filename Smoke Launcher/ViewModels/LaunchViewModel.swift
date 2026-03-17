import Foundation
import Combine
import UserNotifications

@MainActor
final class LaunchViewModel: ObservableObject {
    @Published var logLines: [String] = []
    @Published var isRunning: Bool = false
    @Published var error: String?

    private var streamTask: Task<Void, Never>?
    private var launchedGame: Game?

    func launch(game: Game, bottle: Bottle, gameManager: GameManager) {
        guard !isRunning else { return }
        logLines = []
        error = nil
        isRunning = true
        launchedGame = game
        TrialManager.shared.recordLaunch()

        let stream = gameManager.launch(game, bottle: bottle)

        streamTask = Task { [weak self] in
            do {
                for try await line in stream {
                    if let parsed = Self.parseWineError(line) {
                        await MainActor.run { self?.error = parsed }
                    }
                    await MainActor.run { self?.logLines.append(line) }
                }
            } catch let e as AppError {
                await MainActor.run { self?.error = e.localizedDescription }
            } catch {
                await MainActor.run { self?.error = error.localizedDescription }
            }
            await MainActor.run {
                self?.isRunning = false
                if let name = self?.launchedGame?.displayName {
                    Self.postExitNotification(gameName: name)
                }
            }
        }
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil
        isRunning = false
    }

    // MARK: - Exit notification

    private static func postExitNotification(gameName: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(gameName) closed"
        content.body = "The game has exited."
        content.sound = .none
        let request = UNNotificationRequest(
            identifier: "smoke.gameexit.\(gameName)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Wine error parser

    static func parseWineError(_ line: String) -> String? {
        let l = line.lowercased()
        if l.contains("err:module:import_dll") {
            // Extract the DLL name if possible
            if let range = line.range(of: "import_dll ") ?? line.range(of: "import_dll: ") {
                let rest = String(line[range.upperBound...])
                    .components(separatedBy: " ").first ?? "unknown"
                return "Missing DLL: \(rest). Try enabling DXVK or installing via winetricks."
            }
            return "Missing DLL - game may need DXVK or a Visual C++ runtime."
        }
        if l.contains("access violation") || l.contains("err:seh:setup_exception_record") {
            return "Game crashed (access violation). Try toggling DXVK or running without ESync."
        }
        if l.contains("wine: could not exec") {
            return "Wine could not launch the executable. Check the path is correct and the file is a valid Windows .exe."
        }
        if l.contains("err:wgl") || l.contains("err:d3d") && l.contains("no suitable") {
            return "Graphics error - check that DXVK is enabled and your drivers are up to date."
        }
        if l.contains("cannot allocate memory") {
            return "Out of memory. Close other apps and try again."
        }
        return nil
    }
}
