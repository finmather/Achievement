import Foundation
import AchievementCore

/// Everything the UI needs from "somewhere". Two implementations: live Steam
/// and curated demo data. Previews and demo mode use the demo source, so
/// every screen is exercisable without credentials.
protocol GameDataSource: Sendable {
    func profile() async throws -> PlayerProfile
    func libraryEvents() -> AsyncThrowingStream<LibrarySyncEvent, Error>
    func achievements(appID: Int) async throws -> [Achievement]
    /// Everything already hydrated — powers unlock history without network.
    func allCachedAchievements() async -> [Int: [Achievement]]
    func friends() async throws -> [PlayerProfile]
    func friendGames(friendID: SteamID) async throws -> [Game]
    func friendProgress(appID: Int, friendID: SteamID) async throws -> AchievementProgress?
    /// Community genre tags by appID — feeds the profile radar. Cheap after
    /// first fetch (cached permanently).
    func genreTags() async -> [Int: [String]]
    /// Store-page facts (developer, release date, genres, description) for
    /// the detail page header. Cached permanently; nil on transient failure.
    func gameMeta(appID: Int) async -> GameMeta?
    func clearLocalData() async
}

// MARK: - Live Steam

struct LiveGameDataSource: GameDataSource {
    let player: SteamID
    private let client: SteamWebAPIClient
    private let steamSpy: SteamSpyClient
    private let store: StoreClient
    private let cache: LibraryCache
    private let syncService: LibrarySyncService

    init(player: SteamID, apiKey: String) {
        self.player = player
        client = SteamWebAPIClient(apiKey: apiKey)
        steamSpy = SteamSpyClient()
        store = StoreClient()
        cache = LibraryCache(directory: AppConfig.cacheDirectory)
        syncService = LibrarySyncService(client: client, cache: cache)
    }

    func profile() async throws -> PlayerProfile {
        do {
            let profile = try await client.profile(for: player)
            await cache.storeProfile(profile)
            return profile
        } catch {
            // Offline launch: cached identity beats an error screen.
            if let cached = await cache.profile() { return cached }
            throw error
        }
    }

    func libraryEvents() -> AsyncThrowingStream<LibrarySyncEvent, Error> {
        syncService.sync(player: player)
    }

    func achievements(appID: Int) async throws -> [Achievement] {
        if let cached = await cache.achievements(appID: appID) {
            return cached
        }
        let fresh = try await client.achievements(appID: appID, player: player)
        await cache.storeAchievements(fresh, appID: appID)
        return fresh
    }

    func allCachedAchievements() async -> [Int: [Achievement]] {
        await cache.allAchievements()
    }

    func friends() async throws -> [PlayerProfile] {
        do {
            let ids = try await client.friendIDs(of: player)
            let profiles = try await client.playerSummaries(for: ids)
            await cache.storeFriends(profiles)
            return sortedByName(profiles)
        } catch {
            if let cached = await cache.friends() { return sortedByName(cached) }
            throw error
        }
    }

    func friendGames(friendID: SteamID) async throws -> [Game] {
        try await client.ownedGames(of: friendID)
    }

    func friendProgress(appID: Int, friendID: SteamID) async throws -> AchievementProgress? {
        do {
            let achievements = try await client.achievements(appID: appID, player: friendID)
            return AchievementProgress(
                unlocked: achievements.filter(\.isUnlocked).count,
                total: achievements.count
            )
        } catch SteamWebAPIError.noAchievements {
            return nil
        }
    }

    /// Tags never change, so anything cached is final. Fetch a bounded batch
    /// of missing ones per call (most-played first, SteamSpy asks for ~1
    /// req/sec politeness) — a big library fills in over a few refreshes.
    func genreTags() async -> [Int: [String]] {
        var known = await cache.genreTags() ?? [:]
        let played = (await cache.games() ?? [])
            .filter { $0.playtimeMinutes > 0 }
            .sorted { $0.playtimeMinutes > $1.playtimeMinutes }
            .map(\.appID)
        let missing = played.filter { known[$0] == nil }.prefix(30)
        guard !missing.isEmpty else { return known }

        for appID in missing {
            do {
                known[appID] = try await steamSpy.tags(appID: appID)
            } catch {
                break // transient (network, rate limit) — next refresh resumes
            }
            try? await Task.sleep(for: .milliseconds(400))
        }
        await cache.storeGenreTags(known)
        return known
    }

    func gameMeta(appID: Int) async -> GameMeta? {
        if let cached = await cache.gameMeta(appID: appID) {
            return cached
        }
        guard let meta = try? await store.meta(appID: appID) else {
            return nil // transient — the next detail visit retries
        }
        await cache.storeGameMeta(meta, appID: appID)
        return meta
    }

    func clearLocalData() async {
        await cache.clear()
    }

    private func sortedByName(_ profiles: [PlayerProfile]) -> [PlayerProfile] {
        profiles.sorted {
            $0.personaName.localizedCaseInsensitiveCompare($1.personaName) == .orderedAscending
        }
    }
}

// MARK: - Demo

/// Sample data with a touch of latency so loading states stay honest.
struct DemoGameDataSource: GameDataSource {
    func profile() async throws -> PlayerProfile {
        try? await Task.sleep(for: .milliseconds(250))
        return SampleData.profile
    }

    func libraryEvents() -> AsyncThrowingStream<LibrarySyncEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                try? await Task.sleep(for: .milliseconds(450))
                continuation.yield(.library(SampleData.games()))
                continuation.yield(.hydrationPlanned(total: 0))
                continuation.yield(.finished(failedAppIDs: []))
                continuation.finish()
            }
        }
    }

    func achievements(appID: Int) async throws -> [Achievement] {
        try? await Task.sleep(for: .milliseconds(300))
        return SampleData.achievements(appID: appID)
    }

    func allCachedAchievements() async -> [Int: [Achievement]] {
        var result: [Int: [Achievement]] = [:]
        for game in SampleData.games() {
            let achievements = SampleData.achievements(appID: game.appID)
            if !achievements.isEmpty {
                result[game.appID] = achievements
            }
        }
        return result
    }

    func friends() async throws -> [PlayerProfile] {
        try? await Task.sleep(for: .milliseconds(350))
        return SampleData.friends
    }

    func friendGames(friendID: SteamID) async throws -> [Game] {
        try? await Task.sleep(for: .milliseconds(400))
        return SampleData.friendGames(friendID: friendID)
    }

    func friendProgress(appID: Int, friendID: SteamID) async throws -> AchievementProgress? {
        SampleData.friendGames(friendID: friendID)
            .first { $0.appID == appID }?
            .achievements
    }

    func genreTags() async -> [Int: [String]] {
        SampleData.genreTags
    }

    func gameMeta(appID: Int) async -> GameMeta? {
        SampleData.gameMeta[appID]
    }

    func clearLocalData() async {}
}
