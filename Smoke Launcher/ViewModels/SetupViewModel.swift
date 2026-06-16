import Foundation
import Combine

enum SetupStep: Int, CaseIterable {
    case runtime
    case bottleSetup
    case steamInstall
    case done
}

@MainActor
final class SetupViewModel: ObservableObject {
    @Published var step: SetupStep = .runtime
    @Published var isWorking: Bool = false
    @Published var error: String?

    func advance() {
        guard let next = SetupStep(rawValue: step.rawValue + 1) else { return }
        step = next
    }

    func createBottle(bottleManager: BottleManager, runtimeManager: RuntimeManager) async {
        guard let winePath = runtimeManager.winePath else {
            error = "Runtime not installed. Download the runtime first."
            return
        }
        isWorking = true
        error = nil
        defer { isWorking = false }
        do {
            _ = try await bottleManager.createBottle(name: "steam", winePath: winePath)
            advance()
        } catch let e {
            error = e.localizedDescription
        }
    }

    func installSteam(steamManager: SteamManager, bottle: Bottle) async {
        isWorking = true
        error = nil
        defer { isWorking = false }
        do {
            try await steamManager.downloadAndInstall(into: bottle)
            advance()
        } catch let e {
            error = e.localizedDescription
        }
    }
}
