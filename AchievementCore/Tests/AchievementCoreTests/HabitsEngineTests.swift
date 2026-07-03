import XCTest
@testable import AchievementCore

final class HabitsEngineTests: XCTestCase {
    func testEmptyInputYieldsEmptyHabits() {
        XCTAssertEqual(HabitsEngine.habits(unlockDates: [], calendar: utcCalendar), .empty)
    }

    func testFavoriteWeekdayAndShare() {
        // 2026-07-03 is a Friday, 2026-07-04 a Saturday.
        let habits = HabitsEngine.habits(
            unlockDates: [day(2026, 7, 3, hour: 9), day(2026, 7, 3, hour: 20), day(2026, 7, 4)],
            calendar: utcCalendar
        )
        XCTAssertEqual(habits.favoriteWeekday, "Friday")
        XCTAssertEqual(habits.favoriteWeekdayShare, 2.0 / 3.0, accuracy: 0.0001)
    }

    func testNightOwlShareCountsLateAndEarlyHours() {
        let habits = HabitsEngine.habits(
            unlockDates: [
                day(2026, 7, 1, hour: 23), day(2026, 7, 2, hour: 2),
                day(2026, 7, 3, hour: 14), day(2026, 7, 4, hour: 20),
            ],
            calendar: utcCalendar
        )
        XCTAssertEqual(habits.nightOwlShare, 0.5, accuracy: 0.0001)
    }

    func testBusiestMonth() {
        let habits = HabitsEngine.habits(
            unlockDates: [day(2026, 6, 10), day(2026, 6, 20), day(2026, 7, 1)],
            calendar: utcCalendar
        )
        XCTAssertEqual(habits.busiestMonth, day(2026, 6, 1, hour: 0))
        XCTAssertEqual(habits.busiestMonthCount, 2)
    }

    func testYearSummary() {
        func unlock(_ id: String, game: Int, name: String, date: Date, percent: Double?) -> UnlockEvent {
            UnlockEvent(
                gameAppID: game, gameName: name,
                achievement: Achievement(
                    id: id, displayName: id, isUnlocked: true,
                    unlockedAt: date, globalPercent: percent
                ),
                unlockedAt: date
            )
        }

        let unlocks = [
            // 2026: three consecutive days across two games.
            unlock("A", game: 1, name: "Perfected Now", date: day(2026, 7, 1), percent: 40),
            unlock("B", game: 1, name: "Perfected Now", date: day(2026, 7, 2), percent: 1.2),
            unlock("C", game: 2, name: "Other", date: day(2026, 7, 3), percent: nil),
            // 2025: history that must stay out of the 2026 summary.
            unlock("D", game: 3, name: "Perfected Long Ago", date: day(2025, 3, 10), percent: 0.4),
        ]
        let games = [
            makeGame(id: 1, name: "Perfected Now", unlocked: 10, total: 10, minutes: 600),
            makeGame(id: 2, name: "Other", unlocked: 4, total: 20, minutes: 300),
            makeGame(id: 3, name: "Perfected Long Ago", unlocked: 5, total: 5, minutes: 900),
        ]

        let summary = HabitsEngine.yearSummary(
            year: 2026, unlocks: unlocks, games: games, calendar: utcCalendar
        )

        XCTAssertEqual(summary.unlockCount, 3)
        XCTAssertEqual(summary.gamesTouched, 2)
        XCTAssertEqual(summary.newPerfectGames, 1, "game 3's perfect belongs to 2025")
        XCTAssertEqual(summary.rarest?.achievement.id, "B")
        XCTAssertEqual(summary.longestStreak, 3)
    }
}

final class MilestoneEngineTests: XCTestCase {
    private func stats(unlocked: Int) -> LibraryStats {
        var stats = LibraryStats.empty
        stats.unlockedAchievements = unlocked
        return stats
    }

    func testNearlyPerfectGameWinsAndPicksFewestRemaining() {
        let games = [
            makeGame(id: 1, name: "Close", unlocked: 8, total: 10, minutes: 100),
            makeGame(id: 2, name: "Closer", unlocked: 9, total: 10, minutes: 100),
            makeGame(id: 3, name: "Done", unlocked: 10, total: 10, minutes: 100),
        ]
        let milestone = MilestoneEngine.next(
            games: games, stats: stats(unlocked: 27),
            streak: StreakSummary(current: 4, longest: 5, unlockedToday: false)
        )
        guard case .perfectGame(let game, let remaining) = milestone else {
            return XCTFail("expected perfectGame, got \(String(describing: milestone))")
        }
        XCTAssertEqual(game.appID, 2)
        XCTAssertEqual(remaining, 1)
    }

    func testGamesBelowSeventyPercentDoNotQualify() {
        let games = [makeGame(id: 1, name: "Early", unlocked: 6, total: 10, minutes: 100)]
        let milestone = MilestoneEngine.next(
            games: games, stats: stats(unlocked: 6), streak: .none
        )
        guard case .unlockCount(let target, let remaining) = milestone else {
            return XCTFail("expected unlockCount, got \(String(describing: milestone))")
        }
        XCTAssertEqual(target, 50)
        XCTAssertEqual(remaining, 44)
    }

    func testStreakRecordWithinReachBeatsUnlockCount() {
        let milestone = MilestoneEngine.next(
            games: [], stats: stats(unlocked: 500),
            streak: StreakSummary(current: 4, longest: 5, unlockedToday: true)
        )
        guard case .streakRecord(let record, let remaining) = milestone else {
            return XCTFail("expected streakRecord, got \(String(describing: milestone))")
        }
        XCTAssertEqual(record, 5)
        XCTAssertEqual(remaining, 2, "one day to tie, one more to beat")
    }

    func testExactRoundNumberRollsToNextTarget() {
        let milestone = MilestoneEngine.next(games: [], stats: stats(unlocked: 100), streak: .none)
        guard case .unlockCount(let target, let remaining) = milestone else {
            return XCTFail("expected unlockCount, got \(String(describing: milestone))")
        }
        XCTAssertEqual(target, 150)
        XCTAssertEqual(remaining, 50)
    }

    func testNothingToChaseYieldsNil() {
        XCTAssertNil(MilestoneEngine.next(games: [], stats: .empty, streak: .none))
    }
}
