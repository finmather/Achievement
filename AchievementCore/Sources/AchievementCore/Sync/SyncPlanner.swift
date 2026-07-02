import Foundation

/// Decides which apps need a per-game achievement fetch. Pure and unit-tested;
/// the policy in one place:
///
/// - Only played games are hydrated (achievements require playing).
/// - A game is re-hydrated when its playtime or last-played time changed
///   since the cached snapshot, or when it has never been hydrated.
/// - Most recently played games come first so the data the user is most
///   likely to look at lands earliest during a sync.
public enum SyncPlanner {
    public static func appsNeedingHydration(
        fresh: [Game],
        cached: [Game],
        hydratedApps: Set<Int>
    ) -> [Int] {
        let cachedByApp = Dictionary(
            cached.map { ($0.appID, $0) },
            uniquingKeysWith: { a, _ in a }
        )

        return fresh
            .filter { game in
                guard game.playtimeMinutes > 0 else { return false }
                guard hydratedApps.contains(game.appID),
                      let previous = cachedByApp[game.appID] else { return true }
                return previous.playtimeMinutes != game.playtimeMinutes
                    || previous.lastPlayed != game.lastPlayed
            }
            .sorted {
                let a = $0.lastPlayed ?? .distantPast
                let b = $1.lastPlayed ?? .distantPast
                if a != b { return a > b }
                return $0.playtimeMinutes > $1.playtimeMinutes
            }
            .map(\.appID)
    }

    /// Carries cached achievement progress forward onto a freshly fetched
    /// owned-games list so the UI never regresses to "unknown" mid-sync.
    public static func mergingCachedProgress(fresh: [Game], cached: [Game]) -> [Game] {
        let cachedByApp = Dictionary(
            cached.map { ($0.appID, $0) },
            uniquingKeysWith: { a, _ in a }
        )
        return fresh.map { game in
            var game = game
            if game.achievements == nil {
                game.achievements = cachedByApp[game.appID]?.achievements
            }
            return game
        }
    }
}
