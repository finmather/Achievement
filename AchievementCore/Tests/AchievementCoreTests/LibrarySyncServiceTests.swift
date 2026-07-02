import XCTest
@testable import AchievementCore

private let player = SteamID(rawValue: 76_561_197_984_231_774)!

/// One played game with achievements (620), one never played (105600).
private let ownedGamesJSON = """
{"response":{"game_count":2,"games":[
  {"appid":620,"name":"Portal 2","playtime_forever":1338,"rtime_last_played":1700000000},
  {"appid":105600,"name":"Terraria","playtime_forever":0}
]}}
"""

private let schemaJSON = """
{"game":{"availableGameStats":{"achievements":[
  {"name":"A","displayName":"Alpha","hidden":0},
  {"name":"B","displayName":"Beta","hidden":0}
]}}}
"""

private let playerAchievementsJSON = """
{"playerstats":{"success":true,"achievements":[
  {"apiname":"A","achieved":1,"unlocktime":1600000000},
  {"apiname":"B","achieved":0,"unlocktime":0}
]}}
"""

private let globalJSON = """
{"achievementpercentages":{"achievements":[{"name":"A","percent":80.0},{"name":"B","percent":4.0}]}}
"""

final class LibrarySyncServiceTests: XCTestCase {
    private var cacheDirectory: URL!

    override func setUp() {
        super.setUp()
        cacheDirectory = uniqueTempDirectory()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        super.tearDown()
    }

    private func makeService(
        handler: @escaping @Sendable (URLRequest) throws -> (Data, Int)
    ) -> (LibrarySyncService, LibraryCache) {
        let cache = LibraryCache(directory: cacheDirectory)
        let client = SteamWebAPIClient(apiKey: "TESTKEY", httpClient: MockHTTPClient(handler: handler))
        return (LibrarySyncService(client: client, cache: cache), cache)
    }

    private static let happyPathHandler: @Sendable (URLRequest) throws -> (Data, Int) = { request in
        let path = request.url!.path
        if path.contains("GetOwnedGames") { return (Data(ownedGamesJSON.utf8), 200) }
        if path.contains("GetSchemaForGame") { return (Data(schemaJSON.utf8), 200) }
        if path.contains("GetPlayerAchievements") { return (Data(playerAchievementsJSON.utf8), 200) }
        if path.contains("GetGlobalAchievementPercentagesForApp") { return (Data(globalJSON.utf8), 200) }
        return (Data(), 404)
    }

    private func collectEvents(_ service: LibrarySyncService) async throws -> [LibrarySyncEvent] {
        var events: [LibrarySyncEvent] = []
        for try await event in service.sync(player: player) {
            events.append(event)
        }
        return events
    }

    func testFirstSyncHydratesOnlyPlayedGamesAndPersists() async throws {
        let (service, cache) = makeService(handler: Self.happyPathHandler)
        let events = try await collectEvents(service)

        // Fresh library, plan, one hydration, final library, finished.
        guard case .library(let fresh) = events.first else {
            return XCTFail("first event should be the fresh library, got \(events)")
        }
        XCTAssertEqual(fresh.count, 2)

        guard case .hydrationPlanned(let total) = events[1] else {
            return XCTFail("expected hydrationPlanned, got \(events[1])")
        }
        XCTAssertEqual(total, 1, "unplayed games must not be hydrated")

        guard case .gameHydrated(let game, let achievements) = events[2] else {
            return XCTFail("expected gameHydrated, got \(events[2])")
        }
        XCTAssertEqual(game.appID, 620)
        XCTAssertEqual(game.achievements, AchievementProgress(unlocked: 1, total: 2))
        XCTAssertEqual(achievements.count, 2)

        guard case .finished(let failed) = events.last else {
            return XCTFail("expected finished, got \(String(describing: events.last))")
        }
        XCTAssertTrue(failed.isEmpty)

        // Persistence: both the game list and per-game achievements.
        let cachedGames = await cache.games()
        XCTAssertEqual(cachedGames?.first { $0.appID == 620 }?.achievements?.unlocked, 1)
        let cachedAchievements = await cache.achievements(appID: 620)
        XCTAssertEqual(cachedAchievements?.count, 2)
    }

    func testSecondSyncWithUnchangedLibrarySkipsHydration() async throws {
        let (service, _) = makeService(handler: Self.happyPathHandler)
        _ = try await collectEvents(service)

        let events = try await collectEvents(service)

        // Cached library arrives first now, then fresh.
        guard case .library(let cached) = events.first else {
            return XCTFail("expected cached library first")
        }
        XCTAssertEqual(cached.first { $0.appID == 620 }?.achievements?.total, 2,
                       "cached progress must render immediately")

        let planned = events.compactMap { event -> Int? in
            if case .hydrationPlanned(let total) = event { return total }
            return nil
        }
        XCTAssertEqual(planned, [0], "nothing changed, nothing to hydrate")
    }

    func testTransientHydrationFailureIsReportedNotFatal() async throws {
        let (service, _) = makeService { request in
            let path = request.url!.path
            if path.contains("GetOwnedGames") { return (Data(ownedGamesJSON.utf8), 200) }
            return (Data(), 500) // every per-game call fails
        }
        let events = try await collectEvents(service)

        guard case .finished(let failed) = events.last else {
            return XCTFail("sync should still finish")
        }
        XCTAssertEqual(failed, [620])
    }

    func testPrivateProfileAbortsSync() async {
        let privateJSON = "{\"playerstats\":{\"error\":\"Profile is not public\",\"success\":false}}"
        let (service, _) = makeService { request in
            let path = request.url!.path
            if path.contains("GetOwnedGames") { return (Data(ownedGamesJSON.utf8), 200) }
            if path.contains("GetSchemaForGame") { return (Data(schemaJSON.utf8), 200) }
            if path.contains("GetPlayerAchievements") { return (Data(privateJSON.utf8), 403) }
            return (Data(globalJSON.utf8), 200)
        }
        do {
            _ = try await collectEvents(service)
            XCTFail("expected profilePrivate to abort the stream")
        } catch {
            XCTAssertEqual(error as? SteamWebAPIError, .profilePrivate)
        }
    }

    func testGameWithNoAchievementsIsCachedAsEmptyAndNotRefetched() async throws {
        let noStatsSchema = "{\"game\":{}}"
        let (service, cache) = makeService { request in
            let path = request.url!.path
            if path.contains("GetOwnedGames") { return (Data(ownedGamesJSON.utf8), 200) }
            if path.contains("GetSchemaForGame") { return (Data(noStatsSchema.utf8), 200) }
            if path.contains("GetPlayerAchievements") { return (Data(playerAchievementsJSON.utf8), 200) }
            return (Data(globalJSON.utf8), 200)
        }
        _ = try await collectEvents(service)

        let cached = await cache.achievements(appID: 620)
        XCTAssertEqual(cached, [], "no-achievement result must be cached as empty, not missing")

        let hydrated = await cache.hydratedAppIDs()
        XCTAssertTrue(hydrated.contains(620))
    }
}

final class LibraryCacheTests: XCTestCase {
    private var directory: URL!
    private var cache: LibraryCache!

    override func setUp() {
        super.setUp()
        directory = uniqueTempDirectory()
        cache = LibraryCache(directory: directory)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    func testGamesRoundTrip() async {
        let games = [makeGame(id: 620, name: "Portal 2", unlocked: 3, total: 51,
                              minutes: 1338, lastPlayed: day(2026, 7, 1))]
        await cache.storeGames(games)
        let loaded = await cache.games()
        XCTAssertEqual(loaded?.count, 1)
        XCTAssertEqual(loaded?.first?.achievements?.total, 51)
        // Dates encode as epoch seconds — exact equality should survive.
        XCTAssertEqual(loaded?.first?.lastPlayed, day(2026, 7, 1))
    }

    func testAchievementsRoundTripAndHydratedIndex() async {
        let achievements = [Achievement(id: "A", displayName: "Alpha", isUnlocked: true,
                                        unlockedAt: day(2026, 6, 1), globalPercent: 12.5)]
        await cache.storeAchievements(achievements, appID: 620)

        let loaded = await cache.achievements(appID: 620)
        XCTAssertEqual(loaded, achievements)
        let hydrated = await cache.hydratedAppIDs()
        XCTAssertEqual(hydrated, [620])
        let missing = await cache.achievements(appID: 999)
        XCTAssertNil(missing)

        // Empty lists (games without achievements) stay out of the unlock feed.
        await cache.storeAchievements([], appID: 777)
        let all = await cache.allAchievements()
        XCTAssertEqual(all.keys.sorted(), [620])
        XCTAssertEqual(all[620], achievements)
    }

    func testClearRemovesEverything() async {
        await cache.storeGames([makeGame()])
        await cache.clear()
        let games = await cache.games()
        XCTAssertNil(games)
        let hydrated = await cache.hydratedAppIDs()
        XCTAssertTrue(hydrated.isEmpty)
    }
}

final class SyncPlannerTests: XCTestCase {
    func testOnlyPlayedGamesAreHydrated() {
        let fresh = [
            makeGame(id: 1, minutes: 100, lastPlayed: day(2026, 7, 1)),
            makeGame(id: 2, minutes: 0),
        ]
        let plan = SyncPlanner.appsNeedingHydration(fresh: fresh, cached: [], hydratedApps: [])
        XCTAssertEqual(plan, [1])
    }

    func testUnchangedHydratedGamesAreSkipped() {
        let game = makeGame(id: 1, minutes: 100, lastPlayed: day(2026, 7, 1))
        let plan = SyncPlanner.appsNeedingHydration(
            fresh: [game], cached: [game], hydratedApps: [1]
        )
        XCTAssertTrue(plan.isEmpty)
    }

    func testChangedPlaytimeTriggersRehydration() {
        let cached = makeGame(id: 1, minutes: 100, lastPlayed: day(2026, 7, 1))
        let fresh = makeGame(id: 1, minutes: 160, lastPlayed: day(2026, 7, 2))
        let plan = SyncPlanner.appsNeedingHydration(
            fresh: [fresh], cached: [cached], hydratedApps: [1]
        )
        XCTAssertEqual(plan, [1])
    }

    func testPlanOrdersMostRecentlyPlayedFirst() {
        let fresh = [
            makeGame(id: 1, minutes: 50, lastPlayed: day(2026, 1, 1)),
            makeGame(id: 2, minutes: 50, lastPlayed: day(2026, 7, 2)),
            makeGame(id: 3, minutes: 50, lastPlayed: day(2026, 6, 1)),
        ]
        let plan = SyncPlanner.appsNeedingHydration(fresh: fresh, cached: [], hydratedApps: [])
        XCTAssertEqual(plan, [2, 3, 1])
    }

    func testMergingCachedProgressNeverOverwritesFreshData() {
        let cached = [makeGame(id: 1, unlocked: 3, total: 10)]
        let freshWithProgress = [makeGame(id: 1, unlocked: 5, total: 10)]
        let freshWithout = [makeGame(id: 1)]

        XCTAssertEqual(
            SyncPlanner.mergingCachedProgress(fresh: freshWithProgress, cached: cached)
                .first?.achievements?.unlocked,
            5
        )
        XCTAssertEqual(
            SyncPlanner.mergingCachedProgress(fresh: freshWithout, cached: cached)
                .first?.achievements?.unlocked,
            3
        )
    }
}
