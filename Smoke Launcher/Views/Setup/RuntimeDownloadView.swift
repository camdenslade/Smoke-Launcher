import SwiftUI

struct RuntimeDownloadView: View {
    @EnvironmentObject var runtimeManager: RuntimeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Download Runtime", systemImage: "arrow.down.circle")
                .font(.title2.bold())

            Text("Smoke Launcher bundles its own Wine runtime — no external tools needed.")
                .foregroundStyle(.secondary)

            // Component list
            VStack(spacing: 8) {
                componentRow(
                    icon: "wineglass",
                    title: "Wine Staging",
                    subtitle: runtimeManager.manifest?.wineVersion ?? "latest",
                    note: "Runs Windows games (~300 MB)"
                )
                componentRow(
                    icon: "cpu",
                    title: "DXVK-macOS",
                    subtitle: runtimeManager.manifest?.dxvkVersion ?? "latest",
                    note: "DirectX → Metal translation (~3 MB)"
                )
                componentRow(
                    icon: "scroll",
                    title: "winetricks",
                    subtitle: "20260125",
                    note: "Installs Windows DLL dependencies"
                )
            }

            if runtimeManager.isInstalled {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    VStack(alignment: .leading) {
                        Text("Runtime installed")
                            .font(.headline)
                        if let m = runtimeManager.manifest {
                            Text("Wine \(m.wineVersion) · DXVK \(m.dxvkVersion)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else if runtimeManager.isDownloading {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        ProgressView().scaleEffect(0.8)
                        Text(runtimeManager.currentStep)
                            .font(.callout)
                        Spacer()
                    }

                    ProgressView(value: runtimeManager.overallProgress)

                    HStack {
                        Text("\(Int(runtimeManager.overallProgress * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)

                        if runtimeManager.downloadBytesPerSec > 0 {
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text(speedString(runtimeManager.downloadBytesPerSec))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if let eta = runtimeManager.downloadETA {
                            Text(etaString(eta))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !runtimeManager.log.isEmpty {
                        LogView(lines: runtimeManager.log)
                            .frame(height: 100)
                    }
                }
            } else if runtimeManager.hasResumeData {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .foregroundStyle(.orange)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Download was interrupted")
                                .font(.headline)
                            Text("You can continue where you left off.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    HStack(spacing: 10) {
                        Button {
                            Task { await runtimeManager.install() }
                        } label: {
                            Label("Resume Download", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Button("Start Over") {
                            runtimeManager.discardResumeData()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
            } else {
                Button {
                    Task { await runtimeManager.install() }
                } label: {
                    Label("Download Runtime (~300 MB)", systemImage: "arrow.down.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            if let err = runtimeManager.error {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(err).foregroundStyle(.red).font(.caption)
                        Button("Retry") { Task { await runtimeManager.install() } }
                            .font(.caption)
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private func speedString(_ bps: Int64) -> String {
        let mbps = Double(bps) / 1_048_576
        if mbps >= 1 {
            return String(format: "%.1f MB/s", mbps)
        } else {
            return String(format: "%.0f KB/s", Double(bps) / 1024)
        }
    }

    private func etaString(_ seconds: TimeInterval) -> String {
        if seconds < 5 { return "Almost done" }
        let s = Int(seconds)
        if s < 60 { return "\(s)s remaining" }
        let m = s / 60
        let rem = s % 60
        if rem == 0 { return "\(m)m remaining" }
        return "\(m)m \(rem)s remaining"
    }

    private func componentRow(icon: String, title: String, subtitle: String, note: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title).font(.callout.bold())
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Text(note).font(.caption2).foregroundStyle(.tertiary)
            }
            Spacer()
            if runtimeManager.isInstalled {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }
        }
        .padding(10)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
