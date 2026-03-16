import Foundation
import Combine

@MainActor
final class LaunchViewModel: ObservableObject {
    @Published var logLines: [String] = []
    @Published var isRunning: Bool = false
    @Published var error: String?

    private var streamTask: Task<Void, Never>?

    func launch(game: Game, bottle: Bottle, gameManager: GameManager) {
        guard !isRunning else { return }
        logLines = []
        error = nil
        isRunning = true

        let stream = gameManager.launch(game, bottle: bottle)

        streamTask = Task { [weak self] in
            do {
                for try await line in stream {
                    await MainActor.run {
                        self?.logLines.append(line)
                    }
                }
            } catch let e as AppError {
                await MainActor.run { self?.error = e.localizedDescription }
            } catch let e {
                await MainActor.run { self?.error = e.localizedDescription }
            }
            await MainActor.run { self?.isRunning = false }
        }
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil
        isRunning = false
    }
}
