import SwiftUI

struct DetectedGamesView: View {
    let detectedGames: [DetectedGame]
    @Binding var isPresented: Bool
    @EnvironmentObject var gameManager: GameManager

    @State private var selected: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Detected Games")
                        .font(.title2.bold())
                    Text("\(detectedGames.count) game\(detectedGames.count == 1 ? "" : "s") found in your Steam library")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Select All") {
                    selected = Set(detectedGames.map { $0.id })
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
            .padding([.horizontal, .top], 20)
            .padding(.bottom, 12)

            Divider()

            // Game list
            List(detectedGames, selection: $selected) { game in
                HStack(spacing: 12) {
                    Image(systemName: "gamecontroller.fill")
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(game.name)
                            .font(.headline)
                        Text(game.exePath.path)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .tag(game.id)
            }
            .frame(minHeight: 200)

            Divider()

            // Footer
            HStack {
                Text("\(selected.count) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.escape)
                Button("Add \(selected.count == detectedGames.count ? "All" : "\(selected.count)") Game\(selected.count == 1 ? "" : "s")") {
                    addSelected()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
                .disabled(selected.isEmpty)
            }
            .padding(20)
        }
        .frame(width: 480, height: 400)
        .onAppear {
            // Pre-select all by default
            selected = Set(detectedGames.map { $0.id })
        }
    }

    private func addSelected() {
        for detected in detectedGames where selected.contains(detected.id) {
            try? gameManager.register(game: detected.toGame())
        }
        isPresented = false
    }
}
