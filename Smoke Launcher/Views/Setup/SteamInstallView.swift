import SwiftUI

struct SteamInstallView: View {
    @ObservedObject var vm: SetupViewModel
    @EnvironmentObject var steamManager: SteamManager
    @EnvironmentObject var bottleManager: BottleManager

    var bottle: Bottle? { bottleManager.bottles.first }

    /// True while the installer GUI is running and the user needs to click through it.
    var isWaitingForInstallerUI: Bool {
        steamManager.installLog.contains(where: { $0.contains("Running Steam installer") })
        && !steamManager.installLog.contains(where: { $0.contains("Shutting down") })
    }

    /// True during the bootstrap phase - Steam is downloading its components silently.
    var isBootstrapping: Bool {
        steamManager.installLog.contains(where: { $0.contains("Starting Steam for first-run") })
        && !steamManager.installLog.contains(where: { $0.contains("first-run complete") || $0.contains("Steam components already") })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Install Steam", systemImage: "gamecontroller")
                .font(.title2.bold())

            Text("Downloads the Steam client and installs it into your Wine bottle. Auto-updates are disabled to prevent crashes.")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                featureRow("Download Steam installer", done: steamManager.pinnedBuild != nil)
                featureRow("Install into Wine bottle", done: steamManager.pinnedBuild != nil)
                featureRow("Pin version / block auto-update", done: bottle.map { steamManager.isVersionPinned(in: $0) } ?? false)
            }

            if steamManager.isInstalling && isWaitingForInstallerUI {
                callout(
                    icon: "cursorarrow.click",
                    color: .orange,
                    title: "Action required",
                    message: "A Steam installer window appeared. Click through it - if Steam launches at the end and shows an error, just dismiss it and return here."
                )
            }

            if steamManager.isInstalling && isBootstrapping {
                callout(
                    icon: "arrow.down.circle",
                    color: .blue,
                    title: "Downloading Steam components",
                    message: "Steam is running in the background downloading its client files. This takes 2–5 minutes. Do not close the app."
                )
            }

            if !steamManager.installLog.isEmpty {
                LogView(lines: steamManager.installLog)
                    .frame(minHeight: 100, maxHeight: 200)
            }

            if let err = vm.error {
                Text(err).foregroundStyle(.red).font(.caption)
            }

            if steamManager.pinnedBuild != nil {
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("Steam installed and pinned.")
                }
                Button("Continue") { vm.advance() }
                    .buttonStyle(.borderedProminent)
            } else {
                Button {
                    guard let b = bottle else { return }
                    Task { await vm.installSteam(steamManager: steamManager, bottle: b) }
                } label: {
                    if steamManager.isInstalling {
                        HStack { ProgressView().scaleEffect(0.8); Text("Installing...") }
                    } else {
                        Label("Install Steam", systemImage: "arrow.down.circle")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(steamManager.isInstalling || bottle == nil)
            }
        }
    }

    private func callout(icon: String, color: Color, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.callout.bold())
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private func featureRow(_ text: String, done: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? .green : .secondary)
            Text(text).font(.callout)
        }
    }
}
