import SwiftUI

/// Loads Steam header art (460×215) from Valve's CDN for a given App ID.
/// Falls back to a tinted gamecontroller icon if no appID or download fails.
struct SteamArtworkView: View {
    let appID: String?
    var cornerRadius: CGFloat = 8

    private var headerURL: URL? {
        guard let id = appID else { return nil }
        return URL(string: "https://cdn.cloudflare.steamstatic.com/steam/apps/\(id)/header.jpg")
    }

    var body: some View {
        if let url = headerURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure, .empty:
                    placeholder
                @unknown default:
                    placeholder
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            placeholder
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }

    private var placeholder: some View {
        ZStack {
            Color.primary.opacity(0.06)
            Image(systemName: "gamecontroller.fill")
                .font(.title2)
                .foregroundStyle(.quaternary)
        }
    }
}

/// Square icon variant — uses Steam's small capsule art (231×87 treated as square crop).
struct SteamIconView: View {
    let appID: String?
    var size: CGFloat = 34
    var cornerRadius: CGFloat = 8

    private var iconURL: URL? {
        guard let id = appID else { return nil }
        // header.jpg (460x215) is the most reliably available Steam CDN image
        return URL(string: "https://cdn.cloudflare.steamstatic.com/steam/apps/\(id)/header.jpg")
    }

    var body: some View {
        Group {
            if let url = iconURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var fallback: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.accentColor.opacity(0.12))
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: size * 0.38))
                .foregroundStyle(Color.accentColor)
        }
    }
}
