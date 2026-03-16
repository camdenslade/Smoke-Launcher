import SwiftUI

struct AddGameView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var bottleManager: BottleManager

    @State private var displayName = ""
    @State private var exePath = ""
    @State private var selectedBottleID: UUID?
    @State private var error: String?

    var selectedBottle: Bottle? {
        guard let id = selectedBottleID else { return bottleManager.bottles.first }
        return bottleManager.bottles.first { $0.id == id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Add Game")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 6) {
                Text("Display Name").font(.caption.bold())
                TextField("e.g. Dark Souls III", text: $displayName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Game Executable (.exe)").font(.caption.bold())
                HStack {
                    TextField("/path/to/game.exe", text: $exePath)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse") { browseForExe() }
                        .buttonStyle(.bordered)
                }
            }

            if bottleManager.bottles.count > 1 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Wine Bottle").font(.caption.bold())
                    Picker("Bottle", selection: $selectedBottleID) {
                        ForEach(bottleManager.bottles) { b in
                            Text(b.name).tag(Optional(b.id))
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            if let err = error {
                Text(err).foregroundStyle(.red).font(.caption)
            }

            HStack {
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.escape)
                Spacer()
                Button("Add Game") { addGame() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return)
                    .disabled(displayName.isEmpty || exePath.isEmpty || selectedBottle == nil)
            }
        }
        .padding(24)
        .frame(width: 420)
    }

    private func browseForExe() {
        let panel = NSOpenPanel()
        panel.title = "Select game executable"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = []
        panel.message = "Select a Windows .exe file"
        if panel.runModal() == .OK, let url = panel.url {
            exePath = url.path
            if displayName.isEmpty {
                displayName = url.deletingPathExtension().lastPathComponent
            }
        }
    }

    private func addGame() {
        guard let bottle = selectedBottle else {
            error = "No bottle available. Complete setup first."
            return
        }
        let game = Game(
            displayName: displayName,
            exePath: URL(fileURLWithPath: exePath),
            bottleID: bottle.id
        )
        do {
            try gameManager.register(game: game)
            isPresented = false
        } catch let e as AppError {
            error = e.localizedDescription
        } catch let e {
            error = e.localizedDescription
        }
    }
}
