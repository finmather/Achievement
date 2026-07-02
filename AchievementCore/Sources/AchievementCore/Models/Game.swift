import Foundation

/// A game in a player's Steam library, including whatever achievement progress
/// has been hydrated so far (`achievements == nil` until the per-game fetch runs,
/// or forever for games that expose no achievements).
public struct Game: Identifiable, Hashable, Sendable, Codable {
    public let appID: Int
    public var name: String
    public var playtimeMinutes: Int
    public var lastPlayed: Date?
    /// Steam community icon hash from `GetOwnedGames` (`img_icon_url`).
    public var iconHash: String?
    public var achievements: AchievementProgress?

    public var id: Int { appID }

    public init(
        appID: Int,
        name: String,
        playtimeMinutes: Int = 0,
        lastPlayed: Date? = nil,
        iconHash: String? = nil,
        achievements: AchievementProgress? = nil
    ) {
        self.appID = appID
        self.name = name
        self.playtimeMinutes = playtimeMinutes
        self.lastPlayed = lastPlayed
        self.iconHash = iconHash
        self.achievements = achievements
    }

    public var artwork: SteamArtwork { SteamArtwork(appID: appID, iconHash: iconHash) }

    public var hoursPlayed: Double { Double(playtimeMinutes) / 60 }

    public var isPerfect: Bool { achievements?.isPerfect ?? false }
}

/// Unlocked/total achievement counts for a single game.
public struct AchievementProgress: Hashable, Sendable, Codable {
    public var unlocked: Int
    public var total: Int

    public init(unlocked: Int, total: Int) {
        self.unlocked = max(0, unlocked)
        self.total = max(0, total)
    }

    /// 0...1, and 0 when the game has no achievements at all.
    public var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(unlocked) / Double(total)
    }

    public var isPerfect: Bool { total > 0 && unlocked == total }

    public var remaining: Int { max(0, total - unlocked) }
}
