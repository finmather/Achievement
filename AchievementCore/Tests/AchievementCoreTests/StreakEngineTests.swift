import XCTest
@testable import AchievementCore

final class StreakEngineTests: XCTestCase {
    private let today = day(2026, 7, 3)

    private func summary(_ dates: [Date]) -> StreakSummary {
        StreakEngine.summary(unlockDates: dates, calendar: utcCalendar, today: today)
    }

    func testNoUnlocksMeansNoStreak() {
        XCTAssertEqual(summary([]), .none)
    }

    func testSingleUnlockTodayStartsStreak() {
        let result = summary([day(2026, 7, 3, hour: 8)])
        XCTAssertEqual(result.current, 1)
        XCTAssertEqual(result.longest, 1)
        XCTAssertTrue(result.unlockedToday)
    }

    func testConsecutiveDaysEndingToday() {
        let result = summary([
            day(2026, 7, 1), day(2026, 7, 2), day(2026, 7, 3),
        ])
        XCTAssertEqual(result.current, 3)
        XCTAssertEqual(result.longest, 3)
        XCTAssertTrue(result.unlockedToday)
    }

    func testStreakSurvivesQuietTodayWhenYesterdayUnlocked() {
        let result = summary([day(2026, 7, 1), day(2026, 7, 2)])
        XCTAssertEqual(result.current, 2)
        XCTAssertFalse(result.unlockedToday)
    }

    func testStreakBrokenByTwoQuietDays() {
        let result = summary([day(2026, 6, 29), day(2026, 7, 1)])
        XCTAssertEqual(result.current, 0)
        XCTAssertEqual(result.longest, 1)
    }

    func testLongestStreakCanBeInThePast() {
        let result = summary([
            day(2026, 5, 10), day(2026, 5, 11), day(2026, 5, 12), day(2026, 5, 13),
            day(2026, 7, 3),
        ])
        XCTAssertEqual(result.current, 1)
        XCTAssertEqual(result.longest, 4)
    }

    func testMultipleUnlocksSameDayCountOnce() {
        let result = summary([
            day(2026, 7, 2, hour: 1), day(2026, 7, 2, hour: 9), day(2026, 7, 2, hour: 23),
            day(2026, 7, 3, hour: 5),
        ])
        XCTAssertEqual(result.current, 2)
        XCTAssertEqual(result.longest, 2)
    }
}

final class HistoryEngineTests: XCTestCase {
    private let now = day(2026, 7, 3)

    func testBucketsIncludeEmptyMonthsAndKeepOrder() {
        let history = HistoryEngine.monthlyUnlocks(
            dates: [
                day(2026, 6, 15), day(2026, 6, 20), day(2026, 7, 1),
                day(2026, 4, 30),          // before the 3-month window
                day(2026, 7, 10),          // in the future
            ],
            monthsBack: 3,
            calendar: utcCalendar,
            now: now
        )

        XCTAssertEqual(history.count, 3)
        XCTAssertEqual(history.map(\.count), [0, 2, 1]) // May, June, July
        XCTAssertEqual(
            history.map(\.month),
            [day(2026, 5, 1, hour: 0), day(2026, 6, 1, hour: 0), day(2026, 7, 1, hour: 0)]
        )
    }

    func testZeroMonthsBackIsEmpty() {
        XCTAssertTrue(
            HistoryEngine.monthlyUnlocks(
                dates: [now], monthsBack: 0, calendar: utcCalendar, now: now
            ).isEmpty
        )
    }
}
