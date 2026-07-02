import Foundation

/// Day-based unlock streaks: how many consecutive days (ending today or
/// yesterday) the player unlocked at least one achievement.
public struct StreakSummary: Hashable, Sendable, Codable {
    public var current: Int
    public var longest: Int
    /// Whether an unlock has already happened today (drives "keep it going"
    /// vs. "unlock one today to continue" messaging).
    public var unlockedToday: Bool

    public static let none = StreakSummary(current: 0, longest: 0, unlockedToday: false)

    public init(current: Int, longest: Int, unlockedToday: Bool) {
        self.current = current
        self.longest = longest
        self.unlockedToday = unlockedToday
    }
}

public enum StreakEngine {
    public static func summary(
        unlockDates: [Date],
        calendar: Calendar = .current,
        today: Date = .now
    ) -> StreakSummary {
        guard !unlockDates.isEmpty else { return .none }

        let days = Set(unlockDates.map { calendar.startOfDay(for: $0) })
        let sortedDays = days.sorted()

        // Longest run of consecutive days anywhere in history.
        var longest = 1
        var run = 1
        for (previous, current) in zip(sortedDays, sortedDays.dropFirst()) {
            if let next = calendar.date(byAdding: .day, value: 1, to: previous),
               calendar.isDate(next, inSameDayAs: current) {
                run += 1
                longest = max(longest, run)
            } else {
                run = 1
            }
        }

        // Current streak: walk backwards from today. A streak survives a
        // quiet "today" if yesterday had an unlock — it just isn't extended yet.
        let startOfToday = calendar.startOfDay(for: today)
        let unlockedToday = days.contains(startOfToday)
        var cursor = unlockedToday
            ? startOfToday
            : calendar.date(byAdding: .day, value: -1, to: startOfToday)!
        var current = 0
        while days.contains(cursor) {
            current += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }

        return StreakSummary(
            current: current,
            longest: max(longest, current),
            unlockedToday: unlockedToday
        )
    }
}
