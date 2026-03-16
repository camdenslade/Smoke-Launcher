import SwiftUI

struct ProgressOverlay: View {
    let message: String
    var progress: Double? = nil

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                Text(message)
                    .font(.headline)
                if let p = progress {
                    ProgressView(value: p)
                        .frame(width: 200)
                }
            }
            .padding(24)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
