import SwiftUI
import AchievementCore

/// The companion guide for one game. Opens with the cover and identity,
/// then progressively reveals: progress + time-to-100% estimate, recent
/// unlocks, the roadmap to perfection, data-driven insights, friends who
/// own it, personal notes, similar games from the player's own shelf, and
/// the full achievement list. Everything floats on a blurred bloom of the
/// game's own art.
struct GameDetailView: View {
    let game: Game
    let home: HomeModel

    @State private var achievements: [Achievement]?
    @State private var meta: GameMeta?
    @State private var friendOwners: [PlayerProfile] = []
    @State private var loadError: String?
    @State private var hasCelebrated = false

    /// Live copy from the store — progress can improve mid-sync.
    private var currentGame: Game {
        home.library.games.first { $0.appID == game.appID } ?? game
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.sectionGap) {
                FloatingCover(game: currentGame)
                    .entrance(0)

                TitleBlock(game: currentGame, meta: meta)
                    .entrance(1)

                if currentGame.isPerfect {
                    PerfectRibbon().entrance(2)
                }

                ProgressPanel(
                    game: currentGame,
                    estimate: achievements.flatMap {
                        CompletionEstimator.hoursToComplete(game: currentGame, achievements: $0)
                    }
                )
                .entrance(2)

                detailSections
            }
            .padding(.horizontal, Tokens.screenMargin)
            .padding(.bottom, 40)
        }
        .scrollClipDisabled()
        .background { BackdropArt(game: currentGame) }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        // The compare push can originate here too, whichever tab's stack
        // this detail page lives in.
        .navigationDestination(for: PlayerProfile.self) { friend in
            FriendCompareView(friend: friend, home: home)
        }
        .task {
            async let achievementsLoad: Void = loadAchievements()
            async let metaLoad: Void = loadMeta()
            async let ownersLoad: Void = loadFriendOwners()
            _ = await (achievementsLoad, metaLoad, ownersLoad)
        }
        .onAppear {
            if currentGame.isPerfect, !hasCelebrated {
                hasCelebrated = true
                Haptics.celebrate()
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var detailSections: some View {
        if let achievements {
            if achievements.isEmpty {
                EmptyStateView(
                    motif: .trophy,
                    title: "No achievements here",
                    message: "This game doesn't offer achievements — pure play, no checklists."
                )
            } else {
                let unlocked = achievements
                    .filter(\.isUnlocked)
                    .sorted { ($0.unlockedAt ?? .distantPast) > ($1.unlockedAt ?? .distantPast) }
                let locked = achievements
                    .filter { !$0.isUnlocked }
                    .sorted { ($0.globalPercent ?? -1) > ($1.globalPercent ?? -1) }
                let insights = GameInsightsEngine.insights(
                    game: currentGame, achievements: achievements
                )

                if !unlocked.isEmpty {
                    FloatingSection(title: "Recently unlocked here", index: 3) {
                        RecentUnlockStrip(achievements: Array(unlocked.prefix(8)))
                    }
                }

                if !locked.isEmpty {
                    FloatingSection(title: "Road to 100%", index: 4) {
                        RoadmapView(remaining: locked)
                    }
                }

                if !insights.isEmpty {
                    FloatingSection(title: "Insights", index: 5) {
                        InsightLines(game: currentGame, insights: insights)
                    }
                }

                if !friendOwners.isEmpty {
                    FloatingSection(title: "Friends who own it", index: 6) {
                        FriendOwnersRow(owners: friendOwners)
                    }
                }

                FloatingSection(title: "Your notes", index: 6) {
                    NotesCard(appID: currentGame.appID)
                }

                let similar = SimilarGames.similar(
                    to: currentGame,
                    in: home.library.games,
                    tagsByApp: home.library.genreTags
                )
                if !similar.isEmpty {
                    FloatingSection(title: "More like this on your shelf", index: 7) {
                        SimilarGamesRail(games: similar)
                    }
                }

                if !locked.isEmpty {
                    FloatingSection(title: "To unlock · \(locked.count)", index: 8) {
                        AchievementList(achievements: locked)
                    }
                }
                if !unlocked.isEmpty {
                    FloatingSection(title: "Unlocked · \(unlocked.count)", index: 9) {
                        AchievementList(achievements: unlocked)
                    }
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
                            .frame(width: Tokens.IconSize.m, height: Tokens.IconSize.m)
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
            withAnimation(.settle) {
                achievements = loaded
            }
        } catch {
            loadError = (error as? SteamWebAPIError)?.errorDescription
                ?? "Check your connection and try again."
        }
    }

    private func loadMeta() async {
        guard meta == nil else { return }
        let loaded = await home.dataSource.gameMeta(appID: game.appID)
        withAnimation(.settle) {
            meta = loaded
        }
    }

    private func loadFriendOwners() async {
        await home.friends.loadIfNeeded()
        let owners = await home.friendsOwning(game.appID)
        withAnimation(.settle) {
            friendOwners = owners
        }
    }
}

// MARK: - Header pieces

/// Sharp cover floating on the atmosphere, ring badge overlapping its corner.
/// Size comes from the neutral Color.clear; the art is overlay-only and can
/// never leak its native ideal size into layout.
private struct FloatingCover: View {
    let game: Game

    var body: some View {
        Color.clear
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .overlay { RemoteArtView.wide(for: game) }
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.hero, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.hero, style: .continuous)
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

/// Name, genre chips, developer byline, and an expandable description.
private struct TitleBlock: View {
    let game: Game
    let meta: GameMeta?

    @State private var descriptionExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(game.name)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            if let meta {
                if !meta.genres.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(meta.genres.prefix(3), id: \.self) { genre in
                            Text(genre)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(.quaternary.opacity(0.5)))
                        }
                    }
                }

                if let byline = meta.byline {
                    Text(byline).capsLabel()
                }

                if let description = meta.shortDescription {
                    Text(description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(descriptionExpanded ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                        .onTapGesture {
                            withAnimation(.settle) {
                                descriptionExpanded.toggle()
                            }
                        }
                }
            }
        }
        .animation(.settle, value: meta != nil)
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

/// The numbers panel: ring, counts, pace, and the time-to-100% estimate.
private struct ProgressPanel: View {
    let game: Game
    let estimate: Double?

    var body: some View {
        HStack(spacing: 20) {
            if let progress = game.achievements, progress.total > 0 {
                CompletionRing(
                    fraction: progress.fraction,
                    isPerfect: progress.isPerfect,
                    lineWidth: 8
                ) {
                    Text(Format.percent(progress.fraction))
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                }
                .frame(width: 82, height: 82)

                VStack(alignment: .leading, spacing: 7) {
                    if progress.remaining > 0 {
                        panelLine(
                            symbol: "flag.checkered",
                            text: progress.remaining == 1
                                ? "1 achievement to go"
                                : "\(progress.remaining) achievements to go"
                        )
                        if let estimate {
                            panelLine(symbol: "hourglass", text: estimateText(estimate))
                        }
                    } else {
                        panelLine(symbol: "crown.fill", text: "100% complete")
                    }
                    panelLine(
                        symbol: "clock",
                        text: "\(Format.hours(game.playtimeMinutes)) played"
                    )
                    if let lastPlayed = game.lastPlayed {
                        panelLine(
                            symbol: "calendar",
                            text: "Last played \(Format.relative(lastPlayed))"
                        )
                    }
                }
                Spacer(minLength: 0)
            } else {
                Image(systemName: "circle.dashed")
                    .font(.title2)
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
        .padding(18)
        .glassChip(.blob(Tokens.Radius.blob))
    }

    private func panelLine(symbol: String, text: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.caption)
                .foregroundStyle(Theme.accentDuotone)
                .frame(width: 16)
            Text(text)
                .font(.footnote.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private func estimateText(_ hours: Double) -> String {
        if hours < 1 { return "Under an hour to 100%" }
        return "≈ \(Int(hours.rounded())) hrs to 100% at your pace"
    }
}
