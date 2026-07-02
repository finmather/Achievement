import SwiftUI
import AchievementCore

struct DashboardView: View {
    let home: HomeModel

    private var library: LibraryStore { home.library }

    var body: some View {
        ZStack {
            ScreenBackground()

            ScrollView {
                VStack(spacing: 20) {
                    header

                    switch (library.hasContent, library.phase) {
                    case (false, .loadingLibrary):
                        DashboardSkeleton()
                    case (false, .failed(let message)):
                        SyncErrorView(message: message) {
                            Task { await library.refresh() }
                        }
                    default:
                        loadedContent
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .refreshable { await library.refresh() }
        }
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .top) { celebrationToast }
    }

    @ViewBuilder
    private var loadedContent: some View {
        HeroCompletionCard(stats: library.stats, streak: library.streak)

        if case .hydrating(let done, let total) = library.phase {
            SyncProgressBanner(done: done, total: total)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
        if case .failed(let message) = library.phase, library.hasContent {
            InlineErrorBanner(message: message)
        }

        if !library.recentUnlocks.isEmpty {
            SectionHeader("Recently Unlocked")
            RecentUnlocksRail(unlocks: library.recentUnlocks, gameLookup: game(for:))
        }

        if library.streak.current > 0 {
            StreakCard(streak: library.streak)
        }

        if !library.nearlyPerfect.isEmpty {
            SectionHeader("Almost There")
            NearlyPerfectRail(games: Array(library.nearlyPerfect.prefix(8)))
        }

        if !library.recentlyPlayed.isEmpty {
            SectionHeader("Recently Played")
            VStack(spacing: 10) {
                ForEach(library.recentlyPlayed) { game in
                    NavigationLink(value: game) {
                        RecentGameRow(game: game)
                    }
                    .buttonStyle(.pressableCard)
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(home.profile?.personaName ?? "Achievement")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
            }
            Spacer()
            if let profile = home.profile {
                AvatarView(profile: profile, size: 44)
            }
        }
        .padding(.top, 12)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Good morning"
        case 12..<18: "Good afternoon"
        default: "Good evening"
        }
    }

    @ViewBuilder
    private var celebrationToast: some View {
        if library.freshUnlockCount > 0 {
            CelebrationToast(count: library.freshUnlockCount)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task {
                    Haptics.celebrate()
                    try? await Task.sleep(for: .seconds(4))
                    withAnimation(.spring(duration: 0.5)) {
                        library.acknowledgeFreshUnlocks()
                    }
                }
        }
    }

    private func game(for appID: Int) -> Game? {
        library.games.first { $0.appID == appID }
    }
}

// MARK: - Hero

private struct HeroCompletionCard: View {
    let stats: LibraryStats
    let streak: StreakSummary

    var body: some View {
        VStack(spacing: 20) {
            CompletionRing(
                fraction: stats.averageCompletion,
                lineWidth: 14
            ) {
                VStack(spacing: 2) {
                    Text(Format.percent(stats.averageCompletion))
                        .font(.heroNumber)
                        .contentTransition(.numericText())
                    Text("Average")
                        .statLabelStyle()
                }
            }
            .frame(width: 168, height: 168)
            .padding(.top, 8)

            HStack(spacing: 0) {
                HeroStat(
                    value: stats.unlockedAchievements.formatted(),
                    label: "Achievements"
                )
                heroDivider
                HeroStat(value: "\(stats.perfectGames)", label: "Perfect")
                heroDivider
                HeroStat(value: "\(streak.current)", label: "Day streak")
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .cardSurface()
    }

    private var heroDivider: some View {
        Rectangle().fill(.quaternary).frame(width: 1, height: 34)
    }
}

private struct HeroStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.statNumber)
                .contentTransition(.numericText())
            Text(label).statLabelStyle()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Sync states

private struct SyncProgressBanner: View {
    let done: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Importing achievements")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(done) of \(total)")
                    .font(.miniNumber)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            ProgressView(value: Double(done), total: Double(max(total, 1)))
                .tint(Theme.accent)
        }
        .padding(16)
        .cardSurface(cornerRadius: 18)
    }
}

private struct InlineErrorBanner: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "wifi.exclamationmark")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface(cornerRadius: 16)
    }
}

private struct SyncErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Can't Sync", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding(.top, 60)
    }
}

private struct DashboardSkeleton: View {
    var body: some View {
        VStack(spacing: 20) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.quaternary)
                .frame(height: 280)
            HStack(spacing: 12) {
                ForEach(0..<2, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.quaternary)
                        .frame(height: 150)
                }
            }
        }
        .shimmering()
        .accessibilityLabel("Loading your library")
    }
}

// MARK: - Celebration

private struct CelebrationToast: View {
    let count: Int

    var body: some View {
        Label(
            count == 1 ? "New achievement unlocked" : "\(count) new achievements",
            systemImage: "sparkles"
        )
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(
            Capsule().fill(
                LinearGradient(
                    colors: [Theme.gold, Theme.goldDeep],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
        )
        .shadow(color: Theme.goldDeep.opacity(0.4), radius: 12, y: 5)
        .padding(.top, 8)
    }
}

// MARK: - Rails & rows

struct SectionHeader: View {
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
    }
}

private struct RecentUnlocksRail: View {
    let unlocks: [UnlockEvent]
    let gameLookup: (Int) -> Game?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(unlocks) { unlock in
                    if let game = gameLookup(unlock.gameAppID) {
                        NavigationLink(value: game) {
                            UnlockCard(unlock: unlock)
                        }
                        .buttonStyle(.pressableCard)
                    } else {
                        UnlockCard(unlock: unlock)
                    }
                }
            }
            .padding(.horizontal, 20)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .padding(.horizontal, -20)
    }
}

private struct UnlockCard: View {
    let unlock: UnlockEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AchievementIcon(achievement: unlock.achievement, size: 44)

            Text(unlock.achievement.displayName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(unlock.gameName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(Format.relative(unlock.unlockedAt))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .frame(width: 168, alignment: .leading)
        .cardSurface(cornerRadius: 20)
    }
}

private struct StreakCard: View {
    let streak: StreakSummary

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.gold, .orange],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: 44, height: 44)
                .background(Circle().fill(.orange.opacity(0.12)))

            VStack(alignment: .leading, spacing: 3) {
                Text("\(streak.current)-day unlock streak")
                    .font(.subheadline.weight(.semibold))
                Text(
                    streak.unlockedToday
                        ? "Extended today — keep it alive."
                        : "Unlock one today to keep it going."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(spacing: 2) {
                Text("\(streak.longest)")
                    .font(.statNumber)
                Text("Best").statLabelStyle()
            }
        }
        .padding(18)
        .cardSurface(cornerRadius: 20)
    }
}

private struct NearlyPerfectRail: View {
    let games: [Game]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(games) { game in
                    NavigationLink(value: game) {
                        NearlyPerfectCard(game: game)
                    }
                    .buttonStyle(.pressableCard)
                }
            }
            .padding(.horizontal, 20)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .padding(.horizontal, -20)
    }
}

private struct NearlyPerfectCard: View {
    let game: Game

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RemoteArtView.wide(for: game)
                .frame(width: 220, height: 103)
                .clipped()

            VStack(alignment: .leading, spacing: 8) {
                Text(game.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                if let progress = game.achievements {
                    HStack(spacing: 8) {
                        ProgressView(value: progress.fraction)
                            .tint(
                                Theme.completionGradient(
                                    fraction: progress.fraction
                                )
                            )
                        Text(progress.remaining == 1
                             ? "1 left"
                             : "\(progress.remaining) left")
                            .font(.miniNumber)
                            .foregroundStyle(.secondary)
                            .fixedSize()
                    }
                }
            }
            .padding(12)
        }
        .frame(width: 220, alignment: .leading)
        .cardSurface(cornerRadius: 20)
    }
}

private struct RecentGameRow: View {
    let game: Game

    var body: some View {
        HStack(spacing: 14) {
            RemoteArtView.icon(for: game)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(game.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            if let progress = game.achievements {
                CompletionRing(
                    fraction: progress.fraction,
                    isPerfect: progress.isPerfect,
                    lineWidth: 4,
                    animatesOnAppear: false
                )
                .frame(width: 30, height: 30)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .cardSurface(cornerRadius: 18)
    }

    private var subtitle: String {
        var parts = [Format.hours(game.playtimeMinutes)]
        if let lastPlayed = game.lastPlayed {
            parts.append(Format.relative(lastPlayed))
        }
        return parts.joined(separator: " · ")
    }
}

/// Achievement icon with a rarity-tinted fallback when Steam art is missing.
struct AchievementIcon: View {
    let achievement: Achievement
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let url = achievement.isUnlocked
                ? achievement.iconURL
                : (achievement.lockedIconURL ?? achievement.iconURL) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        .saturation(achievement.isUnlocked ? 1 : 0)
        .opacity(achievement.isUnlocked ? 1 : 0.55)
    }

    private var fallback: some View {
        ZStack {
            LinearGradient(
                colors: [tint.opacity(0.85), tint.opacity(0.55)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Image(systemName: achievement.isUnlocked ? "trophy.fill" : "lock.fill")
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    private var tint: Color {
        achievement.rarity.map(Theme.color(for:)) ?? Theme.accent
    }
}
