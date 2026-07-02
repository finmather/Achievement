import Foundation

/// Aggregate statistics for a game library.
public struct LibraryStats: Hashable, Sendable, Codable {
    public var totalGames: Int
    public var playedGames: Int
    public var gamesWithAchievements: Int
    public var unlockedAchievements: Int
    public var totalAchievements: Int
    public var perfectGames: Int
    public var totalPlaytimeMinutes: Int
    /// Unlocked ÷ total across every achievement in the library (0...1).
    public var overallCompletion: Double
    /// Mean per-game completion across games with achievements (0...1) — the
    /// figure completionists usually track, matching Steam's own "average game
    /// completion rate".
    public var averageCompletion: Double

    public static let empty = LibraryStats(
        totalGames: 0, playedGames: 0, gamesWithAchievements: 0,
        unlockedAchievements: 0, totalAchievements: 0, perfectGames: 0,
        totalPlaytimeMinutes: 0, overallCompletion: 0, averageCompletion: 0
    )

    public init(
        totalGames: Int, playedGames: Int, gamesWithAchievements: Int,
        unlockedAchievements: Int, totalAchievements: Int, perfectGames: Int,
        totalPlaytimeMinutes: Int, overallCompletion: Double, averageCompletion: Double
    ) {
        self.totalGames = totalGames
        self.playedGames = playedGames
        self.gamesWithAchievements = gamesWithAchievements
        self.unlockedAchievements = unlockedAchievements
        self.totalAchievements = totalAchievements
        self.perfectGames = perfectGames
        self.totalPlaytimeMinutes = totalPlaytimeMinutes
        self.overallCompletion = overallCompletion
        self.averageCompletion = averageCompletion
    }

    public var totalHours: Double { Double(totalPlaytimeMinutes) / 60 }
}

public enum StatsEngine {
    public static func stats(for games: [Game]) -> LibraryStats {
        var playedGames = 0
        var gamesWithAchievements = 0
        var unlocked = 0
        var total = 0
        var perfect = 0
        var playtime = 0
        var completionSum = 0.0

        for game in games {
            playtime += game.playtimeMinutes
            if game.playtimeMinutes > 0 { playedGames += 1 }
            guard let progress = game.achievements, progress.total > 0 else { continue }
            gamesWithAchievements += 1
            unlocked += progress.unlocked
            total += progress.total
            completionSum += progress.fraction
            if progress.isPerfect { perfect += 1 }
        }

        return LibraryStats(
            totalGames: games.count,
            playedGames: playedGames,
            gamesWithAchievements: gamesWithAchievements,
            unlockedAchievements: unlocked,
            totalAchievements: total,
            perfectGames: perfect,
            totalPlaytimeMinutes: playtime,
            overallCompletion: total > 0 ? Double(unlocked) / Double(total) : 0,
            averageCompletion: gamesWithAchievements > 0
                ? completionSum / Double(gamesWithAchievements) : 0
        )
    }
}
