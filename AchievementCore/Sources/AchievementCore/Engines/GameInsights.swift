import Foundation

/// Data-driven guidance for one game — real numbers from the player's own
/// record and global rarity, never fabricated walkthrough content.
public struct GameInsights: Hashable, Sendable {
    /// Up to three most-attainable locked achievements (highest global %),
    /// hidden ones excluded — nudges, not spoilers.
    public let easiestRemaining: [Achievement]
    /// The rarest achievement the player has already earned here.
    public let rarestEarned: Achievement?
    /// Unlocks per hour of playtime.
    public let unlockPace: Double?
    public let firstUnlock: Date?
    public let latestUnlock: Date?

    public var isEmpty: Bool {
        easiestRemaining.isEmpty && rarestEarned == nil && unlockPace == nil
    }
}

public enum GameInsightsEngine {
    public static func insights(game: Game, achievements: [Achievement]) -> GameInsights {
        let unlockedDates = achievements
            .filter(\.isUnlocked)
            .compactMap(\.unlockedAt)

        let easiest = achievements
            .filter { !$0.isUnlocked && !$0.isHidden && $0.globalPercent != nil }
            .sorted { ($0.globalPercent ?? 0) > ($1.globalPercent ?? 0) }
            .prefix(3)

        let rarest = achievements
            .filter { $0.isUnlocked && $0.globalPercent != nil }
            .min { ($0.globalPercent ?? 100) < ($1.globalPercent ?? 100) }

        let unlocked = achievements.filter(\.isUnlocked).count
        let pace: Double? = game.hoursPlayed > 0 && unlocked > 0
            ? Double(unlocked) / game.hoursPlayed
            : nil

        return GameInsights(
            easiestRemaining: Array(easiest),
            rarestEarned: rarest,
            unlockPace: pace,
            firstUnlock: unlockedDates.min(),
            latestUnlock: unlockedDates.max()
        )
    }
}
