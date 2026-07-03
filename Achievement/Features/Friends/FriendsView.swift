import SwiftUI
import AchievementCore

struct FriendsView: View {
    let home: HomeModel

    @State private var scrollOffset: CGFloat = 0

    private var friends: FriendsStore { home.friends }

    var body: some View {
        ZStack {
            AuroraBackground(scrollOffset: scrollOffset)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Friends")
                            .font(.editorialTitle)
                        Text("Pick a rival — friendly ones only.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 16)
                    .entrance(0)

                    content
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .trackScrollOffset(into: $scrollOffset)
            .refreshable { await friends.loadIfNeeded() }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: PlayerProfile.self) { friend in
            FriendCompareView(friend: friend, home: home)
        }
        .task { await friends.loadIfNeeded() }
    }

    @ViewBuilder
    private var content: some View {
        switch friends.phase {
        case .idle, .loading:
            VStack(spacing: 14) {
                ForEach(0..<5, id: \.self) { index in
                    HStack(spacing: 14) {
                        BreathingPlaceholder(shape: .circle)
                            .frame(width: 52, height: 52)
                        BreathingPlaceholder(shape: .capsule)
                            .frame(height: 36)
                    }
                    .entrance(index)
                }
            }
            .accessibilityLabel("Loading friends")

        case .unavailable(let message):
            EmptyStateView(
                motif: .lock,
                title: "Friends are hidden",
                message: message,
                actionTitle: "Try again",
                action: { Task { await friends.loadIfNeeded() } }
            )

        case .loaded where friends.friends.isEmpty:
            EmptyStateView(
                motif: .friends,
                title: "No rivals yet",
                message: "Steam friends appear here once they're visible on your profile."
            )

        case .loaded:
            VStack(spacing: 12) {
                ForEach(Array(friends.friends.enumerated()), id: \.element.id) { index, friend in
                    NavigationLink(value: friend) {
                        FriendRow(friend: friend)
                    }
                    .buttonStyle(.pressableCard)
                    .accessibilityIdentifier("friends.row")
                    .entrance(min(index + 1, 8))
                }
            }
        }
    }
}

private struct FriendRow: View {
    let friend: PlayerProfile

    var body: some View {
        HStack(spacing: 14) {
            AvatarView(profile: friend, size: 52)

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
            Text("Compare")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Theme.accent.opacity(0.13)))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassChip(.blob(30))
    }
}
