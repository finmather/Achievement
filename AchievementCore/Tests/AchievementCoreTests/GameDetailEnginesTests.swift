import XCTest
@testable import AchievementCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class CompletionEstimatorTests: XCTestCase {
    private func achievement(_ id: String, unlocked: Bool, percent: Double?) -> Achievement {
        Achievement(id: id, displayName: id, isUnlocked: unlocked, globalPercent: percent)
    }

    func testEstimateScalesPaceByRarity() throws {
        // 10 hours, 5 unlocked → pace 2h per unlock.
        let game = makeGame(id: 1, unlocked: 5, total: 7, minutes: 600)
        let achievements = [
            achievement("common", unlocked: false, percent: 50),  // factor 1 → 2h
            achievement("rare", unlocked: false, percent: 2),     // factor 5 → 10h
        ]
        let estimate = try XCTUnwrap(
            CompletionEstimator.hoursToComplete(game: game, achievements: achievements)
        )
        XCTAssertEqual(estimate, 12, accuracy: 0.01)
    }

    func testRarityFactorClampsAndDefaults() {
        XCTAssertEqual(CompletionEstimator.rarityFactor(50), 1, accuracy: 0.001)
        XCTAssertEqual(CompletionEstimator.rarityFactor(0.1), 6, "ultra-rare clamps high")
        XCTAssertEqual(CompletionEstimator.rarityFactor(100), 0.8, accuracy: 0.001,
                       "gimme achievements clamp low")
        XCTAssertEqual(CompletionEstimator.rarityFactor(nil), (50.0 / 25).squareRoot(),
                       accuracy: 0.001, "unknown rarity assumes 25%")
    }

    func testNoEstimateWithoutObservedPace() {
        let unplayed = makeGame(id: 1, unlocked: 0, total: 10, minutes: 0)
        let noUnlocks = makeGame(id: 2, unlocked: 0, total: 10, minutes: 300)
        let perfect = makeGame(id: 3, unlocked: 10, total: 10, minutes: 300)
        let locked = [achievement("a", unlocked: false, percent: 40)]

        XCTAssertNil(CompletionEstimator.hoursToComplete(game: unplayed, achievements: locked))
        XCTAssertNil(CompletionEstimator.hoursToComplete(game: noUnlocks, achievements: locked))
        XCTAssertNil(CompletionEstimator.hoursToComplete(game: perfect, achievements: []))
    }
}

final class SimilarGamesTests: XCTestCase {
    private let base = makeGame(id: 1, name: "Base", minutes: 100)

    func testExactTagMatchesOutrankAxisOnlyMatches() {
        let library = [
            base,
            makeGame(id: 2, name: "Exact", minutes: 100),
            makeGame(id: 3, name: "AxisOnly", minutes: 100),
            makeGame(id: 4, name: "Unrelated", minutes: 100),
        ]
        let tags = [
            1: ["Roguelike", "Action"],
            2: ["Roguelike", "Platformer"],   // shares raw tag (rank 0 → +3) + axis
            3: ["Roguelite"],                 // same axis, no raw tag → +0.75
            4: ["Farming Sim"],
        ]
        let similar = SimilarGames.similar(to: base, in: library, tagsByApp: tags)
        XCTAssertEqual(similar.map(\.name), ["Exact", "AxisOnly"])
    }

    func testExcludesSelfRespectsLimitAndNeedsBaseTags() {
        let library = (1...8).map { makeGame(id: $0, name: "G\($0)", minutes: 10) }
        var tags: [Int: [String]] = [:]
        for id in 1...8 { tags[id] = ["Puzzle"] }

        let similar = SimilarGames.similar(to: library[0], in: library, tagsByApp: tags)
        XCTAssertEqual(similar.count, 4)
        XCTAssertFalse(similar.contains { $0.appID == 1 })

        XCTAssertTrue(
            SimilarGames.similar(to: library[0], in: library, tagsByApp: [2: ["Puzzle"]]).isEmpty,
            "no tags on the reference game means no recommendations"
        )
    }

    func testSampleDataYieldsNeighborsForHades() {
        let games = SampleData.games(now: day(2026, 7, 3))
        let hades = games.first { $0.appID == 1_145_360 }!
        let similar = SimilarGames.similar(
            to: hades, in: games, tagsByApp: SampleData.genreTags
        )
        XCTAssertFalse(similar.isEmpty)
        XCTAssertFalse(similar.contains { $0.appID == hades.appID })
        XCTAssertLessThanOrEqual(similar.count, 4)
    }
}

final class GameInsightsTests: XCTestCase {
    func testInsightsSurfaceEasiestRarestAndPace() throws {
        let game = makeGame(id: 1, unlocked: 2, total: 6, minutes: 240) // 4 hrs
        let achievements = [
            Achievement(id: "e1", displayName: "e1", isUnlocked: false, globalPercent: 60),
            Achievement(id: "e2", displayName: "e2", isUnlocked: false, globalPercent: 45),
            Achievement(id: "hidden", displayName: "h", isHidden: true,
                        isUnlocked: false, globalPercent: 70),
            Achievement(id: "hard", displayName: "hard", isUnlocked: false, globalPercent: 2),
            Achievement(id: "u1", displayName: "u1", isUnlocked: true,
                        unlockedAt: day(2026, 6, 1), globalPercent: 30),
            Achievement(id: "u2", displayName: "u2", isUnlocked: true,
                        unlockedAt: day(2026, 7, 1), globalPercent: 1.5),
        ]
        let insights = GameInsightsEngine.insights(game: game, achievements: achievements)

        XCTAssertEqual(insights.easiestRemaining.map(\.id), ["e1", "e2", "hard"],
                       "hidden achievements never appear as suggestions")
        XCTAssertEqual(insights.rarestEarned?.id, "u2")
        XCTAssertEqual(try XCTUnwrap(insights.unlockPace), 0.5, accuracy: 0.001)
        XCTAssertEqual(insights.firstUnlock, day(2026, 6, 1))
        XCTAssertEqual(insights.latestUnlock, day(2026, 7, 1))
        XCTAssertFalse(insights.isEmpty)
    }

    func testEmptyInsightsForUntouchedGame() {
        let game = makeGame(id: 1, minutes: 0)
        let insights = GameInsightsEngine.insights(game: game, achievements: [])
        XCTAssertTrue(insights.isEmpty)
    }
}

final class StoreClientTests: XCTestCase {
    func testMetaDecodesStorePayload() async throws {
        let body = """
        {"1145360":{"success":true,"data":{
            "developers":["Supergiant Games"],
            "publishers":["Supergiant Games"],
            "genres":[{"id":"1","description":"Action"},{"id":"23","description":"Indie"}],
            "release_date":{"coming_soon":false,"date":"17 Sep, 2020"},
            "short_description":"Defy the god of the dead."
        }}}
        """
        let http = MockHTTPClient { request in
            XCTAssertEqual(request.url?.host, "store.steampowered.com")
            XCTAssertEqual(queryItems(of: request)["appids"], "1145360")
            return (Data(body.utf8), 200)
        }
        let meta = try await StoreClient(httpClient: http).meta(appID: 1_145_360)

        XCTAssertEqual(meta.developers, ["Supergiant Games"])
        XCTAssertEqual(meta.genres, ["Action", "Indie"])
        XCTAssertEqual(meta.releaseDate, "17 Sep, 2020")
        XCTAssertEqual(meta.byline, "Supergiant Games · 2020")
    }

    func testDelistedAppYieldsEmptyCacheableMeta() async throws {
        let http = MockHTTPClient { _ in
            (Data("{\"999\":{\"success\":false}}".utf8), 200)
        }
        let meta = try await StoreClient(httpClient: http).meta(appID: 999)
        XCTAssertTrue(meta.isEmpty)
    }

    func testBylineJoinsDistinctDeveloperPublisherAndYear() {
        let distinct = GameMeta(
            developers: ["FromSoftware"], publishers: ["Bandai Namco"],
            releaseDate: "24 Feb, 2022"
        )
        XCTAssertEqual(distinct.byline, "FromSoftware · Bandai Namco · 2022")

        let selfPublished = GameMeta(
            developers: ["Valve"], publishers: ["Valve"], releaseDate: "18 Apr, 2011"
        )
        XCTAssertEqual(selfPublished.byline, "Valve · 2011")
        XCTAssertNil(GameMeta().byline)
    }

    func testMetaCacheRoundTrip() async {
        let directory = uniqueTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = LibraryCache(directory: directory)

        let missing = await cache.gameMeta(appID: 620)
        XCTAssertNil(missing)

        await cache.storeGameMeta(GameMeta(developers: ["Valve"]), appID: 620)
        let loaded = await cache.gameMeta(appID: 620)
        XCTAssertEqual(loaded?.developers, ["Valve"])

        await cache.storeGameMeta(GameMeta(), appID: 777)
        let empty = await cache.gameMeta(appID: 777)
        XCTAssertEqual(empty?.isEmpty, true, "empty meta persists to stop refetching")
    }

    func testSampleMetaCoversEveryDemoGame() {
        for game in SampleData.games(now: day(2026, 7, 3)) {
            let meta = SampleData.gameMeta[game.appID]
            XCTAssertNotNil(meta, game.name)
            XCTAssertNotNil(meta?.byline, game.name)
            XCTAssertFalse(meta?.genres.isEmpty ?? true, game.name)
        }
    }
}
