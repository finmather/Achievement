import Foundation

/// Unlock count for one calendar month — one bar/point in the profile chart.
public struct MonthlyUnlocks: Identifiable, Hashable, Sendable {
    public let month: Date
    public let count: Int

    public var id: Date { month }

    public init(month: Date, count: Int) {
        self.month = month
        self.count = count
    }
}

public enum HistoryEngine {
    /// Buckets unlock dates into calendar months over the trailing window,
    /// including empty months so charts keep a continuous axis.
    public static func monthlyUnlocks(
        dates: [Date],
        monthsBack: Int = 12,
        calendar: Calendar = .current,
        now: Date = .now
    ) -> [MonthlyUnlocks] {
        guard monthsBack > 0 else { return [] }

        let currentMonth = calendar.dateInterval(of: .month, for: now)?.start
            ?? calendar.startOfDay(for: now)
        let months: [Date] = (0..<monthsBack).reversed().compactMap {
            calendar.date(byAdding: .month, value: -$0, to: currentMonth)
        }
        guard let windowStart = months.first else { return [] }

        var counts: [Date: Int] = [:]
        for date in dates where date >= windowStart && date <= now {
            if let month = calendar.dateInterval(of: .month, for: date)?.start {
                counts[month, default: 0] += 1
            }
        }

        return months.map { MonthlyUnlocks(month: $0, count: counts[$0] ?? 0) }
    }
}
