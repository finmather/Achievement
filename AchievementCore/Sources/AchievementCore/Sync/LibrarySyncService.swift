import Foundation

/// Progress events streamed while a library sync runs. The UI renders every
/// intermediate state, so a first import feels alive rather than blocking.
public enum LibrarySyncEvent: Sendable {
    /// Full game list (first from cache, then fresh from Steam, then final).
    case library([Game])
    /// How many games this sync will hydrate with per-game achievement data.
    case hydrationPlanned(total: Int)
    /// One game's achievements landed.
    case gameHydrated(game: Game, achievements: [Achievement])
    /// Sync completed. Transient per-game failures are listed, not fatal.
    case finished(failedAppIDs: [Int])
}

/// Orchestrates a full library sync:
///
/// 1. Emit cached games immediately (instant UI).
/// 2. Fetch the owned-games list, carrying cached progress forward.
/// 3. Hydrate per-game achievements for the apps `SyncPlanner` selects,
///    a few at a time, most recently played first.
/// 4. Persist everything back to the cache.
///
/// Stateless — safe to use from any task.
public struct LibrarySyncService: Sendable {
    /// Steam has no bulk achievements endpoint; keep per-game fetches polite.
    public static let hydrationBatchSize = 4

    private let client: SteamWebAPIClient
    private let cache: LibraryCache

    public init(client: SteamWebAPIClient, cache: LibraryCache) {
        self.client = client
        self.cache = cache
    }

    public func sync(player: SteamID) -> AsyncThrowingStream<LibrarySyncEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await run(player: player, continuation: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func run(
        player: SteamID,
        continuation: AsyncThrowingStream<LibrarySyncEvent, Error>.Continuation
    ) async throws {
        let cached = await cache.games() ?? []
        if !cached.isEmpty {
            continuation.yield(.library(cached))
        }

        let fresh = try await client.ownedGames(of: player)
        var games = SyncPlanner.mergingCachedProgress(fresh: fresh, cached: cached)
        continuation.yield(.library(games))

        let plan = SyncPlanner.appsNeedingHydration(
            fresh: games,
            cached: cached,
            hydratedApps: await cache.hydratedAppIDs()
        )
        continuation.yield(.hydrationPlanned(total: plan.count))

        var indexByApp: [Int: Int] = [:]
        for (index, game) in games.enumerated() {
            indexByApp[game.appID] = index
        }

        var failed: [Int] = []
        let client = self.client

        for batch in plan.chunked(into: Self.hydrationBatchSize) {
            try Task.checkCancellation()
            try await withThrowingTaskGroup(
                of: (Int, Result<[Achievement], Error>).self
            ) { group in
                for appID in batch {
                    group.addTask {
                        do {
                            let achievements = try await client.achievements(
                                appID: appID, player: player
                            )
                            return (appID, .success(achievements))
                        } catch {
                            return (appID, .failure(error))
                        }
                    }
                }

                while let (appID, result) = try await group.next() {
                    switch result {
                    case .success(let achievements):
                        await cache.storeAchievements(achievements, appID: appID)
                        if let index = indexByApp[appID] {
                            let unlocked = achievements.filter(\.isUnlocked).count
                            games[index].achievements = AchievementProgress(
                                unlocked: unlocked, total: achievements.count
                            )
                            continuation.yield(.gameHydrated(
                                game: games[index], achievements: achievements
                            ))
                        }

                    case .failure(SteamWebAPIError.noAchievements):
                        // Remember the empty result so we never refetch it.
                        await cache.storeAchievements([], appID: appID)

                    case .failure(SteamWebAPIError.profilePrivate):
                        throw SteamWebAPIError.profilePrivate

                    case .failure:
                        // Transient (network, rate limit) — next sync retries.
                        failed.append(appID)
                    }
                }
            }
        }

        await cache.storeGames(games)
        continuation.yield(.library(games))
        continuation.yield(.finished(failedAppIDs: failed))
    }
}
