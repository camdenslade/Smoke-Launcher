import SwiftUI

struct BottleSetupView: View {
    @ObservedObject var vm: SetupViewModel
    @EnvironmentObject var bottleManager: BottleManager
    @EnvironmentObject var runtimeManager: RuntimeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Create Wine Bottle", systemImage: "archivebox")
                .font(.title2.bold())

            Text("A Wine bottle is an isolated Windows environment. We'll create one configured for Steam.")
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text("DXVK").font(.caption.bold())
                    Text("DirectX → Metal translation").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
            .padding(10)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text("ESync").font(.caption.bold())
                    Text("Better CPU synchronization").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
            .padding(10)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if !bottleManager.setupLog.isEmpty {
                LogView(lines: bottleManager.setupLog)
                    .frame(minHeight: 100, maxHeight: 200)
            }

            if let err = vm.error {
                Text(err).foregroundStyle(.red).font(.caption)
            }

            Button {
                Task { await vm.createBottle(bottleManager: bottleManager, runtimeManager: runtimeManager) }
            } label: {
                if bottleManager.isWorking {
                    HStack { ProgressView().scaleEffect(0.8); Text("Creating...") }
                } else {
                    Label("Create Bottle", systemImage: "plus.app")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(bottleManager.isWorking || !runtimeManager.isInstalled)
        }
    }
}
