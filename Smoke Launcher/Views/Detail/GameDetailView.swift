import SwiftUI

struct GameDetailView: View {
    let game: Game
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var bottleManager: BottleManager
    @StateObject private var launchVM = LaunchViewModel()
    @State private var showSettings = false

    // Always read the live copy from gameManager so updates (e.g. steamAppID) are reflected immediately.
    private var liveGame: Game {
        gameManager.games.first { $0.id == game.id } ?? game
    }

    var bottle: Bottle? {
        bottleManager.bottles.first { $0.id == liveGame.bottleID }
    }

    var isRunning: Bool { gameManager.runningGameID == liveGame.id }

    var body: some View {
        ZStack(alignment: .topLeading) {
            AmbientBackground(appID: liveGame.steamAppID, blurRadius: 80, opacity: 0.35)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Hero banner — Steam header art with gradient overlay
                    ZStack(alignment: .bottomLeading) {
                        SteamArtworkView(appID: liveGame.steamAppID, cornerRadius: 0)
                            .frame(maxWidth: .infinity)
                            .frame(height: 160)

                        // Gradient scrim so text is readable over any art
                        LinearGradient(
                            colors: [.black.opacity(0.7), .clear],
                            startPoint: .bottom, endPoint: .center
                        )

                        HStack(alignment: .bottom, spacing: 14) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(liveGame.displayName)
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                                    .lineLimit(2)
                                Text(liveGame.exePath.lastPathComponent)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                                    .textSelection(.enabled)
                            }

                            Spacer()

                            if isRunning {
                                Label("Running", systemImage: "circle.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.green)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(.ultraThinMaterial, in: Capsule())
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 14)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        // Info strip
                        HStack(spacing: 8) {
                            infoChip(icon: "cylinder.split.1x2", label: bottle?.name ?? "No bottle")
                            infoChip(icon: "cpu", label: (bottle?.dxvkEnabled ?? false) ? "DXVK On" : "DXVK Off",
                                     color: (bottle?.dxvkEnabled ?? false) ? .green : .white.opacity(0.5))
                            infoChip(icon: "clock", label: liveGame.lastPlayedAt.map {
                                $0.formatted(.relative(presentation: .named))
                            } ?? "Never played")
                            Spacer()
                        }

                        // Play button row
                        HStack(spacing: 10) {
                            Button {
                                guard let b = bottle else { return }
                                launchVM.launch(game: liveGame, bottle: b, gameManager: gameManager)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: isRunning ? "stop.fill" : "play.fill")
                                    Text(isRunning ? "Running…" : "Play")
                                        .fontWeight(.semibold)
                                }
                                .frame(minWidth: 100)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(bottle == nil || (isRunning && !launchVM.isRunning))

                            if isRunning {
                                Button("Stop") { launchVM.stop() }
                                    .buttonStyle(.bordered)
                                    .controlSize(.large)
                            }
                        }

                        // Error
                        if let err = launchVM.error {
                            Label(err, systemImage: "exclamationmark.triangle.fill")
                                .font(.callout)
                                .foregroundStyle(.red)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .glassCard(cornerRadius: 8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.3), lineWidth: 0.5))
                        }

                        // Output log
                        if !launchVM.logLines.isEmpty || launchVM.isRunning {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Output")
                                        .font(.headline)
                                        .foregroundStyle(.white.opacity(0.8))
                                    Spacer()
                                    if launchVM.isRunning { ProgressView().scaleEffect(0.7).tint(.white.opacity(0.6)) }
                                    Button("Clear") { launchVM.logLines = [] }
                                        .font(.caption).buttonStyle(.borderless)
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                                LogView(lines: launchVM.logLines)
                                    .frame(minHeight: 150, maxHeight: 400)
                            }
                            .padding(14)
                            .glassCard(cornerRadius: 12)
                        }
                    }
                    .padding(24)
                }
            }
        }
        .navigationTitle(liveGame.displayName)
        .toolbar {
            ToolbarItem {
                Button { showSettings.toggle() } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            GameSettingsView(game: liveGame, isPresented: $showSettings)
        }
    }

    private func infoChip(icon: String, label: String, color: Color = .white.opacity(0.6)) -> some View {
        Label(label, systemImage: icon)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
    }
}

// MARK: - Game Settings Sheet

struct GameSettingsView: View {
    var game: Game
    @Binding var isPresented: Bool
    @EnvironmentObject var bottleManager: BottleManager
    @EnvironmentObject var gameManager: GameManager

    @State private var steamAppIDText: String = ""

    var bottle: Bottle? {
        bottleManager.bottles.first { $0.id == game.bottleID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings — \(game.displayName)")
                .font(.title2.bold())

            if let b = bottle {
                GroupBox("Wine Bottle: \(b.name)") {
                    VStack(alignment: .leading) {
                        Toggle("DXVK (DirectX → Metal)", isOn: Binding(
                            get: { b.dxvkEnabled },
                            set: { bottleManager.setDXVK(enabled: $0, bottleID: b.id) }
                        ))
                        Toggle("ESync", isOn: Binding(
                            get: { b.esyncEnabled },
                            set: { bottleManager.setEsync(enabled: $0, bottleID: b.id) }
                        ))
                    }
                    .padding(.top, 4)
                }
            }

            GroupBox("Steam App ID") {
                HStack {
                    TextField("e.g. 570 for Dota 2", text: $steamAppIDText)
                        .textFieldStyle(.roundedBorder)
                    if !steamAppIDText.isEmpty {
                        Link(destination: URL(string: "https://store.steampowered.com/app/\(steamAppIDText)")!) {
                            Image(systemName: "arrow.up.right.square")
                        }
                    }
                }
                .padding(.top, 4)
            }

            GroupBox("Executable Path") {
                Text(game.exePath.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Spacer()
                Button("Done") {
                    var updated = game
                    updated.steamAppID = steamAppIDText.trimmingCharacters(in: .whitespaces).isEmpty ? nil : steamAppIDText.trimmingCharacters(in: .whitespaces)
                    try? gameManager.update(updated)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
            }
        }
        .padding(24)
        .frame(width: 400)
        .onAppear { steamAppIDText = game.steamAppID ?? "" }
    }
}
