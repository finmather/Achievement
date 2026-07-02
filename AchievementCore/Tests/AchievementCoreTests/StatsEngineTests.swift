import XCTest
@testable import AchievementCore

final class StatsEngineTests: XCTestCase {
    func testEmptyLibraryProducesZeroesNotNaN() {
        let stats = StatsEngine.stats(for: [])
        XCTAssertEqual(stats, .empty)
        XCTAssertFalse(stats.overallCompletion.isNaN)
        XCTAssertFalse(stats.averageCompletion.isNaN)
    }

    func testMixedLibraryAggregation() {
        let games = [
            makeGame(id: 1, unlocked: 10, total: 20, minutes: 600),
            makeGame(id: 2, unlocked: 5, total: 5, minutes: 300),
            makeGame(id: 3, minutes: 0), // no achievements, never played
            makeGame(id: 4, unlocked: 0, total: 10, minutes: 100),
        ]
        let stats = StatsEngine.stats(for: games)

        XCTAssertEqual(stats.totalGames, 4)
        XCTAssertEqual(stats.playedGames, 3)
        XCTAssertEqual(stats.gamesWithAchievements, 3)
        XCTAssertEqual(stats.unlockedAchievements, 15)
        XCTAssertEqual(stats.totalAchievements, 35)
        XCTAssertEqual(stats.perfectGames, 1)
        XCTAssertEqual(stats.totalPlaytimeMinutes, 1000)
        XCTAssertEqual(stats.overallCompletion, 15.0 / 35.0, accuracy: 0.0001)
        XCTAssertEqual(stats.averageCompletion, 0.5, accuracy: 0.0001)
    }

    func testGameWithZeroTotalAchievementsIsNotCountedAsPerfect() {
        let games = [makeGame(id: 1, unlocked: 0, total: 0, minutes: 50)]
        let stats = StatsEngine.stats(for: games)
        XCTAssertEqual(stats.perfectGames, 0)
        XCTAssertEqual(stats.gamesWithAchievements, 0)
    }
}

final class RarityTests: XCTestCase {
    func testTierBoundaries() {
        XCTAssertEqual(Rarity(globalPercent: 0.5), .legendary)
        XCTAssertEqual(Rarity(globalPercent: 0.99), .legendary)
        XCTAssertEqual(Rarity(globalPercent: 1.0), .veryRare)
        XCTAssertEqual(Rarity(globalPercent: 4.99), .veryRare)
        XCTAssertEqual(Rarity(globalPercent: 5.0), .rare)
        XCTAssertEqual(Rarity(globalPercent: 19.99), .rare)
        XCTAssertEqual(Rarity(globalPercent: 20.0), .uncommon)
        XCTAssertEqual(Rarity(globalPercent: 49.99), .uncommon)
        XCTAssertEqual(Rarity(globalPercent: 50.0), .common)
        XCTAssertEqual(Rarity(globalPercent: 100.0), .common)
    }

    func testNegativePercentClampsToLegendary() {
        XCTAssertEqual(Rarity(globalPercent: -3), .legendary)
    }

    func testComparableOrdersCommonToLegendary() {
        XCTAssertLessThan(Rarity.common, .uncommon)
        XCTAssertLessThan(Rarity.uncommon, .rare)
        XCTAssertLessThan(Rarity.rare, .veryRare)
        XCTAssertLessThan(Rarity.veryRare, .legendary)
    }
}
