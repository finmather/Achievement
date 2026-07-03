import Foundation

/// Estimates hours to 100% from the player's own demonstrated pace.
///
/// Model: the player's cost per unlock so far (`hoursPlayed / unlocked`)
/// scaled per remaining achievement by rarity — rarer achievements take
/// disproportionately longer, approximated by `sqrt(50 / globalPercent)`
/// clamped to [0.8, 6]. Honest by construction: no estimate without observed
/// pace (never played, or nothing unlocked yet).
public enum CompletionEstimator {
    public static func hoursToComplete(
        game: Game,
        achievements: [Achievement]
    ) -> Double? {
        guard let progress = game.achievements,
              progress.remaining > 0,
              progress.unlocked > 0,
              game.playtimeMinutes > 0 else { return nil }

        let locked = achievements.filter { !$0.isUnlocked }
        guard !locked.isEmpty else { return nil }

        let pace = game.hoursPlayed / Double(progress.unlocked)
        let total = locked.reduce(0.0) { sum, achievement in
            sum + pace * rarityFactor(achievement.globalPercent)
        }
        return min(total, 500)
    }

    static func rarityFactor(_ globalPercent: Double?) -> Double {
        // Unknown rarity assumes a middling 25%.
        let percent = max(globalPercent ?? 25, 1)
        return min(6, max(0.8, (50 / percent).squareRoot()))
    }
}
