import Foundation

/// Curated demo library used by demo mode, SwiftUI previews, and tests.
///
/// Real Steam appIDs are used so official CDN artwork loads in demo mode.
/// Generation is seeded per app, so the data is stable across launches while
/// unlock dates stay relative to `now` (keeping streaks and "recent" rails
/// alive whenever the demo is opened).
public enum SampleData {
    public static let profileID = SteamID(rawValue: 76_561_197_984_231_774)!

    public static var profile: PlayerProfile {
        PlayerProfile(
            id: profileID,
            personaName: "Fin",
            countryCode: "AU",
            accountCreatedAt: Date(timeIntervalSince1970: 1_357_000_000), // Jan 2013
            isPublic: true
        )
    }

    // MARK: - Library

    /// (appID, name, achievement count, target completion, hours, days since played)
    /// A deliberate mix: perfect games, near-misses, backlog, and zero-progress.
    private static let specs: [(Int, String, Int, Double, Double, Int?)] = [
        (1145360, "Hades", 49, 0.96, 91.4, 0),
        (1245620, "Elden Ring", 42, 0.64, 138.2, 1),
        (413150, "Stardew Valley", 40, 0.75, 204.9, 3),
        (620, "Portal 2", 51, 1.0, 22.3, 26),
        (367520, "Hollow Knight", 63, 0.57, 58.7, 6),
        (504230, "Celeste", 32, 1.0, 41.0, 47),
        (1794680, "Vampire Survivors", 45, 1.0, 68.5, 9),
        (646570, "Slay the Spire", 46, 0.83, 112.6, 13),
        (588650, "Dead Cells", 51, 0.41, 33.8, 71),
        (753640, "Outer Wilds", 24, 0.88, 19.5, 122),
        (268910, "Cuphead", 28, 0.36, 12.1, 155),
        (105600, "Terraria", 88, 0.22, 96.3, 34),
        (264710, "Subnautica", 17, 0.0, 2.4, 201),
        (220, "Half-Life 2", 33, 0.55, 14.0, 310),
        (1057090, "Ori and the Will of the Wisps", 37, 0.0, 0.0, nil),
    ]

    public static func games(now: Date = .now) -> [Game] {
        specs.map { spec in
            let unlocked = unlockedCount(total: spec.2, fraction: spec.3)
            return Game(
                appID: spec.0,
                name: spec.1,
                playtimeMinutes: Int(spec.4 * 60),
                lastPlayed: spec.5.map { now.addingTimeInterval(TimeInterval(-$0 * 86_400 - 3_600)) },
                achievements: spec.2 > 0
                    ? AchievementProgress(unlocked: unlocked, total: spec.2) : nil
            )
        }
    }

    public static func achievements(appID: Int, now: Date = .now) -> [Achievement] {
        guard let spec = specs.first(where: { $0.0 == appID }) else { return [] }
        var rng = SeededGenerator(seed: UInt64(appID))
        let total = spec.2
        let unlocked = unlockedCount(total: total, fraction: spec.3)
        let names = achievementNames(count: total, rng: &rng)
        let daysSincePlayed = spec.5 ?? 400
        // Unlock dates span from "recently played" back through this window.
        let windowDays = max(30, min(540, Int(spec.4 * 4)))

        var result: [Achievement] = []
        for index in 0..<total {
            // Global percent decays with index (jitter decays with it), so
            // every long list spans Common → Legendary.
            let jitter = Double(rng.next() % 40) / 10
            let percent = min(94, (94 + jitter) * pow(0.915, Double(index)))
            let isUnlocked = index < unlocked
            var unlockedAt: Date?
            if isUnlocked {
                let daysAgo = daysSincePlayed + Int(rng.next() % UInt64(windowDays))
                let seconds = TimeInterval(-daysAgo * 86_400) - TimeInterval(rng.next() % 43_200)
                unlockedAt = now.addingTimeInterval(seconds)
            }
            result.append(Achievement(
                id: "SAMPLE_\(appID)_\(index)",
                displayName: names[index],
                detail: descriptions[Int(rng.next() % UInt64(descriptions.count))],
                isHidden: index >= total - 2 && !isUnlocked,
                isUnlocked: isUnlocked,
                unlockedAt: unlockedAt,
                globalPercent: percent
            ))
        }

        // Keep the flagship game's latest unlocks on a live streak so the
        // dashboard always has something to celebrate.
        if appID == specs[0].0, unlocked >= 6 {
            let streakDays = [0, 0, 1, 2, 3, 4]
            for (offset, daysAgo) in streakDays.enumerated() {
                let index = unlocked - 1 - offset
                result[index].unlockedAt = now.addingTimeInterval(
                    TimeInterval(-daysAgo * 86_400) - TimeInterval(1_800 + offset * 600)
                )
            }
        }
        return result
    }

    /// Every unlock across the library, newest first — feeds the dashboard
    /// rail, streaks, and profile history in demo mode.
    public static func allUnlocks(now: Date = .now) -> [UnlockEvent] {
        specs.flatMap { spec in
            achievements(appID: spec.0, now: now).compactMap { achievement in
                guard let date = achievement.unlockedAt else { return nil }
                return UnlockEvent(
                    gameAppID: spec.0, gameName: spec.1,
                    achievement: achievement, unlockedAt: date
                )
            }
        }
        .sorted { $0.unlockedAt > $1.unlockedAt }
    }

    /// Curated community tags per game so the profile radar always has a
    /// rich hexagon in demo mode and previews.
    public static var genreTags: [Int: [String]] {
        [
            1145360: ["Roguelike", "Action RPG", "Hack and Slash"],
            1245620: ["RPG", "Souls-like", "Open World"],
            413150: ["Farming Sim", "RPG", "Simulation"],
            620: ["Puzzle", "FPS", "Co-op"],
            367520: ["Metroidvania", "Platformer", "Souls-like"],
            504230: ["Precision Platformer", "Platformer", "Puzzle"],
            1794680: ["Roguelite", "Action Roguelike", "Bullet Hell"],
            646570: ["Deckbuilding", "Roguelike", "Turn-Based Strategy"],
            588650: ["Roguelite", "Metroidvania", "Platformer"],
            753640: ["Puzzle", "Exploration", "Mystery"],
            268910: ["Platformer", "Precision Platformer", "Boss Rush"],
            105600: ["Sandbox", "Survival", "Adventure"],
            264710: ["Survival", "Open World", "Exploration"],
            220: ["FPS", "Shooter", "Sci-fi"],
            1057090: ["Platformer", "Metroidvania"],
        ]
    }

    // MARK: - Friends

    public static var friends: [PlayerProfile] {
        [
            ("Rook", 101, "SE"), ("Mirabelle", 102, "GB"),
            ("Atlas_77", 103, "US"), ("quietstorm", 104, "JP"),
        ].map { name, offset, country in
            PlayerProfile(
                id: SteamID(rawValue: profileID.rawValue + UInt64(offset))!,
                personaName: name,
                countryCode: country,
                isPublic: true
            )
        }
    }

    /// A friend's version of the library: overlapping subset with scaled
    /// progress, so comparisons have real texture (they win some, you win some).
    public static func friendGames(friendID: SteamID, now: Date = .now) -> [Game] {
        let offset = friendID.rawValue - profileID.rawValue
        var rng = SeededGenerator(seed: offset)
        let factor = [0.45, 0.85, 1.15, 0.65][Int(offset % 4)]

        return games(now: now).compactMap { game in
            guard rng.next() % 10 < 7 else { return nil } // owns ~70% of shared pool
            var friendGame = game
            friendGame.playtimeMinutes = Int(Double(game.playtimeMinutes) * factor
                + Double(rng.next() % 600))
            friendGame.lastPlayed = game.lastPlayed?
                .addingTimeInterval(TimeInterval(-(Int(rng.next() % 14)) * 86_400))
            if let progress = game.achievements {
                let unlocked = min(
                    progress.total,
                    Int(Double(progress.unlocked) * factor) + Int(rng.next() % 4)
                )
                friendGame.achievements = AchievementProgress(
                    unlocked: unlocked, total: progress.total
                )
            }
            return friendGame
        }
    }

    // MARK: - Generation details

    private static func unlockedCount(total: Int, fraction: Double) -> Int {
        min(total, Int((Double(total) * fraction).rounded()))
    }

    private static func achievementNames(count: Int, rng: inout SeededGenerator) -> [String] {
        var pool = namePool
        // Seeded shuffle for per-game variety.
        for index in pool.indices.reversed() where index > 0 {
            pool.swapAt(index, Int(rng.next() % UInt64(index + 1)))
        }
        return (0..<count).map { index in
            index < pool.count
                ? pool[index]
                : "\(pool[index % pool.count]) \(roman(index / pool.count + 1))"
        }
    }

    private static func roman(_ value: Int) -> String {
        ["", "I", "II", "III", "IV", "V"][min(value, 5)]
    }

    private static let namePool = [
        "First Steps", "Into the Depths", "No Stone Unturned", "Against All Odds",
        "The Long Road", "Perfect Run", "Untouchable", "The Collector",
        "Master Tactician", "Speed Demon", "Completionist", "The Final Door",
        "Hidden Truths", "Old Friends", "New Horizons", "Trailblazer",
        "Beyond the Veil", "Iron Will", "Silent Victory", "Grand Finale",
        "One More Turn", "Fearless", "Deep Diver", "Night Owl", "Early Bird",
        "Uncharted", "Relentless", "A Study in Patience", "The Last Piece",
        "Second Wind", "Full Circle", "Apex", "Keeper of Secrets",
        "The Quiet Hours", "Momentum", "Clean Sweep", "Long Shot",
        "Pathfinder", "Homecoming", "The Gilded Path",
    ]

    private static let descriptions = [
        "Complete the opening chapter.",
        "Defeat a boss without taking damage.",
        "Find every collectible in a single region.",
        "Finish a run in under twenty minutes.",
        "Reach the summit the hard way.",
        "Master every weapon at least once.",
        "Uncover the hidden ending.",
        "Win without spending a single coin.",
        "Help every character with their story.",
        "Survive the longest night.",
        "Discover a place few have seen.",
        "Turn certain defeat into victory.",
    ]
}

/// SplitMix64 — deterministic RNG so sample data is stable across launches.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &+ 0x9E37_79B9_7F4A_7C15
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
