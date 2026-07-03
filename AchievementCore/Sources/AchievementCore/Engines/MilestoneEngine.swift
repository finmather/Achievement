import Foundation

/// The single most motivating next goal, shown on the dashboard.
public enum Milestone: Hashable, Sendable {
    /// A game close enough to 100% to chase.
    case perfectGame(game: Game, remaining: Int)
    /// One more day beats the all-time streak record.
    case streakRecord(record: Int, remaining: Int)
    /// The next round-number unlock total.
    case unlockCount(target: Int, remaining: Int)
}

public enum MilestoneEngine {
    /// Priority: a nearly-perfect game (the completionist's real goal), then
    /// a streak record within reach, then the next 50-unlock landmark.
    public static func next(
        games: [Game],
        stats: LibraryStats,
        streak: StreakSummary
    ) -> Milestone? {
        let nearlyPerfect = games.filter { game in
            guard let progress = game.achievements else { return false }
            return progress.fraction >= 0.7 && !progress.isPerfect
        }
        let candidate = nearlyPerfect.min { a, b in
            let remainingA = a.achievements!.remaining
            let remainingB = b.achievements!.remaining
            if remainingA != remainingB { return remainingA < remainingB }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        if let candidate {
            return .perfectGame(game: candidate, remaining: candidate.achievements!.remaining)
        }

        if streak.current >= 2, streak.longest > streak.current,
           streak.longest - streak.current <= 2 {
            return .streakRecord(
                record: streak.longest,
                remaining: streak.longest - streak.current + 1
            )
        }

        if stats.unlockedAchievements > 0 {
            let target = (stats.unlockedAchievements / 50 + 1) * 50
            return .unlockCount(
                target: target,
                remaining: target - stats.unlockedAchievements
            )
        }

        return nil
    }
}
