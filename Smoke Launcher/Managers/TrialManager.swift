import SwiftUI

// MARK: - Trial state

final class TrialManager {
    static let shared = TrialManager()
    private let key = "smoke.launchCount"
    static let trialLimit = 3

    var launchCount: Int {
        get { UserDefaults.standard.integer(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    var isTrialExpired: Bool { launchCount >= Self.trialLimit }
    var launchesRemaining: Int { max(0, Self.trialLimit - launchCount) }

    func recordLaunch() { launchCount += 1 }
}

// MARK: - Paywall sheet

struct TrialPaywallView: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.indigo)

            VStack(spacing: 8) {
                Text("Free trial ended")
                    .font(.title2.bold())
                Text("You've used your \(TrialManager.trialLimit) free launches.\nGet Smoke Launcher to keep playing.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                Link(destination: URL(string: "https://buy.stripe.com/dRm28rcGg8sHesRcbh5c400")!) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Buy Smoke Launcher - $5")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.indigo, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.white)
                }

                Button("Maybe later") { isPresented = false }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(32)
        .frame(width: 360)
    }
}
