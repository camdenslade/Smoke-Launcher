import SwiftUI

struct LogView: View {
    let lines: [String]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(lineColor(line))
                            .textSelection(.enabled)
                            .id(idx)
                    }
                }
                .padding(8)
            }
            .background(Color(nsColor: .textBackgroundColor).opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .onChange(of: lines.count) { _ in
                if let last = lines.indices.last {
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func lineColor(_ line: String) -> Color {
        if line.hasPrefix("[wine]") { return .secondary.opacity(0.6) }  // Wine noise — dimmed
        if line.hasPrefix("[err]") { return .red.opacity(0.8) }         // Real errors — red
        if line.lowercased().contains("error") { return .orange }
        if line.lowercased().contains("complete") || line.lowercased().contains("success") { return .green }
        return .primary
    }
}
