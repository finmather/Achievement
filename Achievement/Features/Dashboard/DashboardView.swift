import SwiftUI
import AchievementCore

/// The daily ritual. No cards, no boxes: an editorial hero number with an
/// arc sweeping behind it, then floating groups — next milestone, latest
/// unlock spotlight, perfect-game coins, streak orbit, recent play — all
/// breathing on the aurora.
struct DashboardView: View {
    let home: HomeModel
    let onCelebrate: (UnlockEvent) -> Void

    @Namespace private var zoom

    private var library: LibraryStore { home.library }

    var body: some View {
        ZStack {
            AmbientBackground(palette: .dashboard)

            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.sectionGapAiry) {
                    header
                        .entrance(0)

                    switch (library.hasContent, library.phase) {
                    case (false, .loadingLibrary):
                        loadingState
                    case (false, .failed(let message)):
                        EmptyStateView(
                            motif: .signal,
                            title: "Can't reach Steam",
                            message: message,
                            actionTitle: "Try again",
                            action: { Task { await library.refresh() } }
                        )
                    default:
                        loadedContent
                    }
                }
                .padding(.horizontal, Tokens.screenMargin)
                .padding(.bottom, 40)
            }
            .scrollClipDisabled()
            .refreshable {
                await library.refresh()
                Haptics.success()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        // Games opened from here zoom out of their rail chip.
        .navigationDestination(for: Game.self) { game in
            GameDetailView(game: game, home: home)
                .navigationTransition(.zoom(sourceID: game.appID, in: zoom))
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting).capsLabel()
                Text(home.profile?.personaName ?? "Achievement")
                    .font(.editorialTitle)
            }
            Spacer()
            if let profile = home.profile {
                AvatarView(profile: profile, size: 46)
            }
        }
        .padding(.top, 16)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Good morning"
        case 12..<18: "Good afternoon"
        default: "Good evening"
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var loadedContent: some View {
        HeroCompletion(
            stats: library.stats,
            streak: library.streak,
            syncPhase: library.phase
        )
        .entrance(1)

        if case .failed(let message) = library.phase, library.hasContent {
            Label(message, systemImage: "wifi.exclamationmark")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .glassChip()
                .entrance(2)
        }

        if let milestone = library.nextMilestone {
            MilestoneCapsule(milestone: milestone)
                .entrance(2)
        }

        if let latest = library.unlocks.first {
            FloatingSection(title: "Latest unlock", index: 3) {
                SpotlightUnlock(unlock: latest) {
                    onCelebrate(latest)
                }
            }
        }

        let perfects = library.games.filter(\.isPerfect)
        if !perfects.isEmpty {
            FloatingSection(title: "Perfect games", index: 4) {
                PerfectCoinShelf(games: perfects)
            }
        }

        if library.streak.current > 0 {
            StreakOrbit(streak: library.streak, activeDays: last7Days)
                .entrance(5)
        }

        if !library.recentlyPlayed.isEmpty {
            FloatingSection(title: "Back to it", index: 6) {
                RecentPlayRail(games: library.recentlyPlayed, namespace: zoom)
            }
        }

        if library.unlocks.count > 1 {
            FloatingSection(title: "Recent unlocks", index: 7) {
                RecentUnlockRail(
                    unlocks: Array(library.recentUnlocks.dropFirst()),
                    gameLookup: { id in library.games.first { $0.appID == id } }
                )
            }
        }
    }

    private var loadingState: some View {
        VStack(alignment: .leading, spacing: 24) {
            BreathingPlaceholder(shape: .circle)
                .frame(width: 190, height: 190)
                .padding(.top, 12)
            BreathingPlaceholder(shape: .capsule)
                .frame(width: 240, height: 54)
            HStack(spacing: -14) {
                ForEach(0..<4, id: \.self) { _ in
                    BreathingPlaceholder(shape: .circle)
                        .frame(width: 56, height: 56)
                }
            }
            LoadingQuips()
                .padding(.top, 6)
        }
        .accessibilityLabel("Loading your library")
    }

    private var last7Days: [Bool] {
        let calendar = Calendar.current
        let activeDays = Set(library.unlocks.map { calendar.startOfDay(for: $0.unlockedAt) })
        return (0..<7).reversed().map { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: .now) else {
                return false
            }
            return activeDays.contains(calendar.startOfDay(for: day))
        }
    }
}

// MARK: - Section scaffolding

/// A floating group: kerned label, content, no box.
struct FloatingSection<Content: View>: View {
    let title: String
    var index: Int = 0
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).capsLabel()
            content()
        }
        .entrance(index)
        .reveal()
    }
}

// MARK: - Hero

/// Giant editorial percentage with a glowing arc sweeping behind it. During
/// a first import the arc doubles as the sync progress indicator.
private struct HeroCompletion: View {
    let stats: LibraryStats
    let streak: StreakSummary
    let syncPhase: SyncPhase

    @State private var swept = false

    private var fraction: Double { stats.averageCompletion }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ZStack(alignment: .leading) {
                // No interior clip anywhere near the arc: its glow blooms
                // freely and only the trailing edge runs past the screen
                // edge, where clipping is invisible by definition.
                arc
                    .frame(width: 224, height: 224)
                    .offset(x: 150)

                VStack(alignment: .leading, spacing: 6) {
                    // Counts up from zero alongside the arc sweep.
                    Text(Format.percent(swept ? fraction : 0))
                        .heroNumberStyle()
                    Text("Average completion").capsLabel()
                    Text("\(stats.unlockedAchievements.formatted()) of \(stats.totalAchievements.formatted()) achievements")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)

                    if case .hydrating(let done, let total) = syncPhase {
                        Text("Importing \(done) of \(total) games")
                            .font(.miniNumber)
                            .foregroundStyle(Theme.accentTeal)
                            .contentTransition(.numericText())
                            .padding(.top, 6)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 232, alignment: .leading)

            HStack(spacing: 32) {
                HeroStat(value: "\(stats.perfectGames)", label: "Perfect")
                HeroStat(value: "\(streak.current)", label: "Day streak")
                HeroStat(value: "\(stats.totalGames)", label: "Games")
            }
        }
        .onAppear {
            withAnimation(.sweep.delay(0.2)) {
                swept = true
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var arc: some View {
        let colors = Theme.completionColors(fraction: fraction, isPerfect: false)
        let trimEnd = swept ? max(0.02, fraction * 0.78) : 0.001
        let sweep = Circle()
            .trim(from: 0, to: trimEnd)
            .stroke(
                AngularGradient(
                    colors: colors + [colors[0]],
                    center: .center,
                    startAngle: .degrees(0),
                    endAngle: .degrees(300)
                ),
                style: StrokeStyle(lineWidth: 18, lineCap: .round)
            )
            .rotationEffect(.degrees(112))
        return ZStack {
            sweep.blur(radius: 20).opacity(0.4)
            sweep.blur(radius: 7).opacity(0.5)
            sweep

            // The pearl riding the arc tip — same cue as the signature ring.
            GeometryReader { proxy in
                let angle = (112 + 360 * trimEnd) * .pi / 180
                let radius = min(proxy.size.width, proxy.size.height) / 2
                let tip = colors.last ?? Theme.accent
                ZStack {
                    Circle()
                        .fill(tip)
                        .frame(width: 25, height: 25)
                        .shadow(color: tip.opacity(0.85), radius: 12)
                    Circle()
                        .fill(Color.white.opacity(0.92))
                        .frame(width: 9, height: 9)
                }
                .position(
                    x: proxy.size.width / 2 + cos(angle) * radius,
                    y: proxy.size.height / 2 + sin(angle) * radius
                )
            }
            .opacity(swept ? 1 : 0)
        }
    }
}

private struct HeroStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.statNumber)
                .contentTransition(.numericText())
            Text(label).capsLabel()
        }
    }
}

// MARK: - Milestone

private struct MilestoneCapsule: View {
    let milestone: Milestone
    @State private var pulsing = false

    var body: some View {
        Group {
            switch milestone {
            case .perfectGame(let game, let remaining):
                NavigationLink(value: game) {
                    capsule(
                        symbol: "crown.fill",
                        tint: Theme.gold,
                        title: remaining == 1
                            ? "One away from perfect"
                            : "\(remaining) to go",
                        subtitle: game.name,
                        ring: game.achievements?.fraction
                    )
                }
                .buttonStyle(.pressableCard)

            case .streakRecord(let record, let remaining):
                capsule(
                    symbol: "flame.fill",
                    tint: .orange,
                    title: remaining == 1
                        ? "A record day awaits"
                        : "\(remaining) days to a new record",
                    subtitle: "Your best streak is \(record)",
                    ring: nil
                )

            case .unlockCount(let target, let remaining):
                capsule(
                    symbol: "sparkles",
                    tint: Theme.accent,
                    title: "\(remaining) to \(target.formatted())",
                    subtitle: "Your next unlock landmark",
                    ring: nil
                )
            }
        }
    }

    private func capsule(
        symbol: String, tint: Color, title: String, subtitle: String, ring: Double?
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(Circle().fill(tint.opacity(0.14)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 10)
            if let ring {
                CompletionRing(fraction: ring, lineWidth: 4, animatesOnAppear: false)
                    .frame(width: 30, height: 30)
                    .scaleEffect(pulsing ? 1.07 : 1)
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 1.9).repeatForever(autoreverses: true)
                        ) {
                            pulsing = true
                        }
                    }
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassChip()
    }
}

// MARK: - Spotlight

private struct SpotlightUnlock: View {
    let unlock: UnlockEvent
    let onReplay: () -> Void

    private var tint: Color {
        unlock.achievement.rarity.map(Theme.color(for:)) ?? Theme.accent
    }

    var body: some View {
        Button(action: onReplay) {
            HStack(spacing: 16) {
                AchievementIcon(achievement: unlock.achievement, size: 58)
                    .shadow(color: tint.opacity(0.55), radius: 14)

                VStack(alignment: .leading, spacing: 3) {
                    Text(unlock.achievement.displayName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text("\(unlock.gameName) · \(Format.relative(unlock.unlockedAt))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if let rarity = unlock.achievement.rarity {
                        RarityChip(rarity: rarity)
                            .padding(.top, 3)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "play.circle")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .glassChip(.blob(30))
        }
        .buttonStyle(.pressableCard)
        .accessibilityHint("Replays the unlock celebration")
    }
}

// MARK: - Perfect coins

/// Overlapping gold-rimmed circles of cover art, waving slightly off the
/// baseline — a shelf of medals, not a grid of thumbnails.
private struct PerfectCoinShelf: View {
    let games: [Game]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: -14) {
                ForEach(Array(games.enumerated()), id: \.element.id) { index, game in
                    NavigationLink(value: game) {
                        RemoteArtView.icon(for: game)
                            .frame(width: 58, height: 58)
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(Theme.goldGradient, lineWidth: 2.5)
                            )
                            .shadow(color: Theme.goldDeep.opacity(0.35), radius: 8, y: 3)
                            .offset(y: index.isMultiple(of: 2) ? 4 : -4)
                    }
                    .buttonStyle(.pressable)
                    .zIndex(Double(games.count - index))
                }
            }
            .padding(.horizontal, Tokens.screenMargin)
            .padding(.vertical, 12)
        }
        .scrollClipDisabled()
        .padding(.horizontal, -Tokens.screenMargin)
    }
}

// MARK: - Streak orbit

private struct StreakOrbit: View {
    let streak: StreakSummary
    /// Last seven days, oldest first.
    let activeDays: [Bool]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 16) {
            TimelineView(.animation(minimumInterval: 1 / 12, paused: reduceMotion)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                Image(systemName: "flame.fill")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.gold, .orange],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    // A candle-quiet flicker, not a bonfire.
                    .scaleEffect(
                        reduceMotion ? 1 : 1 + 0.035 * sin(t * 6.3) * sin(t * 2.9),
                        anchor: .bottom
                    )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("\(streak.current)-day streak")
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 7) {
                    ForEach(Array(activeDays.enumerated()), id: \.offset) { _, active in
                        Circle()
                            .fill(active ? AnyShapeStyle(Theme.accentDuotone)
                                         : AnyShapeStyle(.quaternary))
                            .frame(width: 8, height: 8)
                    }
                    Text(streak.unlockedToday ? "extended today" : "unlock one today")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 4)
                }
            }
            Spacer(minLength: 10)
            VStack(spacing: 2) {
                Text("\(streak.longest)")
                    .font(.statNumber)
                Text("Best").capsLabel()
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .glassChip(.blob(30))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Rails

private struct RecentPlayRail: View {
    let games: [Game]
    let namespace: Namespace.ID

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(games) { game in
                    NavigationLink(value: game) {
                        HStack(spacing: 10) {
                            RemoteArtView.icon(for: game)
                                .frame(width: 34, height: 34)
                                .clipShape(Circle())
                            Text(game.name)
                                .font(.footnote.weight(.semibold))
                                .lineLimit(1)
                            if let progress = game.achievements {
                                CompletionRing(
                                    fraction: progress.fraction,
                                    isPerfect: progress.isPerfect,
                                    lineWidth: 3,
                                    animatesOnAppear: false,
                                    showsGlow: false
                                )
                                .frame(width: 20, height: 20)
                            }
                        }
                        .padding(.leading, 8)
                        .padding(.trailing, 14)
                        .padding(.vertical, 8)
                        .glassChip()
                        .matchedTransitionSource(id: game.appID, in: namespace)
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.horizontal, Tokens.screenMargin)
            .padding(.vertical, 12)
        }
        .scrollClipDisabled()
        .padding(.horizontal, -Tokens.screenMargin)
    }
}

private struct RecentUnlockRail: View {
    let unlocks: [UnlockEvent]
    let gameLookup: (Int) -> Game?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 18) {
                ForEach(unlocks) { unlock in
                    if let game = gameLookup(unlock.gameAppID) {
                        NavigationLink(value: game) {
                            UnlockMote(unlock: unlock)
                        }
                        .buttonStyle(.pressable)
                    } else {
                        UnlockMote(unlock: unlock)
                    }
                }
            }
            .padding(.horizontal, Tokens.screenMargin)
            .padding(.vertical, 10)
        }
        .scrollClipDisabled()
        .padding(.horizontal, -Tokens.screenMargin)
    }
}

private struct UnlockMote: View {
    let unlock: UnlockEvent

    private var tint: Color {
        unlock.achievement.rarity.map(Theme.color(for:)) ?? Theme.accent
    }

    var body: some View {
        VStack(spacing: 8) {
            AchievementIcon(achievement: unlock.achievement, size: 52)
                .shadow(color: tint.opacity(0.4), radius: 9)
            Text(unlock.achievement.displayName)
                .font(.caption2.weight(.medium))
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(width: 76)
    }
}

/// Achievement icon with a rarity-tinted fallback when Steam art is missing.
struct AchievementIcon: View {
    let achievement: Achievement
    var size: CGFloat = 44

    var body: some View {
        CachedImage(
            url: achievement.isUnlocked
                ? achievement.iconURL
                : (achievement.lockedIconURL ?? achievement.iconURL)
        ) { isLoading in
            // Real Steam icon inbound — breathe while it loads; the styled
            // trophy stands in permanently when no icon exists at all.
            if isLoading {
                fallback.breathing()
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .saturation(achievement.isUnlocked ? 1 : 0)
        .opacity(achievement.isUnlocked ? 1 : 0.55)
    }

    private var fallback: some View {
        ZStack {
            LinearGradient(
                colors: [tint.opacity(0.85), tint.opacity(0.5)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Image(systemName: achievement.isUnlocked ? "trophy.fill" : "lock.fill")
                .font(.system(size: size * 0.38, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
        }
    }

    private var tint: Color {
        achievement.rarity.map(Theme.color(for:)) ?? Theme.accent
    }
}
