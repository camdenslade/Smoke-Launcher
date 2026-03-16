import SwiftUI

enum BadgeStatus {
    case idle, running, success, error

    var color: Color {
        switch self {
        case .idle: return .gray
        case .running: return .yellow
        case .success: return .green
        case .error: return .red
        }
    }

    var label: String {
        switch self {
        case .idle: return "Idle"
        case .running: return "Running"
        case .success: return "Ready"
        case .error: return "Error"
        }
    }
}

struct StatusBadge: View {
    let status: BadgeStatus

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
            Text(status.label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
