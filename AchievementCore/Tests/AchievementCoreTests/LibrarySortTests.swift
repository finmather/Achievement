import XCTest
@testable import AchievementCore

final class LibrarySortTests: XCTestCase {
    func testAlphabeticalIsCaseInsensitive() {
        let games = [
            makeGame(id: 1, name: "banana"),
            makeGame(id: 2, name: "Apple"),
            makeGame(id: 3, name: "cherry"),
        ]
        let sorted = LibraryFilter.sorted(games, by: .alphabetical)
        XCTAssertEqual(sorted.map(\.name), ["Apple", "banana", "cherry"])
    }

    func testHoursPlayedDescendingWithNameTiebreak() {
        let games = [
            makeGame(id: 1, name: "Beta", minutes: 100),
            makeGame(id: 2, name: "Alpha", minutes: 100),
            makeGame(id: 3, name: "Gamma", minutes: 500),
        ]
        let sorted = LibraryFilter.sorted(games, by: .hoursPlayed)
        XCTAssertEqual(sorted.map(\.name), ["Gamma", "Alpha", "Beta"])
    }

    func testRecentlyPlayedPutsNeverPlayedLast() {
        let games = [
            makeGame(id: 1, name: "Old", lastPlayed: day(2026, 1, 1)),
            makeGame(id: 2, name: "Never", minutes: 900),
            makeGame(id: 3, name: "New", lastPlayed: day(2026, 7, 1)),
        ]
        let sorted = LibraryFilter.sorted(games, by: .recentlyPlayed)
        XCTAssertEqual(sorted.map(\.name), ["New", "Old", "Never"])
    }

    func testCompletionSortsSinkGamesWithoutAchievements() {
        let games = [
            makeGame(id: 1, name: "Half", unlocked: 5, total: 10),
            makeGame(id: 2, name: "NoAch", minutes: 2000),
            makeGame(id: 3, name: "Done", unlocked: 10, total: 10),
            makeGame(id: 4, name: "Fresh", unlocked: 0, total: 10),
        ]
        let most = LibraryFilter.sorted(games, by: .mostCompleted)
        XCTAssertEqual(most.map(\.name), ["Done", "Half", "Fresh", "NoAch"])

        let least = LibraryFilter.sorted(games, by: .leastCompleted)
        XCTAssertEqual(least.map(\.name), ["Fresh", "Half", "Done", "NoAch"])
    }

    func testEqualFractionsTiebreakOnUnlockedCount() {
        let games = [
            makeGame(id: 1, name: "Small", unlocked: 1, total: 2),
            makeGame(id: 2, name: "Big", unlocked: 50, total: 100),
        ]
        let most = LibraryFilter.sorted(games, by: .mostCompleted)
        XCTAssertEqual(most.map(\.name), ["Big", "Small"])
    }

    func testSearchRanksPrefixMatchesFirst() {
        let games = [
            makeGame(id: 1, name: "Teleport Masters", minutes: 9000),
            makeGame(id: 2, name: "Portal 2", minutes: 10),
        ]
        let results = LibraryFilter.apply(games, search: "port", sort: .hoursPlayed)
        XCTAssertEqual(results.map(\.name), ["Portal 2", "Teleport Masters"])
    }

    func testSearchIsDiacriticAndCaseInsensitive() {
        let games = [makeGame(id: 1, name: "Pokémon Snap")]
        let results = LibraryFilter.apply(games, search: "pokemon", sort: .alphabetical)
        XCTAssertEqual(results.count, 1)
    }

    func testBlankSearchReturnsEverythingSorted() {
        let games = [makeGame(id: 1, name: "B"), makeGame(id: 2, name: "A")]
        let results = LibraryFilter.apply(games, search: "   ", sort: .alphabetical)
        XCTAssertEqual(results.map(\.name), ["A", "B"])
    }

    func testNoMatchesReturnsEmpty() {
        let games = [makeGame(id: 1, name: "Celeste")]
        XCTAssertTrue(LibraryFilter.apply(games, search: "zzz", sort: .alphabetical).isEmpty)
    }
}

final class ComparisonEngineTests: XCTestCase {
    func testSharedGamesIntersectionAndOrdering() {
        let mine = [
            makeGame(id: 1, name: "Shared Low", unlocked: 2, total: 10, minutes: 60),
            makeGame(id: 2, name: "Only Mine", unlocked: 1, total: 5, minutes: 999),
            makeGame(id: 3, name: "Shared High", unlocked: 9, total: 10, minutes: 600),
        ]
        let theirs = [
            makeGame(id: 1, name: "Shared Low", unlocked: 8, total: 10, minutes: 120),
            makeGame(id: 3, name: "Shared High", unlocked: 3, total: 10, minutes: 700),
            makeGame(id: 4, name: "Only Theirs", minutes: 50),
        ]

        let comparison = ComparisonEngine.compare(myGames: mine, friendGames: theirs)

        XCTAssertEqual(comparison.sharedGameCount, 2)
        // Ordered by combined playtime: Shared High (1300) before Shared Low (180).
        XCTAssertEqual(comparison.sharedGames.map(\.game.appID), [3, 1])
        XCTAssertEqual(comparison.sharedGames[0].theirs?.unlocked, 3)
        XCTAssertEqual(comparison.myStats.totalGames, 3)
        XCTAssertEqual(comparison.friendStats.totalGames, 3)
    }

    func testNoOverlapProducesEmptySharedList() {
        let comparison = ComparisonEngine.compare(
            myGames: [makeGame(id: 1)],
            friendGames: [makeGame(id: 2)]
        )
        XCTAssertTrue(comparison.sharedGames.isEmpty)
    }
}
