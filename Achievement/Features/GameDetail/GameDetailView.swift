import SwiftUI
import AchievementCore

struct GameDetailView: View {
    let game: Game
    let home: HomeModel

    @State private var achievements: [Achievement]?
    @State private var loadError: String?
    @State private var hasCelebrated = false

    /// Live copy from the store — progress can improve while this screen is
    /// open (mid-sync); fall back to the pushed snapshot.
    private var currentGame: Game {
        home.library.games.first { $0.appID == game.appID } ?? game
    }

    var body: some View {
        ZStack {
            ScreenBackground()

            ScrollView {
                VStack(spacing: 20) {
                    StretchyHeader(game: currentGame)

                    VStack(spacing: 20) {
                        ProgressSummaryCard(game: currentGame)

                        if currentGame.isPerfect {
                            PerfectBanner()
                        }

                        achievementsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task { await loadAchievements() }
        .onAppear {
            if currentGame.isPerfect, !hasCelebrated {
                hasCelebrated = true
                Haptics.celebrate()
            }
        }
    }

    // MARK: - Achievements

    @ViewBuilder
    private var achievementsSection: some View {
        if let achievements {
            let locked = achievements
                .filter { !$0.isUnlocked }
                .sorted { ($0.globalPercent ?? -1) > ($1.globalPercent ?? -1) }
            let unlocked = achievements
                .filter(\.isUnlocked)
                .sorted { ($0.unlockedAt ?? .distantPast) > ($1.unlockedAt ?? .distantPast) }

            if achievements.isEmpty {
                ContentUnavailableView(
                    "No Achievements",
                    systemImage: "circle.dashed",
                    description: Text("This game doesn't offer achievements.")
                )
                .padding(.top, 12)
            } else {
                if !locked.isEmpty {
                    AchievementGroup(
                        title: "To Unlock",
                        count: locked.count,
                        achievements: locked
                    )
                }
                if !unlocked.isEmpty {
                    AchievementGroup(
                        title: "Unlocked",
                        count: unlocked.count,
                        achievements: unlocked
                    )
                }
            }
        } else if let loadError {
            ContentUnavailableView {
                Label("Couldn't Load Achievements", systemImage: "wifi.exclamationmark")
            } description: {
                Text(loadError)
            } actions: {
                Button("Try Again") {
                    self.loadError = nil
                    Task { await loadAchievements() }
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            VStack(spacing: 10) {
                ForEach(0..<5, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.quaternary)
                        .frame(height: 76)
                }
            }
            .shimmering()
            .accessibilityLabel("Loading achievements")
        }
    }

    private func loadAchievements() async {
        guard achievements == nil else { return }
        do {
            let loaded = try await home.library.achievements(for: game)
            withAnimation(.spring(duration: 0.45)) {
                achievements = loaded
            }
        } catch {
            loadError = (error as? SteamWebAPIError)?.errorDescription
                ?? "Check your connection and try again."
        }
    }
}

// MARK: - Header

/// Hero art that stretches on over-scroll and parallaxes away when scrolling
/// down — the screen should feel anchored to the game's identity.
private struct StretchyHeader: View {
    let game: Game

    var body: some View {
        GeometryReader { proxy in
            let minY = proxy.frame(in: .global).minY
            let stretch = max(0, minY)

            RemoteArtView.wide(for: game)
                .frame(width: proxy.size.width, height: proxy.size.height + stretch)
                .clipped()
                .overlay {
                    LinearGradient(
                        colors: [.clear, .clear, .black.opacity(0.72)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(game.name)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                        Text(playSummary)
                            .font(.footnote.weight(.medium))
                            .opacity(0.85)
                    }
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
                    .padding(20)
                }
                .offset(y: -stretch)
        }
        .frame(height: 260)
    }

    private var playSummary: String {
        var parts = [Format.hours(game.playtimeMinutes) + " played"]
        if let lastPlayed = game.lastPlayed {
            parts.append("last played \(Format.relative(lastPlayed))")
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Summary

private struct ProgressSummaryCard: View {
    let game: Game

    var body: some View {
        HStack(spacing: 20) {
            if let progress = game.achievements, progress.total > 0 {
                CompletionRing(
                    fraction: progress.fraction,
                    isPerfect: progress.isPerfect,
                    lineWidth: 9
                ) {
                    Text(Format.percent(progress.fraction))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                }
                .frame(width: 92, height: 92)

                VStack(alignment: .leading, spacing: 6) {
                    Text("\(progress.unlocked) of \(progress.total)")
                        .font(.statNumber)
                        .contentTransition(.numericText())
                    Text("Achievements unlocked").statLabelStyle()

                    if progress.remaining > 0 {
                        Text(progress.remaining == 1
                             ? "One away from perfect"
                             : "\(progress.remaining) to go")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                }
                Spacer(minLength: 0)
            } else {
                Image(systemName: "circle.dashed")
                    .font(.title)
                    .foregroundStyle(.tertiary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("No achievement data yet")
                        .font(.subheadline.weight(.semibold))
                    Text("Progress appears after the first sync.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(20)
        .cardSurface()
    }
}

private struct PerfectBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Perfect Game")
                    .font(.subheadline.weight(.bold))
                Text("Every achievement unlocked. Beautifully done.")
                    .font(.footnote)
                    .opacity(0.9)
            }
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Theme.gold, Theme.goldDeep],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: Theme.goldDeep.opacity(0.35), radius: 12, y: 5)
    }
}

// MARK: - Achievement list

private struct AchievementGroup: View {
    let title: String
    let count: Int
    let achievements: [Achievement]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(title).font(.title3.weight(.semibold))
                Text("\(count)")
                    .font(.miniNumber)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.quaternary))
            }
            .padding(.top, 4)

            VStack(spacing: 10) {
                ForEach(achievements) { achievement in
                    AchievementRow(achievement: achievement)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AchievementRow: View {
    let achievement: Achievement

    private var isMystery: Bool { achievement.isHidden && !achievement.isUnlocked }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            AchievementIcon(achievement: achievement, size: 46)

            VStack(alignment: .leading, spacing: 4) {
                Text(isMystery ? "Hidden achievement" : achievement.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(achievement.isUnlocked ? .primary : .secondary)

                if let detail = detailText {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    if let rarity = achievement.rarity {
                        RarityChip(rarity: rarity)
                    }
                    if let percent = achievement.globalPercent {
                        Text(Format.globalPercent(percent))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 0)
                    if let unlockedAt = achievement.unlockedAt {
                        Text(Format.relative(unlockedAt))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.top, 2)
            }

            if achievement.isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(Color(red: 0.16, green: 0.78, blue: 0.57))
                    .padding(.top, 2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(cornerRadius: 18)
        .opacity(achievement.isUnlocked ? 1 : 0.88)
    }

    private var detailText: String? {
        if isMystery { return "Keep playing to reveal this one." }
        return achievement.detail
    }
}

struct RarityChip: View {
    let rarity: Rarity

    var body: some View {
        Text(rarity.displayName)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.color(for: rarity))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Theme.color(for: rarity).opacity(0.13)))
    }
}
