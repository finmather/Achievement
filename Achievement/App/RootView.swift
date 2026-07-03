import SwiftUI

/// Switches between onboarding and the signed-in experience with a calm
/// cross-fade — no jarring swaps at launch.
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            switch model.session {
            case .restoring:
                LaunchPlaceholder()
            case .signedOut:
                WelcomeView()
            case .active(let home):
                MainTabView(home: home)
                    .id(home.id)
            }
        }
        .animation(.smooth(duration: 0.4), value: model.sessionPhase)
        .onAppear { model.restoreSession() }
    }
}

/// Shown for the instant it takes to restore the session — mirrors the
/// welcome screen's mark so a cold start never flashes.
private struct LaunchPlaceholder: View {
    var body: some View {
        ZStack {
            AuroraBackground(intensity: .hero)
            AppMark(size: 72)
        }
    }
}

/// The app icon motif, reused on launch and welcome.
struct AppMark: View {
    var size: CGFloat = 88

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Theme.accent, Color(red: 0.22, green: 0.72, blue: 0.93)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "trophy.fill")
                .font(.system(size: size * 0.42, weight: .medium))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: Theme.accent.opacity(0.35), radius: 18, y: 8)
    }
}
