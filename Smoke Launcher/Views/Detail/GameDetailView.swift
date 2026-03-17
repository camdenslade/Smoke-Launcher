import SwiftUI

struct GameDetailView: View {
    let game: Game
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var bottleManager: BottleManager
    @StateObject private var launchVM = LaunchViewModel()
    @State private var showSettings = false
    @State private var showPaywall = false

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
                    // Hero banner - Steam header art with gradient overlay
                    ZStack(alignment: .bottomLeading) {
                        SteamArtworkView(appID: liveGame.steamAppID, cornerRadius: 0, contentMode: .fill)
                            .aspectRatio(460.0 / 215.0, contentMode: .fit)
                            .frame(maxWidth: .infinity)

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
                            infoChip(icon: "hourglass", label: liveGame.totalPlayTime > 0
                                ? liveGame.formattedPlayTime
                                : "0m")
                            Spacer()
                        }

                        // Play button row
                        HStack(spacing: 10) {
                            Button {
                                guard let b = bottle else { return }
                                if TrialManager.shared.isTrialExpired {
                                    showPaywall = true
                                } else {
                                    launchVM.launch(game: liveGame, bottle: b, gameManager: gameManager)
                                }
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
        .sheet(isPresented: $showPaywall) {
            TrialPaywallView(isPresented: $showPaywall)
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

    @State private var displayNameText: String = ""
    @State private var selectedBottleID: UUID? = nil
    @State private var steamAppIDText: String = ""
    @State private var launchArgsText: String = ""
    @State private var backupStatus: String?
    @State private var isBackingUp = false
    @State private var showDeleteConfirm = false

    var selectedBottle: Bottle? {
        bottleManager.bottles.first { $0.id == (selectedBottleID ?? game.bottleID) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.title2.bold())

            GroupBox("Display Name") {
                TextField("Game name", text: $displayNameText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.top, 4)
            }

            if bottleManager.bottles.count > 1 {
                GroupBox("Wine Bottle") {
                    Picker("Bottle", selection: Binding(
                        get: { selectedBottleID ?? game.bottleID },
                        set: { selectedBottleID = $0 }
                    )) {
                        ForEach(bottleManager.bottles) { b in
                            Text(b.name).tag(b.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.top, 4)
                }
            }

            if let b = selectedBottle {
                GroupBox("Wine Settings: \(b.name)") {
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
                        .onChange(of: steamAppIDText) { newValue in
                            let digits = newValue.filter(\.isNumber)
                            if digits != newValue { steamAppIDText = digits }
                        }
                    if !steamAppIDText.isEmpty {
                        Link(destination: URL(string: "https://store.steampowered.com/app/\(steamAppIDText)")!) {
                            Image(systemName: "arrow.up.right.square")
                        }
                    }
                }
                .padding(.top, 4)
            }

            GroupBox("Launch Arguments") {
                TextField("e.g. -windowed -dx11", text: $launchArgsText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.top, 4)
            }

            GroupBox("Save Backup") {
                HStack {
                    Text("Backs up drive_c/users from the Wine bottle.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(isBackingUp ? "Backing up..." : "Backup Now") {
                        guard let b = selectedBottle else { return }
                        isBackingUp = true
                        backupStatus = nil
                        Task {
                            do {
                                let url = try await gameManager.backupSaves(for: game, bottle: b)
                                backupStatus = "Saved to \(url.lastPathComponent)"
                            } catch {
                                backupStatus = error.localizedDescription
                            }
                            isBackingUp = false
                        }
                    }
                    .disabled(selectedBottle == nil || isBackingUp)
                }
                .padding(.top, 4)
                if let status = backupStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(status.starts(with: "Saved") ? Color.green : Color.red)
                }
            }

            GroupBox("Executable Path") {
                Text(game.exePath.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button("Delete Game", role: .destructive) {
                    showDeleteConfirm = true
                }
                .foregroundStyle(.red)
                .buttonStyle(.borderless)

                Spacer()

                Button("Done") {
                    var updated = game
                    let trimmedName = displayNameText.trimmingCharacters(in: .whitespaces)
                    if !trimmedName.isEmpty { updated.displayName = trimmedName }
                    if let bid = selectedBottleID { updated.bottleID = bid }
                    let trimmedID = steamAppIDText.trimmingCharacters(in: .whitespaces)
                    updated.steamAppID = trimmedID.isEmpty ? nil : trimmedID
                    updated.launchArgs = launchArgsText
                        .trimmingCharacters(in: .whitespaces)
                        .components(separatedBy: .whitespaces)
                        .filter { !$0.isEmpty }
                    try? gameManager.update(updated)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
            }
        }
        .padding(24)
        .frame(width: 420)
        .onAppear {
            displayNameText = game.displayName
            selectedBottleID = game.bottleID
            steamAppIDText = game.steamAppID ?? ""
            launchArgsText = game.launchArgs.joined(separator: " ")
        }
        .confirmationDialog("Delete \(game.displayName)?",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                try? gameManager.remove(game)
                isPresented = false
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the game from your library. Your Wine bottle and save data are not affected.")
        }
    }
}
