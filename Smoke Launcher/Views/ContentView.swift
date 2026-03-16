import SwiftUI

struct ContentView: View {
    @EnvironmentObject var runtimeManager: RuntimeManager
    @EnvironmentObject var bottleManager: BottleManager
    @EnvironmentObject var steamManager: SteamManager
    @EnvironmentObject var gameManager: GameManager

    @State private var selectedGame: Game?
    @State private var showSetup = false
    @State private var showBottleManager = false
    @State private var launchError: String?

    var body: some View {
        NavigationSplitView {
            LibraryView(selectedGame: $selectedGame)
        } detail: {
            if let game = selectedGame {
                GameDetailView(game: game)
            } else {
                emptyDetail
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            let needsRuntime = !runtimeManager.isInstalled
            let needsBottle = runtimeManager.isInstalled && bottleManager.bottles.isEmpty
            if needsRuntime || needsBottle {
                showSetup = true
            }
        }
        .sheet(isPresented: $showSetup) {
            SetupView(isPresented: $showSetup)
        }
        .sheet(isPresented: $showBottleManager) {
            BottleManagementView(isPresented: $showBottleManager)
        }
        .alert("Steam Error", isPresented: Binding(get: { launchError != nil }, set: { if !$0 { launchError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(launchError ?? "")
        }
        .toolbar {
            ToolbarItem(placement: .status) {
                StatusBar(
                    runtimeInstalled: runtimeManager.isInstalled,
                    bottleCount: bottleManager.bottles.count,
                    steamPinned: bottleManager.bottles.first.map { steamManager.isVersionPinned(in: $0) } ?? false
                )
            }
            ToolbarItem(placement: .navigation) {
                Button { showBottleManager = true } label: {
                    Image(systemName: "cylinder.split.1x2")
                }
                .help("Manage Wine bottles")
            }
        }
    }

    private var emptyDetail: some View {
        ZStack {
            Color.charcoal.ignoresSafeArea()

            VStack(spacing: 28) {
                VStack(spacing: 14) {
                    Image("SmokeTransparent")
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                        .opacity(0.25)
                    Text("No game selected")
                        .font(.title3.bold())
                        .foregroundStyle(.white.opacity(0.5))
                }

                if let bottle = bottleManager.bottles.first {
                    VStack(spacing: 16) {
                        VStack(spacing: 5) {
                            Text("Install games via Steam")
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.7))
                            Text("Games appear in the sidebar automatically\nonce you close Steam.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.3))
                                .multilineTextAlignment(.center)
                        }

                        Button {
                            Task {
                                do {
                                    try await steamManager.launchSteamUI(in: bottle)
                                } catch {
                                    launchError = error.localizedDescription
                                }
                            }
                        } label: {
                            Label(
                                steamManager.isSteamRunning ? "Steam is Running" : "Open Steam",
                                systemImage: steamManager.isSteamRunning ? "checkmark.circle.fill" : "arrow.up.forward.app"
                            )
                            .frame(minWidth: 160)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(steamManager.isSteamRunning)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct StatusBar: View {
    let runtimeInstalled: Bool
    let bottleCount: Int
    let steamPinned: Bool

    var body: some View {
        HStack(spacing: 6) {
            statusChip(
                icon: runtimeInstalled ? "checkmark.circle.fill" : "xmark.circle.fill",
                label: runtimeInstalled ? "Runtime" : "No Runtime",
                color: runtimeInstalled ? .green : .red
            )
            statusChip(
                icon: bottleCount > 0 ? "cylinder.split.1x2.fill" : "cylinder.split.1x2",
                label: bottleCount > 0 ? "Bottle" : "No Bottle",
                color: bottleCount > 0 ? .green : .orange
            )
            statusChip(
                icon: steamPinned ? "lock.fill" : "lock.open",
                label: steamPinned ? "Pinned" : "Unpinned",
                color: steamPinned ? .blue : .orange
            )
        }
    }

    private func statusChip(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
    }
}
