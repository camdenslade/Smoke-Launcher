import Foundation

enum AppError: LocalizedError {
    case wineNotFound(searchedPaths: [String])
    case bottleCreationFailed(underlying: Error)
    case steamDownloadFailed(statusCode: Int)
    case winetricksNotFound
    case gameExeNotFound(path: String)
    case processLaunchFailed(command: String, code: Int32)
    case configWriteFailed(path: String, underlying: Error)
    case invalidBottle

    var errorDescription: String? {
        switch self {
        case .wineNotFound(let paths):
            return "Wine not found. Searched: \(paths.joined(separator: ", "))"
        case .bottleCreationFailed(let err):
            return "Failed to create bottle: \(err.localizedDescription)"
        case .steamDownloadFailed(let code):
            return "Steam download failed with HTTP \(code)"
        case .winetricksNotFound:
            return "winetricks not found. Install via Homebrew: brew install winetricks"
        case .gameExeNotFound(let path):
            return "Game executable not found at \(path)"
        case .processLaunchFailed(let cmd, let code):
            return "Process '\(cmd)' exited with code \(code)"
        case .configWriteFailed(let path, let err):
            return "Failed to write config at \(path): \(err.localizedDescription)"
        case .invalidBottle:
            return "No valid Wine bottle configured. Run setup first."
        }
    }
}
