import SwiftUI
import AchievementCore

struct MainTabView: View {
    let home: HomeModel

    @State private var celebration: UnlockEvent?
    @State private var celebrationExtra = 0

    var body: some View {
        TabView {
            NavigationStack {
                DashboardView(home: home) { unlock in
                    present(unlock, extra: 0)
                }
                .gameDestination(home: home)
            }
            .tabItem { Label("Overview", systemImage: "trophy.fill") }

            NavigationStack {
                LibraryView(home: home)
            }
            .tabItem { Label("Library", systemImage: "square.stack.fill") }

            NavigationStack {
                FriendsView(home: home)
                    .gameDestination(home: home)
            }
            .tabItem { Label("Friends", systemImage: "person.2.fill") }

            NavigationStack {
                ProfileView(home: home)
            }
            .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
        }
        .overlay {
            if let celebration {
                UnlockCelebrationView(
                    unlock: celebration,
                    extraCount: celebrationExtra
                ) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.celebration = nil
                    }
                    home.library.acknowledgeFreshUnlocks()
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .onChange(of: home.library.latestFreshUnlock) { _, fresh in
            if let fresh {
                present(fresh, extra: home.library.freshUnlockCount - 1)
            }
        }
        .task {
            await home.start()
            // CI capture hook — see .github/workflows/ios-screenshots.yml.
            if ProcessInfo.processInfo.environment["UI_TEST_CELEBRATE"] == "1",
               let sample = SampleData.allUnlocks().first {
                try? await Task.sleep(for: .seconds(1.5))
                present(sample, extra: 2)
            }
        }
    }

    private func present(_ unlock: UnlockEvent, extra: Int) {
        celebrationExtra = max(0, extra)
        withAnimation(.easeIn(duration: 0.25)) {
            celebration = unlock
        }
    }
}

extension View {
    /// Push destination for tabs without a zoom-transition namespace
    /// (Library registers its own so covers can zoom into the detail page).
    func gameDestination(home: HomeModel) -> some View {
        navigationDestination(for: Game.self) { game in
            GameDetailView(game: game, home: home)
        }
    }
}
