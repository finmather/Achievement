import SwiftUI
import AchievementCore

struct FriendsView: View {
    let home: HomeModel

    private var friends: FriendsStore { home.friends }

    var body: some View {
        ZStack {
            ScreenBackground()

            Group {
                switch friends.phase {
                case .idle, .loading:
                    FriendsSkeleton()
                case .unavailable(let message):
                    ContentUnavailableView {
                        Label("Friends Unavailable", systemImage: "person.2.slash")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Try Again") {
                            Task { await friends.loadIfNeeded() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                case .loaded where friends.friends.isEmpty:
                    ContentUnavailableView(
                        "No Friends Found",
                        systemImage: "person.2",
                        description: Text("Steam friends appear here once they're visible on your profile.")
                    )
                case .loaded:
                    list
                }
            }
        }
        .navigationTitle("Friends")
        .navigationDestination(for: PlayerProfile.self) { friend in
            FriendCompareView(friend: friend, home: home)
        }
        .task { await friends.loadIfNeeded() }
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("Pick a friend to compare progress, game by game.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)

                ForEach(friends.friends) { friend in
                    NavigationLink(value: friend) {
                        FriendRow(friend: friend)
                    }
                    .buttonStyle(.pressableCard)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .refreshable { await friends.loadIfNeeded() }
    }
}

private struct FriendRow: View {
    let friend: PlayerProfile

    var body: some View {
        HStack(spacing: 14) {
            AvatarView(profile: friend, size: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.personaName)
                    .font(.subheadline.weight(.semibold))
                if let realName = friend.realName, !realName.isEmpty {
                    Text(realName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Label("Compare", systemImage: "chevron.right")
                .labelStyle(.iconOnly)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .cardSurface(cornerRadius: 18)
    }
}

private struct FriendsSkeleton: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.quaternary)
                        .frame(height: 76)
                }
            }
            .padding(20)
        }
        .shimmering()
        .scrollDisabled(true)
        .accessibilityLabel("Loading friends")
    }
}
