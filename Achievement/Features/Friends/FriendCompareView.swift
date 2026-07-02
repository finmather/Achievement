import SwiftUI
import AchievementCore

/// Head-to-head with a friend. Tone is deliberately friendly: balanced
/// layout, soft "leads" language, no losers.
struct FriendCompareView: View {
    let home: HomeModel
    @State private var model: ComparisonModel

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
            ScreenBackground()

            ScrollView {
                VStack(spacing: 20) {
                    VersusHeader(me: home.profile, friend: model.friend)

                    if let comparison = model.comparison {
                        loadedContent(comparison)
                    } else if let error = model.errorMessage {
                        ContentUnavailableView {
                            Label("Can't Compare", systemImage: "person.2.slash")
                        } description: {
                            Text(error)
                        }
                        .padding(.top, 20)
                    } else {
                        CompareSkeleton()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Compare")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
    }

    @ViewBuilder
    private func loadedContent(_ comparison: FriendComparison) -> some View {
        VStack(spacing: 16) {
            DuelRow(
                label: "Perfect games",
                mine: Double(comparison.myStats.perfectGames),
                theirs: Double(comparison.friendStats.perfectGames),
                display: { "\(Int($0))" }
            )
            DuelRow(
                label: "Achievements",
                mine: Double(comparison.myStats.unlockedAchievements),
                theirs: Double(comparison.friendStats.unlockedAchievements),
                display: { Int($0).formatted() }
            )
            DuelRow(
                label: "Average completion",
                mine: comparison.myStats.averageCompletion,
                theirs: comparison.friendStats.averageCompletion,
                display: { Format.percent($0) }
            )
            DuelRow(
                label: "Hours played",
                mine: comparison.myStats.totalHours,
                theirs: comparison.friendStats.totalHours,
                display: { Int($0.rounded()).formatted() }
            )
        }
        .padding(20)
        .cardSurface()

        let headToHead = model.headToHead
        if headToHead.decided > 0 {
            HeadToHeadChip(
                friendName: model.friend.personaName,
                mine: headToHead.mine,
                theirs: headToHead.theirs,
                decided: headToHead.decided
            )
        }

        if !model.sharedGames.isEmpty {
            SectionHeader("Shared Games")
            VStack(spacing: 10) {
                ForEach(model.sharedGames) { shared in
                    SharedGameRow(
                        shared: shared,
                        friendName: model.friend.personaName,
                        awaitingFriendData: model.isHydratingShared && shared.theirs == nil
                    )
                }
            }
        } else {
            ContentUnavailableView(
                "No Shared Games",
                systemImage: "square.stack",
                description: Text("You and \(model.friend.personaName) don't own any of the same games yet.")
            )
            .padding(.top, 8)
        }
    }
}

// MARK: - Header

private struct VersusHeader: View {
    let me: PlayerProfile?
    let friend: PlayerProfile

    var body: some View {
        HStack(spacing: 24) {
            VStack(spacing: 8) {
                if let me {
                    AvatarView(profile: me, size: 64)
                }
                Text("You").font(.caption.weight(.semibold))
            }
            Text("vs")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
            VStack(spacing: 8) {
                AvatarView(profile: friend, size: 64)
                Text(friend.personaName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Duel rows

/// One stat, two people: numbers on the outside, a split bar between them.
/// The bar animates to its proportion; the stronger side reads instantly.
private struct DuelRow: View {
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
        VStack(spacing: 6) {
            HStack {
                Text(display(mine))
                    .font(.miniNumber)
                    .foregroundStyle(mine >= theirs ? Theme.accent : .secondary)
                Spacer()
                Text(label).statLabelStyle()
                Spacer()
                Text(display(theirs))
                    .font(.miniNumber)
                    .foregroundStyle(theirs > mine ? Theme.accent : .secondary)
            }

            GeometryReader { proxy in
                HStack(spacing: 3) {
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: max(6, proxy.size.width * (animated ? mineFraction : 0.5)))
                    Capsule()
                        .fill(.quaternary)
                }
            }
            .frame(height: 6)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.9, bounce: 0.15).delay(0.1)) {
                animated = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("You \(display(mine)), them \(display(theirs))")
    }
}

private struct HeadToHeadChip: View {
    let friendName: String
    let mine: Int
    let theirs: Int
    let decided: Int

    var body: some View {
        Label(summary, systemImage: "flag.checkered")
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(.quaternary.opacity(0.5)))
    }

    private var summary: String {
        if mine > theirs {
            return "You lead in \(mine) of \(decided) shared games"
        } else if theirs > mine {
            return "\(friendName) leads in \(theirs) of \(decided) shared games"
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
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                Text(shared.game.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                ProgressLine(
                    label: "You",
                    progress: shared.mine,
                    tint: Theme.accent,
                    pending: false
                )
                ProgressLine(
                    label: friendName,
                    progress: shared.theirs,
                    tint: Color(red: 0.18, green: 0.76, blue: 0.78),
                    pending: awaitingFriendData
                )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(cornerRadius: 18)
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
                .frame(width: 58, alignment: .leading)
                .lineLimit(1)

            if let progress, progress.total > 0 {
                ProgressView(value: progress.fraction)
                    .tint(tint)
                Text("\(progress.unlocked)/\(progress.total)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .trailing)
                    .contentTransition(.numericText())
            } else if pending {
                ProgressView(value: 0).tint(.clear)
                    .overlay(Capsule().fill(.quaternary).frame(height: 4).shimmering())
                Text("…")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(width: 52, alignment: .trailing)
            } else {
                ProgressView(value: 0)
                Text("—")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(width: 52, alignment: .trailing)
            }
        }
        .animation(.spring(duration: 0.5), value: progress)
    }
}

private struct CompareSkeleton: View {
    var body: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.quaternary)
                .frame(height: 220)
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.quaternary)
                    .frame(height: 88)
            }
        }
        .shimmering()
        .accessibilityLabel("Loading comparison")
    }
}
