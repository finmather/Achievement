import Foundation

/// One shared game in a head-to-head comparison.
public struct GameComparison: Identifiable, Hashable, Sendable {
    public let game: Game
    public let mine: AchievementProgress?
    public let theirs: AchievementProgress?
    public let myPlaytimeMinutes: Int
    public let theirPlaytimeMinutes: Int

    public var id: Int { game.appID }

    public init(
        game: Game,
        mine: AchievementProgress?,
        theirs: AchievementProgress?,
        myPlaytimeMinutes: Int,
        theirPlaytimeMinutes: Int
    ) {
        self.game = game
        self.mine = mine
        self.theirs = theirs
        self.myPlaytimeMinutes = myPlaytimeMinutes
        self.theirPlaytimeMinutes = theirPlaytimeMinutes
    }
}

/// Head-to-head summary between the player and one friend.
public struct FriendComparison: Hashable, Sendable {
    public let myStats: LibraryStats
    public let friendStats: LibraryStats
    /// Games both own, ordered by combined playtime (most-shared-history first).
    public let sharedGames: [GameComparison]

    public var sharedGameCount: Int { sharedGames.count }

    public init(myStats: LibraryStats, friendStats: LibraryStats, sharedGames: [GameComparison]) {
        self.myStats = myStats
        self.friendStats = friendStats
        self.sharedGames = sharedGames
    }
}

public enum ComparisonEngine {
    public static func compare(myGames: [Game], friendGames: [Game]) -> FriendComparison {
        let friendByApp = Dictionary(
            friendGames.map { ($0.appID, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let shared: [GameComparison] = myGames.compactMap { mine in
            guard let theirs = friendByApp[mine.appID] else { return nil }
            return GameComparison(
                game: mine,
                mine: mine.achievements,
                theirs: theirs.achievements,
                myPlaytimeMinutes: mine.playtimeMinutes,
                theirPlaytimeMinutes: theirs.playtimeMinutes
            )
        }
        .sorted {
            let a = $0.myPlaytimeMinutes + $0.theirPlaytimeMinutes
            let b = $1.myPlaytimeMinutes + $1.theirPlaytimeMinutes
            if a != b { return a > b }
            return $0.game.name.localizedCaseInsensitiveCompare($1.game.name) == .orderedAscending
        }

        return FriendComparison(
            myStats: StatsEngine.stats(for: myGames),
            friendStats: StatsEngine.stats(for: friendGames),
            sharedGames: shared
        )
    }
}
