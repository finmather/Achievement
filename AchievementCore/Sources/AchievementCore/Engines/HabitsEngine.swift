import Foundation

/// When the player actually plays — derived entirely from unlock timestamps,
/// so it costs no extra API calls.
public struct GamingHabits: Hashable, Sendable {
    /// Localized weekday name with the most unlocks, e.g. "Saturday".
    public let favoriteWeekday: String?
    /// Share of all unlocks landing on that weekday (0...1).
    public let favoriteWeekdayShare: Double
    /// Share of unlocks between 21:00 and 04:59 (0...1).
    public let nightOwlShare: Double
    public let busiestMonth: Date?
    public let busiestMonthCount: Int

    public static let empty = GamingHabits(
        favoriteWeekday: nil, favoriteWeekdayShare: 0,
        nightOwlShare: 0, busiestMonth: nil, busiestMonthCount: 0
    )

    public init(
        favoriteWeekday: String?, favoriteWeekdayShare: Double,
        nightOwlShare: Double, busiestMonth: Date?, busiestMonthCount: Int
    ) {
        self.favoriteWeekday = favoriteWeekday
        self.favoriteWeekdayShare = favoriteWeekdayShare
        self.nightOwlShare = nightOwlShare
        self.busiestMonth = busiestMonth
        self.busiestMonthCount = busiestMonthCount
    }
}

/// One year of achievement hunting, summarized for the profile passport.
public struct YearSummary: Hashable, Sendable {
    public let year: Int
    public let unlockCount: Int
    /// Distinct games with at least one unlock this year.
    public let gamesTouched: Int
    /// Perfect games whose final achievement landed this year.
    public let newPerfectGames: Int
    /// The rarest achievement unlocked this year.
    public let rarest: UnlockEvent?
    /// Longest consecutive-day unlock run within the year.
    public let longestStreak: Int

    public init(
        year: Int, unlockCount: Int, gamesTouched: Int,
        newPerfectGames: Int, rarest: UnlockEvent?, longestStreak: Int
    ) {
        self.year = year
        self.unlockCount = unlockCount
        self.gamesTouched = gamesTouched
        self.newPerfectGames = newPerfectGames
        self.rarest = rarest
        self.longestStreak = longestStreak
    }
}

public enum HabitsEngine {
    public static func habits(
        unlockDates: [Date],
        calendar: Calendar = .current
    ) -> GamingHabits {
        guard !unlockDates.isEmpty else { return .empty }

        var weekdayCounts: [Int: Int] = [:]
        var monthCounts: [Date: Int] = [:]
        var nightOwl = 0

        for date in unlockDates {
            weekdayCounts[calendar.component(.weekday, from: date), default: 0] += 1
            let hour = calendar.component(.hour, from: date)
            if hour >= 21 || hour < 5 { nightOwl += 1 }
            if let month = calendar.dateInterval(of: .month, for: date)?.start {
                monthCounts[month, default: 0] += 1
            }
        }

        let total = Double(unlockDates.count)
        // Ties break on the earlier weekday so results are deterministic.
        let topWeekday = weekdayCounts.max {
            ($0.value, $1.key) < ($1.value, $0.key)
        }
        let topMonth = monthCounts.max {
            ($0.value, $1.key.timeIntervalSince1970)
                < ($1.value, $0.key.timeIntervalSince1970)
        }

        return GamingHabits(
            favoriteWeekday: topWeekday.map { calendar.weekdaySymbols[$0.key - 1] },
            favoriteWeekdayShare: topWeekday.map { Double($0.value) / total } ?? 0,
            nightOwlShare: Double(nightOwl) / total,
            busiestMonth: topMonth?.key,
            busiestMonthCount: topMonth?.value ?? 0
        )
    }

    public static func yearSummary(
        year: Int,
        unlocks: [UnlockEvent],
        games: [Game],
        calendar: Calendar = .current
    ) -> YearSummary {
        let inYear = unlocks.filter {
            calendar.component(.year, from: $0.unlockedAt) == year
        }

        // A perfect game "belongs" to the year its final unlock landed in.
        var lastUnlockByApp: [Int: Date] = [:]
        for unlock in unlocks {
            lastUnlockByApp[unlock.gameAppID] = max(
                lastUnlockByApp[unlock.gameAppID] ?? .distantPast, unlock.unlockedAt
            )
        }
        let newPerfects = games.filter { game in
            guard game.isPerfect, let last = lastUnlockByApp[game.appID] else { return false }
            return calendar.component(.year, from: last) == year
        }.count

        let rarest = inYear
            .filter { $0.achievement.globalPercent != nil }
            .min { ($0.achievement.globalPercent ?? 100) < ($1.achievement.globalPercent ?? 100) }

        return YearSummary(
            year: year,
            unlockCount: inYear.count,
            gamesTouched: Set(inYear.map(\.gameAppID)).count,
            newPerfectGames: newPerfects,
            rarest: rarest,
            longestStreak: longestRun(
                days: inYear.map { calendar.startOfDay(for: $0.unlockedAt) },
                calendar: calendar
            )
        )
    }

    private static func longestRun(days: [Date], calendar: Calendar) -> Int {
        let sorted = Set(days).sorted()
        guard !sorted.isEmpty else { return 0 }
        var longest = 1
        var run = 1
        for (previous, current) in zip(sorted, sorted.dropFirst()) {
            if let next = calendar.date(byAdding: .day, value: 1, to: previous),
               calendar.isDate(next, inSameDayAs: current) {
                run += 1
                longest = max(longest, run)
            } else {
                run = 1
            }
        }
        return longest
    }
}
