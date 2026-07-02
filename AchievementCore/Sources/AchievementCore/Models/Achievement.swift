import Foundation

/// A single achievement within a game, merged from the game schema (names,
/// icons), the player's unlock state, and global unlock percentages (rarity).
public struct Achievement: Identifiable, Hashable, Sendable, Codable {
    /// Steam's internal API name — unique within a game.
    public let id: String
    public var displayName: String
    /// May be `nil` for hidden achievements that are still locked.
    public var detail: String?
    public var isHidden: Bool
    public var iconURL: URL?
    public var lockedIconURL: URL?
    public var isUnlocked: Bool
    public var unlockedAt: Date?
    /// Percentage (0–100) of global players who unlocked this. `nil` when unknown.
    public var globalPercent: Double?

    public init(
        id: String,
        displayName: String,
        detail: String? = nil,
        isHidden: Bool = false,
        iconURL: URL? = nil,
        lockedIconURL: URL? = nil,
        isUnlocked: Bool = false,
        unlockedAt: Date? = nil,
        globalPercent: Double? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.detail = detail
        self.isHidden = isHidden
        self.iconURL = iconURL
        self.lockedIconURL = lockedIconURL
        self.isUnlocked = isUnlocked
        self.unlockedAt = unlockedAt
        self.globalPercent = globalPercent
    }

    public var rarity: Rarity? { globalPercent.map(Rarity.init(globalPercent:)) }
}

/// Rarity tiers derived from the percentage of global players holding an
/// achievement. Thresholds follow community convention (Steam Hunters et al.).
public enum Rarity: String, CaseIterable, Hashable, Sendable, Codable, Comparable {
    case common
    case uncommon
    case rare
    case veryRare
    case legendary

    public init(globalPercent: Double) {
        switch max(0, globalPercent) {
        case ..<1: self = .legendary
        case ..<5: self = .veryRare
        case ..<20: self = .rare
        case ..<50: self = .uncommon
        default: self = .common
        }
    }

    public var displayName: String {
        switch self {
        case .common: "Common"
        case .uncommon: "Uncommon"
        case .rare: "Rare"
        case .veryRare: "Very Rare"
        case .legendary: "Legendary"
        }
    }

    /// Rarity order for sorting: common < ... < legendary.
    public static func < (lhs: Rarity, rhs: Rarity) -> Bool {
        let order: [Rarity] = [.common, .uncommon, .rare, .veryRare, .legendary]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

/// An unlock event with enough context to render outside its game page
/// (Dashboard's "recently unlocked" rail, profile history).
public struct UnlockEvent: Identifiable, Hashable, Sendable, Codable {
    public let gameAppID: Int
    public let gameName: String
    public let achievement: Achievement
    public let unlockedAt: Date

    public var id: String { "\(gameAppID).\(achievement.id)" }

    public init(gameAppID: Int, gameName: String, achievement: Achievement, unlockedAt: Date) {
        self.gameAppID = gameAppID
        self.gameName = gameName
        self.achievement = achievement
        self.unlockedAt = unlockedAt
    }
}
