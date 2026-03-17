import SwiftUI

struct GameRowView: View {
    let game: Game
    let isRunning: Bool
    let isSelected: Bool
    var bottlePrefix: URL?

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                SteamIconView(appID: game.steamAppID, bottlePrefix: bottlePrefix, size: 42, cornerRadius: 9)
                if isRunning {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 9, height: 9)
                        .overlay(Circle().stroke(Color.charcoal, lineWidth: 1.5))
                        .offset(x: 2, y: 2)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(game.displayName)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if isRunning {
                    Label("Running", systemImage: "circle.fill")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.green)
                        .symbolRenderingMode(.multicolor)
                } else if let played = game.lastPlayedAt {
                    HStack(spacing: 4) {
                        Text(played, format: .relative(presentation: .named))
                        if game.totalPlayTime > 0 {
                            Text("·")
                            Text(game.formattedPlayTime)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
                } else {
                    Text("Never played")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.3))
                }
            }

            Spacer(minLength: 0)

            if isRunning {
                ProgressView()
                    .scaleEffect(0.6)
                    .tint(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .glassCard(cornerRadius: 10, selected: isSelected)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
