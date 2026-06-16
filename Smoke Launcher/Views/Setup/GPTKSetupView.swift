import SwiftUI

struct GPTKSetupView: View {
    @ObservedObject var vm: SetupViewModel
    @State private var gptkInstalled = PathProvider.gptkInstalled

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Game Porting Toolkit (Optional)", systemImage: "gamecontroller")
                .font(.title2.bold())

            Text("Apple's Game Porting Toolkit significantly improves compatibility with modern Windows games, especially those built on Unreal Engine 5. Without it, some games may have missing graphics or other rendering issues.")
                .foregroundStyle(.secondary)

            if gptkInstalled {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("Game Porting Toolkit is installed - Smoke will use it automatically.")
                        .font(.callout)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("How to install:")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        stepRow(number: "1", text: "Download Game Porting Toolkit from Apple's developer site (free Apple Developer account required).")
                        stepRow(number: "2", text: "Open the downloaded .dmg and run the installer package inside.")
                        stepRow(number: "3", text: "Once installed, click \"I've installed it\" below. Smoke will detect it automatically.")
                    }

                    Link(destination: URL(string: "https://developer.apple.com/games/")!) {
                        Label("Open Apple Developer - Games", systemImage: "arrow.up.right.square")
                            .font(.callout)
                    }
                    .padding(.top, 4)
                }
                .padding(14)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Text("You can skip this step and install GPTK later. Most games will still work without it.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .onAppear { gptkInstalled = PathProvider.gptkInstalled }
    }

    private func stepRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Color.accentColor)
                .clipShape(Circle())
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
