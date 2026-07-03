import SwiftUI
import AchievementCore

/// Head-to-head, kept friendly: overlapping avatars, organic duel bars with
/// a glow on whoever leads, and warm language — rivals, never losers.
struct FriendCompareView: View {
    let home: HomeModel
    @State private var model: ComparisonModel
    @State private var scrollOffset: CGFloat = 0

    init(friend: PlayerProfile, home: HomeModel) {
        self.home = home
        _model = State(initialValue: ComparisonModel(
            friend: friend,
            myGames: home.library.games,
            dataSource: home.dataSource
        ))
    }

    var body: some View {
        ZStack {
            AuroraBackground(intensity: .hero, scrollOffset: scrollOffset)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VersusHeader(me: home.profile, friend: model.friend)
                        .frame(maxWidth: .infinity)
                        .entrance(0)

                    if let comparison = model.comparison {
                        loadedContent(comparison)
                    } else if let error = model.errorMessage {
                        EmptyStateView(
                            motif: .lock,
                            title: "Can't compare",
                            message: error
                        )
                    } else {
                        VStack(spacing: 16) {
                            ForEach(0..<4, id: \.self) { _ in
                                BreathingPlaceholder(shape: .capsule)
                                    .frame(height: 40)
                            }
                        }
                        .accessibilityLabel("Loading comparison")
                    }
                }
                .padding(.horizontal, Tokens.screenMargin)
                .padding(.bottom, 40)
            }
            .scrollClipDisabled()
            .trackScrollOffset(into: $scrollOffset)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task { await model.load() }
    }

    @ViewBuilder
    private func loadedContent(_ comparison: FriendComparison) -> some View {
        VStack(spacing: 22) {
            DuelBar(
                label: "Perfect games",
                mine: Double(comparison.myStats.perfectGames),
                theirs: Double(comparison.friendStats.perfectGames),
                display: { "\(Int($0))" }
            )
            DuelBar(
                label: "Achievements",
                mine: Double(comparison.myStats.unlockedAchievements),
                theirs: Double(comparison.friendStats.unlockedAchievements),
                display: { Int($0).formatted() }
            )
            DuelBar(
                label: "Average completion",
                mine: comparison.myStats.averageCompletion,
                theirs: comparison.friendStats.averageCompletion,
                display: { Format.percent($0) }
            )
            DuelBar(
                label: "Hours played",
                mine: comparison.myStats.totalHours,
                theirs: comparison.friendStats.totalHours,
                display: { Int($0.rounded()).formatted() }
            )
        }
        .padding(20)
        .glassChip(.blob(32))
        .entrance(1)

        let headToHead = model.headToHead
        if headToHead.decided > 0 {
            Scoreboard(
                friendName: model.friend.personaName,
                mine: headToHead.mine,
                theirs: headToHead.theirs,
                decided: headToHead.decided
            )
            .frame(maxWidth: .infinity)
            .entrance(2)
        }

        if model.sharedGames.isEmpty {
            EmptyStateView(
                motif: .controller,
                title: "No shared shelf",
                message: "You and \(model.friend.personaName) don't own the same games yet. First one to gift the other wins."
            )
        } else {
            FloatingSection(title: "Shared games", index: 3) {
                VStack(spacing: 12) {
                    ForEach(model.sharedGames) { shared in
                        SharedGameRow(
                            shared: shared,
                            friendName: model.friend.personaName,
                            awaitingFriendData: model.isHydratingShared && shared.theirs == nil
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Header

private struct VersusHeader: View {
    let me: PlayerProfile?
    let friend: PlayerProfile

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: -16) {
                if let me {
                    AvatarView(profile: me, size: 74)
                        .zIndex(1)
                }
                AvatarView(profile: friend, size: 74)
            }
            HStack(spacing: 6) {
                Text("You")
                    .font(.footnote.weight(.semibold))
                Text("vs")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                Text(friend.personaName)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
            }
        }
        .padding(.top, 6)
    }
}

// MARK: - Duel bar

/// Numbers on the outside, one continuous capsule between them split by
/// proportion. The leading side glows softly; a dead heat glows nowhere.
private struct DuelBar: View {
    let label: String
    let mine: Double
    let theirs: Double
    let display: (Double) -> String

    @State private var animated = false

    private var mineFraction: Double {
        let total = mine + theirs
        guard total > 0 else { return 0.5 }
        return mine / total
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(display(mine))
                    .font(.miniNumber)
                    .foregroundStyle(mine >= theirs && mine > 0 ? Theme.accent : .secondary)
                Spacer()
                Text(label).capsLabel()
                Spacer()
                Text(display(theirs))
                    .font(.miniNumber)
                    .foregroundStyle(theirs > mine ? Theme.accentTeal : .secondary)
            }

            GeometryReader { proxy in
                HStack(spacing: 3) {
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: max(8, proxy.size.width * (animated ? mineFraction : 0.5)))
                        .shadow(
                            color: Theme.accent.opacity(mine > theirs ? 0.65 : 0),
                            radius: 6
                        )
                    Capsule()
                        .fill(Theme.accentTeal.opacity(0.75))
                        .shadow(
                            color: Theme.accentTeal.opacity(theirs > mine ? 0.65 : 0),
                            radius: 6
                        )
                }
            }
            .frame(height: 7)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.9, bounce: 0.15).delay(0.15)) {
                animated = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("You \(display(mine)), them \(display(theirs))")
    }
}

private struct Scoreboard: View {
    let friendName: String
    let mine: Int
    let theirs: Int
    let decided: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "flag.checkered")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(summary)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .glassChip()
    }

    private var summary: String {
        if mine > theirs {
            return "You lead in \(mine) of \(decided) shared games"
        } else if theirs > mine {
            return "\(friendName) leads in \(theirs) of \(decided)"
        }
        return "Dead even across \(decided) shared games"
    }
}

// MARK: - Shared games

private struct SharedGameRow: View {
    let shared: GameComparison
    let friendName: String
    let awaitingFriendData: Bool

    var body: some View {
        HStack(spacing: 14) {
            RemoteArtView.icon(for: shared.game)
                .frame(width: 46, height: 46)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 7) {
                Text(shared.game.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                ProgressLine(label: "You", progress: shared.mine,
                             tint: Theme.accent, pending: false)
                ProgressLine(label: friendName, progress: shared.theirs,
                             tint: Theme.accentTeal, pending: awaitingFriendData)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassChip(.blob(28))
    }
}

private struct ProgressLine: View {
    let label: String
    let progress: AchievementProgress?
    let tint: Color
    let pending: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)
                .lineLimit(1)

            if let progress, progress.total > 0 {
                Capsule()
                    .fill(.quaternary)
                    .frame(height: 5)
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(tint)
                                .frame(width: max(5, proxy.size.width * progress.fraction))
                        }
                    }
                Text("\(progress.unlocked)/\(progress.total)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .trailing)
                    .contentTransition(.numericText())
            } else if pending {
                Capsule().fill(.quaternary).frame(height: 5).breathing()
                Text("…")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(width: 52, alignment: .trailing)
            } else {
                Capsule().fill(.quaternary.opacity(0.5)).frame(height: 5)
                Text("—")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(width: 52, alignment: .trailing)
            }
        }
        .animation(.spring(duration: 0.5), value: progress)
    }
}
