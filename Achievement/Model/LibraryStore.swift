import Foundation
import AchievementCore

/// Library sync lifecycle as the UI sees it. Hydration is a visible,
/// first-class state — a first import can take a while and should feel alive.
enum SyncPhase: Equatable {
    case idle
    case loadingLibrary
    case hydrating(done: Int, total: Int)
    case failed(String)
}

@Observable @MainActor
final class LibraryStore {
    private let dataSource: any GameDataSource

    private(set) var games: [Game] = []
    private(set) var phase: SyncPhase = .idle
    private(set) var stats: LibraryStats = .empty
    /// Every known unlock, newest first.
    private(set) var unlocks: [UnlockEvent] = []
    private(set) var streak: StreakSummary = .none
    private(set) var lastSynced: Date?
    /// Set when a refresh discovers unlocks that weren't there before —
    /// drives the celebration overlay, then gets cleared.
    private(set) var freshUnlockCount = 0
    /// The newest of those fresh unlocks — the one the celebration stars.
    private(set) var latestFreshUnlock: UnlockEvent?
    /// Community genre tags by appID, feeding the profile radar.
    private(set) var genreTags: [Int: [String]] = [:]

    private var achievementsByApp: [Int: [Achievement]] = [:]
    private var knownUnlockIDs: Set<String>?
    private var isRefreshing = false

    init(dataSource: any GameDataSource) {
        self.dataSource = dataSource
    }

    var hasContent: Bool { !games.isEmpty }

    var recentlyPlayed: [Game] {
        Array(
            LibraryFilter.sorted(games, by: .recentlyPlayed)
                .filter { $0.lastPlayed != nil }
                .prefix(6)
        )
    }

    /// Games worth nudging toward 100% — close, but not done.
    var nearlyPerfect: [Game] {
        games
            .filter { game in
                guard let progress = game.achievements else { return false }
                return progress.fraction >= 0.7 && !progress.isPerfect
            }
            .sorted { ($0.achievements?.fraction ?? 0) > ($1.achievements?.fraction ?? 0) }
    }

    var recentUnlocks: [UnlockEvent] { Array(unlocks.prefix(12)) }

    var genreProfile: GenreProfile {
        GenreEngine.profile(games: games, tagsByApp: genreTags)
    }

    var habits: GamingHabits {
        HabitsEngine.habits(unlockDates: unlocks.map(\.unlockedAt))
    }

    var yearSummary: YearSummary {
        HabitsEngine.yearSummary(
            year: Calendar.current.component(.year, from: .now),
            unlocks: unlocks,
            games: games
        )
    }

    var nextMilestone: Milestone? {
        MilestoneEngine.next(games: games, stats: stats, streak: streak)
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        if games.isEmpty { phase = .loadingLibrary }
        var done = 0
        var planned = 0

        do {
            for try await event in dataSource.libraryEvents() {
                switch event {
                case .library(let list):
                    games = list
                    recomputeStats()

                case .hydrationPlanned(let total):
                    planned = total
                    if total > 0 { phase = .hydrating(done: 0, total: total) }

                case .gameHydrated(let game, let achievements):
                    done += 1
                    achievementsByApp[game.appID] = achievements
                    if let index = games.firstIndex(where: { $0.appID == game.appID }) {
                        games[index] = game
                    }
                    phase = .hydrating(done: done, total: max(planned, done))
                    recomputeStats()

                case .finished:
                    lastSynced = .now
                }
            }
            await rebuildUnlockHistory()
            genreTags = await dataSource.genreTags()
            phase = .idle
        } catch {
            phase = .failed(friendlyMessage(for: error))
        }
    }

    func achievements(for game: Game) async throws -> [Achievement] {
        if let cached = achievementsByApp[game.appID] { return cached }
        let fresh = try await dataSource.achievements(appID: game.appID)
        achievementsByApp[game.appID] = fresh
        return fresh
    }

    func acknowledgeFreshUnlocks() {
        freshUnlockCount = 0
        latestFreshUnlock = nil
    }

    func clearLocalData() async {
        await dataSource.clearLocalData()
    }

    // MARK: - Internals

    private func recomputeStats() {
        stats = StatsEngine.stats(for: games)
    }

    private func rebuildUnlockHistory() async {
        let all = await dataSource.allCachedAchievements()
        achievementsByApp.merge(all) { current, _ in current }

        let namesByApp = Dictionary(
            games.map { ($0.appID, $0.name) },
            uniquingKeysWith: { a, _ in a }
        )
        var events: [UnlockEvent] = []
        for (appID, achievements) in all {
            guard let name = namesByApp[appID] else { continue }
            for achievement in achievements where achievement.isUnlocked {
                guard let date = achievement.unlockedAt else { continue }
                events.append(UnlockEvent(
                    gameAppID: appID, gameName: name,
                    achievement: achievement, unlockedAt: date
                ))
            }
        }
        unlocks = events.sorted { $0.unlockedAt > $1.unlockedAt }
        streak = StreakEngine.summary(unlockDates: unlocks.map(\.unlockedAt))

        // Celebrate only unlocks that appeared after the first full load.
        let ids = Set(unlocks.map(\.id))
        if let known = knownUnlockIDs {
            let fresh = ids.subtracting(known)
            if !fresh.isEmpty {
                freshUnlockCount = fresh.count
                latestFreshUnlock = unlocks.first { fresh.contains($0.id) }
            }
        }
        knownUnlockIDs = ids
    }

    private func friendlyMessage(for error: Error) -> String {
        if let apiError = error as? SteamWebAPIError,
           let description = apiError.errorDescription {
            return description
        }
        return "Couldn't reach Steam. Check your connection and try again."
    }
}
