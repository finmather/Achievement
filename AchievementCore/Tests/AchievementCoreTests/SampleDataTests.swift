import XCTest
@testable import AchievementCore

final class SampleDataTests: XCTestCase {
    private let now = day(2026, 7, 3)

    func testGameProgressMatchesGeneratedAchievements() {
        for game in SampleData.games(now: now) {
            let achievements = SampleData.achievements(appID: game.appID, now: now)
            if let progress = game.achievements {
                XCTAssertEqual(achievements.count, progress.total, game.name)
                XCTAssertEqual(
                    achievements.filter(\.isUnlocked).count, progress.unlocked, game.name
                )
            } else {
                XCTAssertTrue(achievements.isEmpty, game.name)
            }
        }
    }

    func testGenerationIsDeterministic() {
        XCTAssertEqual(
            SampleData.achievements(appID: 1145360, now: now),
            SampleData.achievements(appID: 1145360, now: now)
        )
        XCTAssertEqual(SampleData.games(now: now), SampleData.games(now: now))
    }

    func testUnlockedAchievementsAllCarryDatesInThePast() {
        for game in SampleData.games(now: now) {
            for achievement in SampleData.achievements(appID: game.appID, now: now) {
                if achievement.isUnlocked {
                    let date = achievement.unlockedAt
                    XCTAssertNotNil(date)
                    XCTAssertLessThanOrEqual(date!, now)
                } else {
                    XCTAssertNil(achievement.unlockedAt)
                }
            }
        }
    }

    func testAllUnlocksSortedNewestFirstAndFeedALiveStreak() {
        let unlocks = SampleData.allUnlocks(now: now)
        XCTAssertEqual(unlocks.map(\.unlockedAt), unlocks.map(\.unlockedAt).sorted(by: >))

        let streak = StreakEngine.summary(
            unlockDates: unlocks.map(\.unlockedAt), calendar: utcCalendar, today: now
        )
        XCTAssertGreaterThanOrEqual(streak.current, 5, "demo dashboard should show a streak")
        XCTAssertTrue(streak.unlockedToday)
    }

    func testDemoLibraryShowsRangeOfCompletionStates() {
        let stats = StatsEngine.stats(for: SampleData.games(now: now))
        XCTAssertGreaterThanOrEqual(stats.perfectGames, 3)
        XCTAssertGreaterThan(stats.overallCompletion, 0.3)
        XCTAssertLessThan(stats.overallCompletion, 0.95)
    }

    func testFriendLibrariesOverlapWithPlausibleProgress() {
        let myApps = Set(SampleData.games(now: now).map(\.appID))
        for friend in SampleData.friends {
            let games = SampleData.friendGames(friendID: friend.id, now: now)
            XCTAssertFalse(games.isEmpty, friend.personaName)
            for game in games {
                XCTAssertTrue(myApps.contains(game.appID))
                if let progress = game.achievements {
                    XCTAssertLessThanOrEqual(progress.unlocked, progress.total)
                }
            }
        }
    }

    func testRarityTiersSpanTheSpectrumOnLargeLists() {
        let achievements = SampleData.achievements(appID: 105600, now: now) // 88 achievements
        let tiers = Set(achievements.compactMap(\.rarity))
        XCTAssertTrue(tiers.contains(.common))
        XCTAssertTrue(tiers.contains(.legendary))
    }
}

final class ModelCodableTests: XCTestCase {
    func testSteamIDDecodesFromStringAndNumber() throws {
        let decoder = JSONDecoder()
        let fromString = try decoder.decode(
            SteamID.self, from: Data("\"76561197984231774\"".utf8)
        )
        let fromNumber = try decoder.decode(
            SteamID.self, from: Data("76561197984231774".utf8)
        )
        XCTAssertEqual(fromString, fromNumber)
        XCTAssertThrowsError(
            try decoder.decode(SteamID.self, from: Data("\"not-an-id\"".utf8))
        )
        XCTAssertThrowsError(
            try decoder.decode(SteamID.self, from: Data("42".utf8)),
            "IDs below the individual-account base must be rejected"
        )
    }

    func testSteamIDRejectsOutOfRangeInMemberwiseInit() {
        XCTAssertNil(SteamID(rawValue: 42))
        XCTAssertNil(SteamID(string: "abc"))
        XCTAssertNotNil(SteamID(string: " 76561197984231774 "))
    }

    func testArtworkURLs() {
        let art = SteamArtwork(appID: 620, iconHash: "abc123")
        XCTAssertEqual(
            art.portrait.absoluteString,
            "https://cdn.cloudflare.steamstatic.com/steam/apps/620/library_600x900_2x.jpg"
        )
        XCTAssertEqual(
            art.icon?.absoluteString,
            "https://media.steampowered.com/steamcommunity/public/images/apps/620/abc123.jpg"
        )
        XCTAssertNil(SteamArtwork(appID: 620).icon)
    }

    func testAchievementProgressClampsNegativeInput() {
        let progress = AchievementProgress(unlocked: -2, total: -5)
        XCTAssertEqual(progress.unlocked, 0)
        XCTAssertEqual(progress.fraction, 0)
        XCTAssertFalse(progress.isPerfect)
    }
}
