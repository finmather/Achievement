import SwiftUI
import AchievementCore

/// Immersive game page: the cover art becomes the entire atmosphere — a
/// blurred, darkened bloom of it fills the screen while a sharp floating
/// cover carries the zoom transition in from the library. Achievements are
/// floating rows on the atmosphere, not boxes.
struct GameDetailView: View {
    let game: Game
    let home: HomeModel

    @State private var achievements: [Achievement]?
    @State private var loadError: String?
    @State private var hasCelebrated = false

    /// Live copy from the store — progress can improve mid-sync.
    private var currentGame: Game {
        home.library.games.first { $0.appID == game.appID } ?? game
    }

    var body: some View {
        ZStack {
            BackdropArt(game: currentGame)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    FloatingCover(game: currentGame)
                        .entrance(0)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(currentGame.name)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                        Text(playSummary).capsLabel()
                    }
                    .entrance(1)

                    if currentGame.isPerfect {
                        PerfectRibbon().entrance(2)
                    }

                    if let nextUp {
                        NextUpSpotlight(achievement: nextUp).entrance(2)
                    }

                    achievementsSection
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
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

    private var playSummary: String {
        var parts = [Format.hours(currentGame.playtimeMinutes) + " played"]
        if let lastPlayed = currentGame.lastPlayed {
            parts.append("last \(Format.relative(lastPlayed))")
        }
        return parts.joined(separator: " · ")
    }

    /// The most attainable locked achievement — a nudge, not a nag.
    private var nextUp: Achievement? {
        achievements?
            .filter { !$0.isUnlocked && !$0.isHidden }
            .max { ($0.globalPercent ?? -1) < ($1.globalPercent ?? -1) }
    }

    // MARK: - Achievements

    @ViewBuilder
    private var achievementsSection: some View {
        if let achievements {
            if achievements.isEmpty {
                EmptyStateView(
                    motif: .trophy,
                    title: "No achievements here",
                    message: "This game doesn't offer achievements — pure play, no checklists."
                )
            } else {
                let locked = achievements
                    .filter { !$0.isUnlocked }
                    .sorted { ($0.globalPercent ?? -1) > ($1.globalPercent ?? -1) }
                let unlocked = achievements
                    .filter(\.isUnlocked)
                    .sorted { ($0.unlockedAt ?? .distantPast) > ($1.unlockedAt ?? .distantPast) }

                if !locked.isEmpty {
                    AchievementGroup(title: "To unlock", achievements: locked, index: 3)
                }
                if !unlocked.isEmpty {
                    AchievementGroup(title: "Unlocked", achievements: unlocked, index: 4)
                }
            }
        } else if let loadError {
            EmptyStateView(
                motif: .signal,
                title: "Couldn't load achievements",
                message: loadError,
                actionTitle: "Try again",
                action: {
                    self.loadError = nil
                    Task { await loadAchievements() }
                }
            )
        } else {
            VStack(spacing: 14) {
                ForEach(0..<5, id: \.self) { _ in
                    HStack(spacing: 14) {
                        BreathingPlaceholder(shape: .circle)
                            .frame(width: 46, height: 46)
                        BreathingPlaceholder(shape: .capsule)
                            .frame(height: 34)
                    }
                }
            }
            .padding(.top, 10)
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

// MARK: - Atmosphere

/// The cover art, blurred into a full-screen atmosphere with a scrim that
/// keeps text legible in both color schemes.
private struct BackdropArt: View {
    let game: Game
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            AuroraBackground()

            RemoteArtView.wide(for: game)
                .scaledToFill()
                .scaleEffect(1.4)
                .blur(radius: 42, opaque: true)
                .opacity(scheme == .dark ? 0.55 : 0.4)
                .overlay {
                    LinearGradient(
                        colors: scheme == .dark
                            ? [.black.opacity(0.25), .black.opacity(0.6)]
                            : [.white.opacity(0.35), .white.opacity(0.7)],
                        startPoint: .top, endPoint: .bottom
                    )
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }
}

/// Sharp cover floating on the atmosphere, ring overlapping its corner.
private struct FloatingCover: View {
    let game: Game

    var body: some View {
        RemoteArtView.wide(for: game)
            .aspectRatio(21 / 10, contentMode: .fit)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.4), radius: 26, y: 14)
            .overlay(alignment: .bottomTrailing) {
                if let progress = game.achievements, progress.total > 0 {
                    CompletionRing(
                        fraction: progress.fraction,
                        isPerfect: progress.isPerfect,
                        lineWidth: 6
                    ) {
                        VStack(spacing: 0) {
                            Text("\(progress.unlocked)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .contentTransition(.numericText())
                            Text("of \(progress.total)")
                                .font(.system(size: 8.5, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 68, height: 68)
                    .padding(7)
                    .glassChip(.circle)
                    .offset(x: 10, y: 22)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 14)
    }
}

private struct PerfectRibbon: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "crown.fill")
            Text("Perfect game")
                .font(.subheadline.weight(.bold))
            Spacer()
            Text("Every achievement unlocked")
                .font(.caption)
                .opacity(0.85)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Capsule().fill(Theme.goldGradient))
        .shadow(color: Theme.goldDeep.opacity(0.45), radius: 14, y: 6)
    }
}

private struct NextUpSpotlight: View {
    let achievement: Achievement

    var body: some View {
        HStack(spacing: 14) {
            AchievementIcon(achievement: achievement, size: 50)
                .shadow(color: Theme.accent.opacity(0.4), radius: 10)

            VStack(alignment: .leading, spacing: 3) {
                Text("Next up").capsLabel()
                Text(achievement.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if let percent = achievement.globalPercent {
                    Text("\(Format.globalPercent(percent)) have this one")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .glassChip(.blob(28))
    }
}

// MARK: - Rows

private struct AchievementGroup: View {
    let title: String
    let achievements: [Achievement]
    var index: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(title).capsLabel()
                Text("\(achievements.count)")
                    .font(.miniNumber)
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 12)
            .padding(.bottom, 8)

            VStack(spacing: 0) {
                ForEach(Array(achievements.enumerated()), id: \.element.id) { position, achievement in
                    AchievementRow(achievement: achievement)
                    if position < achievements.count - 1 {
                        Rectangle()
                            .fill(.primary.opacity(0.07))
                            .frame(height: 0.5)
                            .padding(.leading, 62)
                    }
                }
            }
        }
        .entrance(index)
    }
}

private struct AchievementRow: View {
    let achievement: Achievement

    private var isMystery: Bool { achievement.isHidden && !achievement.isUnlocked }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
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
                    .foregroundStyle(Color(red: 0.18, green: 0.8, blue: 0.56))
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 13)
        .opacity(achievement.isUnlocked ? 1 : 0.8)
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
            .background(Capsule().fill(Theme.color(for: rarity).opacity(0.14)))
    }
}
