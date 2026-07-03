import SwiftUI

struct WelcomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showingSignIn = false
    @State private var isVerifying = false

    @State private var markBreathes = false

    var body: some View {
        ZStack {
            AuroraBackground(intensity: .hero)

            VStack(spacing: 0) {
                Spacer(minLength: 48)

                AppMark()
                    .scaleEffect(markBreathes ? 1.04 : 1)
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 2.6).repeatForever(autoreverses: true)
                        ) {
                            markBreathes = true
                        }
                    }
                    .padding(.bottom, 24)
                    .entrance(0)

                Text("Achievement")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .entrance(1)

                Text("Your Steam library, beautifully completed.")
                    .font(.headline)
                    .fontWeight(.regular)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
                    .entrance(2)

                Spacer(minLength: 32)

                VStack(alignment: .leading, spacing: 22) {
                    FeatureRow(
                        symbol: "circle.dashed",
                        tint: Theme.accent,
                        title: "Every game, one ring",
                        detail: "Your whole library with live completion progress."
                    )
                    .entrance(3)
                    FeatureRow(
                        symbol: "sparkles",
                        tint: Theme.gold,
                        title: "Celebrate the rare ones",
                        detail: "Rarity, streaks and perfect games, made satisfying."
                    )
                    .entrance(4)
                    FeatureRow(
                        symbol: "person.2",
                        tint: Theme.accentTeal,
                        title: "Friendly rivalries",
                        detail: "Compare progress with friends, game by game."
                    )
                    .entrance(5)
                }
                .padding(.horizontal, 36)

                Spacer(minLength: 32)

                VStack(spacing: 14) {
                    Button {
                        showingSignIn = true
                    } label: {
                        Text("Sign in through Steam")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Capsule().fill(Theme.accentDuotone))
                            .shadow(color: Theme.accent.opacity(0.4), radius: 16, y: 8)
                    }
                    .buttonStyle(.pressable)
                    .disabled(isVerifying)
                    .entrance(6)

                    Button("Explore the demo") {
                        model.startDemo()
                    }
                    .font(.subheadline.weight(.medium))
                    .buttonStyle(.pressable)

                    if AppConfig.steamAPIKey.isEmpty {
                        Text("Developer note: live sync needs a Steam Web API key in Config/Secrets.xcconfig. The demo works without one.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 36)
            }
            .overlay {
                if isVerifying {
                    VerifyingOverlay()
                }
            }
        }
        .sheet(isPresented: $showingSignIn) {
            SteamSignInSheet { callback in
                showingSignIn = false
                isVerifying = true
                Task {
                    await model.completeSignIn(callback: callback)
                    isVerifying = false
                }
            }
        }
        .alert(
            "Sign-in didn't complete",
            isPresented: Binding(
                get: { model.signInError != nil && !isVerifying },
                set: { if !$0 { model.clearSignInError() } }
            ),
            actions: { Button("OK") {} },
            message: { Text(model.signInError ?? "") }
        )
    }
}

private struct FeatureRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.title3.weight(.medium))
                .foregroundStyle(tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct VerifyingOverlay: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                Text("Confirming with Steam…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(28)
            .glassChip(.blob(28))
        }
        .transition(.opacity)
    }
}
