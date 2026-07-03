import XCTest
@testable import AchievementCore

final class GenreEngineTests: XCTestCase {
    func testTagMappingIsCaseInsensitiveAndMultiAxis() {
        XCTAssertEqual(Set(GenreEngine.axes(forTag: "ROGUELIKE")), [.roguelike])
        XCTAssertEqual(Set(GenreEngine.axes(forTag: "Puzzle Platformer")), [.puzzle, .platformer])
        XCTAssertEqual(Set(GenreEngine.axes(forTag: "Roguelike Deckbuilder")), [.roguelike, .strategy])
        XCTAssertTrue(GenreEngine.axes(forTag: "Farming Sim").isEmpty)
    }

    func testStrongestAxisNormalizesToOne() {
        let games = [
            makeGame(id: 1, name: "Big RPG", unlocked: 30, total: 40, minutes: 6000),
            makeGame(id: 2, name: "Small Puzzle", unlocked: 5, total: 10, minutes: 120),
        ]
        let profile = GenreEngine.profile(
            games: games,
            tagsByApp: [1: ["RPG"], 2: ["Puzzle"]]
        )
        let rpg = profile.axes.first { $0.axis == .rpg }!
        let puzzle = profile.axes.first { $0.axis == .puzzle }!

        XCTAssertEqual(rpg.score, 1.0, accuracy: 0.0001)
        XCTAssertGreaterThan(puzzle.score, 0)
        XCTAssertLessThan(puzzle.score, 1)
        XCTAssertEqual(profile.strongest?.axis, .rpg)
    }

    func testUnplayedAndUntaggedGamesAreExcluded() {
        let games = [
            makeGame(id: 1, name: "Never Played", unlocked: 0, total: 10, minutes: 0),
            makeGame(id: 2, name: "No Tags", unlocked: 3, total: 10, minutes: 500),
            makeGame(id: 3, name: "Unmapped Tags", unlocked: 3, total: 10, minutes: 500),
        ]
        let profile = GenreEngine.profile(
            games: games,
            tagsByApp: [1: ["RPG"], 3: ["Sandbox", "Survival"]]
        )
        XCTAssertTrue(profile.isEmpty)
        XCTAssertNil(profile.strongest)
    }

    func testAxisStatsTrackHoursCountAndTopGame() {
        let games = [
            makeGame(id: 1, name: "Main", unlocked: 10, total: 20, minutes: 1200),
            makeGame(id: 2, name: "Side", unlocked: 2, total: 20, minutes: 300),
        ]
        let profile = GenreEngine.profile(
            games: games,
            tagsByApp: [1: ["Platformer"], 2: ["Metroidvania"]]
        )
        let platformer = profile.axes.first { $0.axis == .platformer }!

        XCTAssertEqual(platformer.gameCount, 2)
        XCTAssertEqual(platformer.hours, 25, accuracy: 0.001)
        XCTAssertEqual(platformer.topGame?.appID, 1)
    }

    func testProfileAlwaysCarriesAllSixAxesInStableOrder() {
        let profile = GenreEngine.profile(games: [], tagsByApp: [:])
        XCTAssertEqual(profile.axes.map(\.axis), GenreAxis.allCases)
    }

    func testSampleDataYieldsAFullHexagon() {
        let profile = GenreEngine.profile(
            games: SampleData.games(now: day(2026, 7, 3)),
            tagsByApp: SampleData.genreTags
        )
        for axis in profile.axes {
            XCTAssertGreaterThan(axis.score, 0, "\(axis.axis) should be non-zero in demo data")
        }
    }
}
