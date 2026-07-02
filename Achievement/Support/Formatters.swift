import Foundation
import AchievementCore

/// Display formatting rules, consistent app-wide.
enum Format {
    /// "0%" ... "100%" — whole numbers read faster than decimals on cards.
    static func percent(_ fraction: Double) -> String {
        "\(Int((fraction.clamped(to: 0...1) * 100).rounded()))%"
    }

    /// Playtime: "42 min" under an hour, "9.5 hrs" under ten, "1,204 hrs" above.
    static func hours(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let hours = Double(minutes) / 60
        if hours < 10 {
            return "\((hours * 10).rounded() / 10) hrs"
        }
        return "\(Int(hours.rounded()).formatted()) hrs"
    }

    /// Rarity as shown next to achievements: "3.4% of players".
    static func globalPercent(_ percent: Double) -> String {
        let value = percent < 10
            ? ((percent * 10).rounded() / 10).formatted()
            : "\(Int(percent.rounded()))"
        return "\(value)% of players"
    }

    /// Compact relative time for unlock rows ("2h ago", "yesterday").
    static func relative(_ date: Date, to now: Date = .now) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: now)
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
