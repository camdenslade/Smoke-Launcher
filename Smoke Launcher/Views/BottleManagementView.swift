import SwiftUI

struct BottleManagementView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var bottleManager: BottleManager
    @EnvironmentObject var runtimeManager: RuntimeManager
    @State private var selectedBottle: Bottle?
    @State private var showDeleteConfirm = false
    @State private var bottleToDelete: Bottle?
    @State private var showCreateBottle = false

    var body: some View {
        NavigationSplitView {
            // Bottle list
            List(bottleManager.bottles, selection: $selectedBottle) { bottle in
                BottleRowView(bottle: bottle)
                    .tag(bottle)
                    .contextMenu {
                        Button("Delete Bottle", role: .destructive) {
                            bottleToDelete = bottle
                            showDeleteConfirm = true
                        }
                    }
            }
            .listStyle(.sidebar)
            .navigationTitle("Bottles")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showCreateBottle = true } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(runtimeManager.winePath == nil)
                    .help("Create a new Wine bottle")
                }
            }
            .onAppear {
                selectedBottle = bottleManager.bottles.first
            }
        } detail: {
            if let bottle = selectedBottle {
                BottleDetailView(bottle: bottle)
            } else {
                Text("Select a bottle")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 680, height: 440)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { isPresented = false }
                    .keyboardShortcut(.return)
            }
        }
        .confirmationDialog(
            "Delete \"\(bottleToDelete?.name ?? "")\"?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Bottle", role: .destructive) {
                if let b = bottleToDelete {
                    try? bottleManager.delete(b)
                    if selectedBottle?.id == b.id { selectedBottle = bottleManager.bottles.first }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete the Wine prefix and all its contents. Games installed inside it will no longer work.")
        }
        .sheet(isPresented: $showCreateBottle) {
            CreateBottleView(isPresented: $showCreateBottle)
        }
    }
}

// MARK: - Bottle Row

struct BottleRowView: View {
    let bottle: Bottle

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "cylinder.split.1x2")
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(bottle.name)
                    .font(.headline)
                Text(bottle.arch.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Bottle Detail

struct BottleDetailView: View {
    let bottle: Bottle
    @EnvironmentObject var bottleManager: BottleManager
    @EnvironmentObject var runtimeManager: RuntimeManager
    @State private var isRunningWinetricks = false
    @State private var winetricksLog: [String] = []

    var prefixSizeMB: String {
        let url = bottle.prefixPath
        guard let size = try? FileManager.default.allocatedSizeOfDirectory(at: url) else { return "?" }
        return String(format: "%.0f MB", Double(size) / 1_048_576)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Name + path
                GroupBox("Bottle Info") {
                    infoGrid
                }

                // DXVK toggle
                GroupBox("Graphics") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("DXVK (DirectX → Metal)", isOn: Binding(
                            get: { bottle.dxvkEnabled },
                            set: { bottleManager.setDXVK(enabled: $0, bottleID: bottle.id) }
                        ))
                        Text("Translates DirectX 10/11 calls to Metal. Required for most modern games.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }

                // Winetricks
                GroupBox("Windows Components") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Install additional Windows runtime libraries needed by some games.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            quickInstallButton("vcrun2022", label: "Visual C++ 2022")
                            quickInstallButton("dotnet48", label: ".NET 4.8")
                            quickInstallButton("d3dx11_43", label: "D3DX11")
                        }

                        if !winetricksLog.isEmpty {
                            LogView(lines: winetricksLog).frame(height: 100)
                        }
                    }
                    .padding(.top, 4)
                }

                // Danger zone
                GroupBox {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Reset Bottle")
                                .font(.callout.bold())
                            Text("Re-run wineboot to repair a broken prefix.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Reset") { resetBottle() }
                            .buttonStyle(.bordered)
                            .disabled(isRunningWinetricks || runtimeManager.winePath == nil)
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle(bottle.name)
    }

    private var infoGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
            GridRow {
                Text("Path").font(.caption).foregroundStyle(.secondary)
                Text(bottle.prefixPath.path).font(.caption).textSelection(.enabled)
            }
            GridRow {
                Text("Architecture").font(.caption).foregroundStyle(.secondary)
                Text(bottle.arch.rawValue).font(.caption)
            }
            GridRow {
                Text("Disk Usage").font(.caption).foregroundStyle(.secondary)
                Text(prefixSizeMB).font(.caption)
            }
            GridRow {
                Text("Created").font(.caption).foregroundStyle(.secondary)
                Text(bottle.createdAt.formatted(date: .abbreviated, time: .omitted)).font(.caption)
            }
        }
        .padding(.top, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func quickInstallButton(_ component: String, label: String) -> some View {
        Button(label) {
            Task {
                isRunningWinetricks = true
                winetricksLog = []
                defer { isRunningWinetricks = false }
                try? await bottleManager.installWinetricks(into: bottle, components: [component])
                winetricksLog = bottleManager.setupLog
            }
        }
        .buttonStyle(.bordered)
        .font(.caption)
        .disabled(isRunningWinetricks || runtimeManager.winePath == nil)
    }

    private func resetBottle() {
        guard let winePath = runtimeManager.winePath else { return }
        Task {
            isRunningWinetricks = true
            winetricksLog = []
            defer { isRunningWinetricks = false }
            _ = try? await bottleManager.createBottle(name: bottle.name, winePath: winePath)
            winetricksLog = bottleManager.setupLog
        }
    }
}

// MARK: - Create Bottle

struct CreateBottleView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var bottleManager: BottleManager
    @EnvironmentObject var runtimeManager: RuntimeManager
    @State private var bottleName = ""
    @State private var arch: WineArch = .win64
    @State private var isCreating = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("New Bottle").font(.title2.bold())

            VStack(alignment: .leading, spacing: 6) {
                Text("Name").font(.caption.bold())
                TextField("e.g. game-prefix", text: $bottleName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Architecture").font(.caption.bold())
                Picker("Architecture", selection: $arch) {
                    ForEach(WineArch.allCases, id: \.self) { a in
                        Text(a.rawValue).tag(a)
                    }
                }
                .pickerStyle(.segmented)
            }

            if let err = error {
                Text(err).foregroundStyle(.red).font(.caption)
            }

            HStack {
                Button("Cancel") { isPresented = false }.keyboardShortcut(.escape)
                Spacer()
                Button("Create") { create() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return)
                    .disabled(bottleName.isEmpty || isCreating || runtimeManager.winePath == nil)
            }
        }
        .padding(24)
        .frame(width: 360)
    }

    private func create() {
        guard let winePath = runtimeManager.winePath else { return }
        isCreating = true
        error = nil
        Task {
            defer { isCreating = false }
            do {
                _ = try await bottleManager.createBottle(name: bottleName, arch: arch, winePath: winePath)
                isPresented = false
            } catch let e {
                error = e.localizedDescription
            }
        }
    }
}

// MARK: - FileManager extension for directory size

extension FileManager {
    func allocatedSizeOfDirectory(at url: URL) throws -> UInt64 {
        var size: UInt64 = 0
        let enumerator = self.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey])
        while let fileURL = enumerator?.nextObject() as? URL {
            size += UInt64((try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return size
    }
}
