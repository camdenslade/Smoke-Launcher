import SwiftUI

// MARK: - Image URL resolver

/// Resolves Steam CDN image URLs for a given App ID.
/// Newer games use hashed CDN paths not guessable from the App ID alone.
@MainActor
final class SteamImageCache {
    static let shared = SteamImageCache()

    private var headerCache: [String: URL?] = [:]
    private var iconCache: [String: URL?] = [:]
    private var headerInFlight: [String: Task<URL?, Never>] = [:]
    private var iconInFlight: [String: Task<URL?, Never>] = [:]

    // MARK: Header art (460x215)

    func headerURL(for appID: String) async -> URL? {
        if let cached = headerCache[appID] { return cached }
        if let existing = headerInFlight[appID] { return await existing.value }
        let task = Task<URL?, Never> { await self.fetchHeaderURL(appID: appID) }
        headerInFlight[appID] = task
        let result = await task.value
        headerCache[appID] = result
        headerInFlight.removeValue(forKey: appID)
        return result
    }

    private func fetchHeaderURL(appID: String) async -> URL? {
        // Try legacy CDN first (fast, works for most older games)
        let legacyURL = URL(string: "https://cdn.cloudflare.steamstatic.com/steam/apps/\(appID)/header.jpg")!
        if let (_, response) = try? await URLSession.shared.data(from: legacyURL),
           (response as? HTTPURLResponse)?.statusCode == 200 {
            return legacyURL
        }
        // Fall back to Store API for newer games with hashed CDN paths
        return await fetchAppDetails(appID: appID)?["header_image"].flatMap { URL(string: $0) }
    }

    // MARK: Square icon (from community CDN)

    func iconURL(for appID: String) async -> URL? {
        if let cached = iconCache[appID] { return cached }
        if let existing = iconInFlight[appID] { return await existing.value }
        let task = Task<URL?, Never> { await self.fetchIconURL(appID: appID) }
        iconInFlight[appID] = task
        let result = await task.value
        iconCache[appID] = result
        iconInFlight.removeValue(forKey: appID)
        return result
    }

    private func fetchIconURL(appID: String) async -> URL? {
        guard let hash = await fetchAppDetails(appID: appID)?["icon"] else { return nil }
        return URL(string: "https://cdn.cloudflare.steamstatic.com/steamcommunity/public/images/apps/\(appID)/\(hash).jpg")
    }

    // MARK: Shared appdetails fetch

    private func fetchAppDetails(appID: String) async -> [String: String]? {
        guard let apiURL = URL(string: "https://store.steampowered.com/api/appdetails?appids=\(appID)&filters=basic") else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: apiURL) else { return nil }
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let entry = json[appID] as? [String: Any],
            let appData = entry["data"] as? [String: Any]
        else { return nil }
        // Flatten string fields we care about
        var result: [String: String] = [:]
        if let v = appData["header_image"] as? String { result["header_image"] = v }
        if let v = appData["icon"] as? String { result["icon"] = v }
        return result
    }
}

// MARK: - Header art (460x215)

struct SteamArtworkView: View {
    let appID: String?
    var cornerRadius: CGFloat = 8
    var contentMode: ContentMode = .fill

    @State private var resolvedURL: URL?

    var body: some View {
        Group {
            if let url = resolvedURL {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: contentMode)
                } placeholder: {
                    placeholder
                }
            } else {
                placeholder
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .task(id: appID) {
            resolvedURL = nil
            guard let id = appID else { return }
            resolvedURL = await SteamImageCache.shared.headerURL(for: id)
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

// MARK: - Square icon (cropped from header art)

struct SteamIconView: View {
    let appID: String?
    var size: CGFloat = 34
    var cornerRadius: CGFloat = 8

    @State private var resolvedURL: URL?

    var body: some View {
        Group {
            if let url = resolvedURL {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    fallback
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .task(id: appID) {
            resolvedURL = nil
            guard let id = appID else { return }
            // Prefer the dedicated square icon; fall back to header art
            if let iconURL = await SteamImageCache.shared.iconURL(for: id) {
                resolvedURL = iconURL
            } else {
                resolvedURL = await SteamImageCache.shared.headerURL(for: id)
            }
        }
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
