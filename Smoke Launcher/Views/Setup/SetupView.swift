import SwiftUI

struct SetupView: View {
    @StateObject private var vm = SetupViewModel()
    @Binding var isPresented: Bool
    @EnvironmentObject var bottleManager: BottleManager
    @EnvironmentObject var steamManager: SteamManager
    @EnvironmentObject var runtimeManager: RuntimeManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Logo header
                HStack(spacing: 10) {
                    Image("SmokeTransparent")
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 32, height: 32)
                    Text("Smoke Launcher")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                .padding(.top, 24)

                // Step progress indicators
                HStack(spacing: 0) {
                    ForEach(SetupStep.allCases.dropLast(), id: \.rawValue) { s in
                        stepIndicator(s)
                        if s.rawValue < SetupStep.allCases.dropLast().count - 1 {
                            Rectangle()
                                .fill(vm.step.rawValue > s.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
                                .frame(height: 2)
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 16)

                Divider().padding(.top, 16)

                // Step content
                ScrollView {
                    Group {
                        switch vm.step {
                        case .runtime:
                            RuntimeDownloadView()
                        case .bottleSetup:
                            BottleSetupView(vm: vm)
                        case .steamInstall:
                            SteamInstallView(vm: vm)
                        case .done:
                            doneView
                        }
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider()

                // Navigation buttons
                HStack {
                    if vm.step != .runtime {
                        Button("Back") {
                            if let prev = SetupStep(rawValue: vm.step.rawValue - 1) {
                                vm.step = prev
                            }
                        }
                        .disabled(vm.isWorking || runtimeManager.isDownloading)
                    }

                    Spacer()

                    // Runtime step: Continue once installed
                    if vm.step == .runtime {
                        Button("Continue") { vm.advance() }
                            .buttonStyle(.borderedProminent)
                            .keyboardShortcut(.return)
                            .disabled(!runtimeManager.isInstalled)
                    }

                    if vm.step == .done {
                        Button("Done") { isPresented = false }
                            .buttonStyle(.borderedProminent)
                            .keyboardShortcut(.return)
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 540, height: 560)
        .onAppear {
            // If already installed, skip to bottle setup
            if runtimeManager.isInstalled && vm.step == .runtime {
                vm.step = .bottleSetup
            }
        }
    }

    private var doneView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Setup Complete", systemImage: "party.popper")
                .font(.title2.bold())
            Text("Your Wine bottle is ready and Steam is installed. Add games from the library to get started.")
                .foregroundStyle(.secondary)
            HStack {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                if let m = runtimeManager.manifest {
                    Text("Wine \(m.wineVersion) + DXVK \(m.dxvkVersion)")
                } else {
                    Text("Wine runtime installed")
                }
            }
            HStack {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("Wine bottle: steam")
            }
            HStack {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("Steam installed and version pinned")
            }
        }
    }

    private func stepIndicator(_ step: SetupStep) -> some View {
        let isCurrent = vm.step == step
        let isDone = vm.step.rawValue > step.rawValue
        return VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isDone ? Color.accentColor : isCurrent ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.2))
                    .frame(width: 28, height: 28)
                if isDone {
                    Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                } else {
                    Text("\(step.rawValue + 1)").font(.caption.bold())
                        .foregroundStyle(isCurrent ? Color.accentColor : Color.secondary)
                }
            }
            Text(stepLabel(step)).font(.caption2).foregroundStyle(isCurrent ? .primary : .secondary)
        }
    }

    private func stepLabel(_ step: SetupStep) -> String {
        switch step {
        case .runtime: return "Runtime"
        case .bottleSetup: return "Bottle"
        case .steamInstall: return "Steam"
        case .done: return "Done"
        }
    }
}
