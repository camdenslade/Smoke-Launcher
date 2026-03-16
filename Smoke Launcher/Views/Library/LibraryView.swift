import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var steamManager: SteamManager
    @EnvironmentObject var bottleManager: BottleManager
    @Binding var selectedGame: Game?

    @State private var showAddGame = false
    @State private var showDetected = false
    @State private var detectedGames: [DetectedGame] = []
    @State private var searchText = ""
    @State private var steamError: String?
    @State private var autoScanBanner: String?

    var bottle: Bottle? { bottleManager.bottles.first }

    var filteredGames: [Game] {
        if searchText.isEmpty { return gameManager.games }
        return gameManager.games.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List(selection: $selectedGame) {
            if let banner = autoScanBanner {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text(banner).font(.caption).foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Button { autoScanBanner = nil } label: {
                        Image(systemName: "xmark").font(.caption2).foregroundStyle(.white.opacity(0.4))
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.vertical, 6)
                .listRowBackground(Color.green.opacity(0.12))
                .listRowSeparator(.hidden)
            }

            gameListContent
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .searchable(text: $searchText, prompt: "Search games")
        .navigationTitle("Library")
        .onAppear {
            if let b = bottle { _ = gameManager.scanSteamGames(bottle: b) }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { launchSteam() } label: {
                    Image(systemName: steamManager.isSteamRunning ? "stop.circle" : "arrow.up.forward.app")
                }
                .help(steamManager.isSteamRunning ? "Steam Running" : "Open Steam")
                .disabled(bottle == nil)

                Button { scanForGames() } label: {
                    Image(systemName: "magnifyingglass")
                }
                .help("Detect installed Steam games")
                .disabled(bottle == nil)

                Button { showAddGame = true } label: {
                    Image(systemName: "plus")
                }
                .help("Add game manually")
            }
        }
        .sheet(isPresented: $showAddGame) {
            AddGameView(isPresented: $showAddGame)
        }
        .sheet(isPresented: $showDetected) {
            DetectedGamesView(detectedGames: detectedGames, isPresented: $showDetected)
        }
        .alert("Steam", isPresented: Binding(get: { steamError != nil }, set: { if !$0 { steamError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(steamError ?? "")
        }
        .onChange(of: steamManager.isSteamRunning) { _ in
            if !steamManager.isSteamRunning, let b = bottle {
                let found = gameManager.scanSteamGames(bottle: b)
                if !found.isEmpty {
                    for detected in found { try? gameManager.register(game: detected.toGame()) }
                    let names = found.prefix(2).map(\.name).joined(separator: ", ")
                    let extra = found.count > 2 ? " +\(found.count - 2) more" : ""
                    autoScanBanner = "Added: \(names)\(extra)"
                    selectedGame = gameManager.games.last
                }
            }
        }
    }

    @ViewBuilder
    private var gameListContent: some View {
        if filteredGames.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "gamecontroller")
                    .font(.system(size: 34))
                    .foregroundStyle(.white.opacity(0.2))
                Text(gameManager.games.isEmpty ? "No Games" : "No Results")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.4))
                if gameManager.games.isEmpty {
                    Text("Open Steam, install games,\nthey'll appear here automatically.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.25))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        } else {
            ForEach(filteredGames) { game in
                GameRowView(
                    game: game,
                    isRunning: gameManager.runningGameID == game.id,
                    isSelected: selectedGame?.id == game.id
                )
                .tag(game)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(.init(top: 3, leading: 8, bottom: 3, trailing: 8))
                .contextMenu {
                    Button("Remove Game", role: .destructive) {
                        try? gameManager.remove(game)
                        if selectedGame?.id == game.id { selectedGame = nil }
                    }
                }
            }
        }
    }

    private func launchSteam() {
        guard let b = bottle else { return }
        Task {
            do { try await steamManager.launchSteamUI(in: b) }
            catch { steamError = error.localizedDescription }
        }
    }

    private func scanForGames() {
        guard let b = bottle else { return }
        let found = gameManager.scanSteamGames(bottle: b)
        if found.isEmpty {
            steamError = "No new games found. Install games through Steam first."
        } else {
            detectedGames = found
            showDetected = true
        }
    }
}
