import SwiftUI
import AchievementCore

struct MainTabView: View {
    let home: HomeModel

    var body: some View {
        TabView {
            NavigationStack {
                DashboardView(home: home)
                    .gameDestination(home: home)
            }
            .tabItem { Label("Overview", systemImage: "trophy.fill") }

            NavigationStack {
                LibraryView(home: home)
                    .gameDestination(home: home)
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
        .task { await home.start() }
    }
}

extension View {
    /// Registers the shared push destination for game detail screens.
    func gameDestination(home: HomeModel) -> some View {
        navigationDestination(for: Game.self) { game in
            GameDetailView(game: game, home: home)
        }
    }
}
