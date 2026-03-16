import Foundation
import Combine

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var selectedGame: Game?

    var filteredGames: [Game] = []

    func update(games: [Game]) {
        if searchText.isEmpty {
            filteredGames = games
        } else {
            filteredGames = games.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}
