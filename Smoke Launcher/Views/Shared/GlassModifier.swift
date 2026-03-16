import SwiftUI

// MARK: - Liquid Glass Card

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 12
    var selected: Bool = false

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    // Inner gradient simulates light refracting through top edge
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(LinearGradient(
                                colors: [
                                    .white.opacity(selected ? 0.18 : 0.10),
                                    .white.opacity(selected ? 0.04 : 0.01)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                    }
                    // Edge highlight — the "glass rim" refraction effect
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(selected ? 0.45 : 0.22),
                                        .white.opacity(selected ? 0.12 : 0.04)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
            }
            .shadow(color: .black.opacity(selected ? 0.35 : 0.20), radius: selected ? 14 : 8, y: selected ? 5 : 2)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 12, selected: Bool = false) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, selected: selected))
    }
}

// MARK: - Charcoal palette

extension Color {
    static let charcoal = Color(red: 0.07, green: 0.07, blue: 0.09)
    static let charcoalMid = Color(red: 0.11, green: 0.11, blue: 0.14)
}

// MARK: - Ambient art background

struct AmbientBackground: View {
    let appID: String?
    var blurRadius: CGFloat = 60
    var opacity: Double = 0.28

    private var artURL: URL? {
        guard let id = appID else { return nil }
        return URL(string: "https://cdn.cloudflare.steamstatic.com/steam/apps/\(id)/header.jpg")
    }

    var body: some View {
        ZStack {
            Color.charcoal

            if let url = artURL {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .blur(radius: blurRadius)
                        .opacity(opacity)
                        .blendMode(.plusLighter)
                } placeholder: { EmptyView() }
                .transition(.opacity.animation(.easeInOut(duration: 0.6)))
            }

            // Vignette to keep edges dark
            RadialGradient(
                colors: [.clear, .black.opacity(0.5)],
                center: .center,
                startRadius: 100,
                endRadius: 600
            )
        }
        .ignoresSafeArea()
    }
}
