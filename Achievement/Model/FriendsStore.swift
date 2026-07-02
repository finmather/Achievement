import Foundation
import AchievementCore

@Observable @MainActor
final class FriendsStore {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case unavailable(String)
    }

    private let dataSource: any GameDataSource
    private(set) var friends: [PlayerProfile] = []
    private(set) var phase: Phase = .idle

    init(dataSource: any GameDataSource) {
        self.dataSource = dataSource
    }

    func loadIfNeeded() async {
        guard phase == .idle || isUnavailable else { return }
        phase = .loading
        do {
            friends = try await dataSource.friends()
            phase = .loaded
        } catch SteamWebAPIError.profilePrivate {
            phase = .unavailable(
                "Your friends list is private on Steam. Set it to public to compare progress."
            )
        } catch {
            phase = .unavailable("Couldn't load friends right now. Pull to try again.")
        }
    }

    private var isUnavailable: Bool {
        if case .unavailable = phase { return true }
        return false
    }
}

/// Drives one head-to-head screen. Friend progress arrives progressively:
/// the shared-game list renders instantly from library data, then per-game
/// friend completion fills in (Steam requires one call per game).
@Observable @MainActor
final class ComparisonModel {
    let friend: PlayerProfile
    private let dataSource: any GameDataSource
    private let myGames: [Game]

    private(set) var comparison: FriendComparison?
    private(set) var isLoading = false
    private(set) var isHydratingShared = false
    private(set) var errorMessage: String?

    /// Per-game friend achievement fetches per comparison — enough for the
    /// screen, gentle on the API.
    private static let sharedHydrationLimit = 12

    init(friend: PlayerProfile, myGames: [Game], dataSource: any GameDataSource) {
        self.friend = friend
        self.myGames = myGames
        self.dataSource = dataSource
    }

    var sharedGames: [GameComparison] {
        guard let comparison else { return [] }
        return Array(comparison.sharedGames.prefix(Self.sharedHydrationLimit))
    }

    /// "You lead in 4 of 9" — only counts games where both sides are known.
    var headToHead: (mine: Int, theirs: Int, decided: Int) {
        var mine = 0, theirs = 0, decided = 0
        for shared in sharedGames {
            guard let my = shared.mine, let their = shared.theirs else { continue }
            decided += 1
            if my.fraction > their.fraction { mine += 1 }
            else if their.fraction > my.fraction { theirs += 1 }
        }
        return (mine, theirs, decided)
    }

    func load() async {
        guard comparison == nil, !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            var friendGames = try await dataSource.friendGames(friendID: friend.id)
            comparison = ComparisonEngine.compare(myGames: myGames, friendGames: friendGames)
            isLoading = false

            // Fill in friend completion for the games on screen.
            let targets = sharedGames
                .filter { $0.theirs == nil }
                .map(\.game.appID)
            guard !targets.isEmpty else { return }

            isHydratingShared = true
            for appID in targets.prefix(Self.sharedHydrationLimit) {
                guard let progress = try? await dataSource.friendProgress(
                    appID: appID, friendID: friend.id
                ) else { continue }
                if let index = friendGames.firstIndex(where: { $0.appID == appID }) {
                    friendGames[index].achievements = progress
                    comparison = ComparisonEngine.compare(
                        myGames: myGames, friendGames: friendGames
                    )
                }
            }
            isHydratingShared = false
        } catch SteamWebAPIError.profilePrivate {
            isLoading = false
            errorMessage = "\(friend.personaName)'s game details are private on Steam."
        } catch {
            isLoading = false
            errorMessage = "Couldn't load this comparison. Try again in a moment."
        }
    }
}
