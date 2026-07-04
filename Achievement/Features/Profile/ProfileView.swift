import SwiftUI
import Charts
import AchievementCore

/// The gaming passport: an animated identity header with passport-stamp
/// seals, the genre radar (the app's signature), editorial habit lines, a
/// year summary, an organic unlock-history chart, and the rarity gems.
struct ProfileView: View {
    @Environment(AppModel.self) private var appModel
    let home: HomeModel

    @State private var confirmingSignOut = false

    private var library: LibraryStore { home.library }

    var body: some View {
        ZStack {
            AmbientBackground(palette: .profile)

            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.sectionGap) {
                    IdentityHeader(profile: home.profile, isDemo: home.isDemo)
                        .frame(maxWidth: .infinity)
                        .entrance(0)

                    StampRow(stats: library.stats, profile: home.profile)
                        .entrance(1)

                    FloatingSection(title: "Your shape", index: 2) {
                        GenreRadarView(profile: library.genreProfile)
                    }

                    editorialStats.entrance(3)

                    if library.habits != .empty {
                        FloatingSection(title: "Habits", index: 4) {
                            HabitLines(habits: library.habits)
                        }
                    }

                    if library.yearSummary.unlockCount > 0 {
                        FloatingSection(title: "\(library.yearSummary.year) so far", index: 5) {
                            YearSummaryCapsule(summary: library.yearSummary)
                        }
                    }

                    if !library.unlocks.isEmpty {
                        FloatingSection(title: "Unlock history", index: 6) {
                            HistoryChart(unlocks: library.unlocks)
                        }

                        FloatingSection(title: "Rarity collection", index: 7) {
                            RarityGems(unlocks: library.unlocks)
                        }
                    }

                    footer.entrance(8)
                }
                .padding(.horizontal, Tokens.screenMargin)
                .padding(.bottom, 40)
            }
            .scrollClipDisabled()
        }
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog(
            home.isDemo ? "Leave the demo?" : "Sign out of Achievement?",
            isPresented: $confirmingSignOut,
            titleVisibility: .visible
        ) {
            Button(home.isDemo ? "Leave Demo" : "Sign Out", role: .destructive) {
                appModel.signOut()
            }
        } message: {
            Text(home.isDemo
                 ? "You can come back anytime."
                 : "Synced data on this device will be removed.")
        }
    }

    // MARK: - Editorial stats

    /// Two loose columns of oversized numbers — a spread, not a spreadsheet.
    private var editorialStats: some View {
        let stats = library.stats
        return HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 22) {
                EditorialStat(
                    value: Int(stats.totalHours.rounded()).formatted(),
                    label: "Hours played",
                    countsUp: Int(stats.totalHours.rounded())
                )
                EditorialStat(
                    value: "\(stats.perfectGames)",
                    label: "Perfect games",
                    countsUp: stats.perfectGames
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 22) {
                EditorialStat(
                    value: Format.percent(stats.averageCompletion),
                    label: "Avg completion"
                )
                EditorialStat(
                    value: stats.unlockedAchievements.formatted(),
                    label: "Achievements",
                    countsUp: stats.unlockedAchievements
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var footer: some View {
        VStack(spacing: 16) {
            Button(home.isDemo ? "Leave demo" : "Sign out") {
                confirmingSignOut = true
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .buttonStyle(.pressable)

            Text("Game data provided by Steam. Not affiliated with Valve.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
    }
}

// MARK: - Identity

private struct IdentityHeader: View {
    let profile: PlayerProfile?
    let isDemo: Bool

    var body: some View {
        VStack(spacing: 14) {
            if let profile {
                AvatarView(profile: profile, size: 88, showsAuroraRing: true)

                VStack(spacing: 4) {
                    Text(profile.personaName)
                        .font(.editorialTitle)
                    if let created = profile.accountCreatedAt {
                        Text("Hunting since \(created.formatted(.dateTime.year()))")
                            .capsLabel()
                    }
                }
            } else {
                BreathingPlaceholder(shape: .circle)
                    .frame(width: 88, height: 88)
                BreathingPlaceholder(shape: .capsule)
                    .frame(width: 150, height: 26)
            }

            if isDemo {
                Text("Demo")
                    .font(.caption2.weight(.bold))
                    .kerning(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Theme.accent.opacity(0.13)))
            }
        }
        .padding(.top, 20)
    }
}

/// Passport stamps: small circular seals for the trip so far.
private struct StampRow: View {
    let stats: LibraryStats
    let profile: PlayerProfile?

    var body: some View {
        HStack(spacing: 14) {
            Seal(symbol: "square.stack.fill", value: "\(stats.totalGames)", label: "Games")
            Seal(symbol: "crown.fill", value: "\(stats.perfectGames)", label: "Perfect",
                 tint: Theme.gold)
            Seal(symbol: "trophy.fill", value: compact(stats.unlockedAchievements),
                 label: "Unlocked")
            if let country = profile?.countryCode {
                Seal(symbol: nil, value: flag(for: country), label: "Base")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func compact(_ value: Int) -> String {
        value >= 10_000
            ? "\((Double(value) / 1000 * 10).rounded() / 10)k"
            : value.formatted()
    }

    private func flag(for countryCode: String) -> String {
        countryCode.uppercased().unicodeScalars.reduce(into: "") { result, scalar in
            if let flagScalar = UnicodeScalar(127_397 + scalar.value) {
                result.unicodeScalars.append(flagScalar)
            }
        }
    }
}

private struct Seal: View {
    let symbol: String?
    let value: String
    let label: String
    var tint: Color = Theme.accent

    var body: some View {
        VStack(spacing: 7) {
            VStack(spacing: 1) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 11))
                        .foregroundStyle(tint)
                }
                Text(value)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(width: 62, height: 62)
            .glassChip(.circle)

            Text(label).capsLabel()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct EditorialStat: View {
    let value: String
    let label: String
    /// Numeric stats count up on first appearance.
    var countsUp: Int? = nil

    private static let numberFont = Font.system(size: 36, weight: .bold, design: .rounded)

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let countsUp {
                CountUpText(value: countsUp, font: Self.numberFont)
                    .tracking(-0.5)
            } else {
                Text(value)
                    .font(Self.numberFont)
                    .tracking(-0.5)
                    .contentTransition(.numericText())
            }
            Text(label).capsLabel()
        }
    }
}

// MARK: - Habits

private struct HabitLines: View {
    let habits: GamingHabits

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let weekday = habits.favoriteWeekday {
                line(
                    symbol: "calendar",
                    text: "\(weekday)s are your day — \(Format.percent(habits.favoriteWeekdayShare)) of unlocks land there"
                )
            }
            line(
                symbol: habits.nightOwlShare >= 0.5 ? "moon.stars.fill" : "sun.max.fill",
                text: habits.nightOwlShare >= 0.5
                    ? "Night owl — \(Format.percent(habits.nightOwlShare)) of unlocks after dark"
                    : "Daylight hunter — \(Format.percent(1 - habits.nightOwlShare)) of unlocks before dusk"
            )
            if let month = habits.busiestMonth {
                line(
                    symbol: "flame.fill",
                    text: "Busiest month: \(month.formatted(.dateTime.month(.wide).year())) with \(habits.busiestMonthCount) unlocks"
                )
            }
        }
    }

    private func line(symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.footnote)
                .foregroundStyle(Theme.accentDuotone)
                .frame(width: 22)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Year summary

private struct YearSummaryCapsule: View {
    let summary: YearSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 0) {
                MiniStat(value: "\(summary.unlockCount)", label: "Unlocks")
                MiniStat(value: "\(summary.gamesTouched)", label: "Games")
                MiniStat(value: "\(summary.newPerfectGames)", label: "New perfects")
                MiniStat(value: "\(summary.longestStreak)", label: "Best streak")
            }

            if let rarest = summary.rarest,
               let percent = rarest.achievement.globalPercent {
                HStack(spacing: 12) {
                    AchievementIcon(achievement: rarest.achievement, size: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Rarest this year: \(rarest.achievement.displayName)")
                            .font(.footnote.weight(.semibold))
                            .lineLimit(1)
                        Text("\(rarest.gameName) · only \(Format.globalPercent(percent))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassChip(.blob(30))
    }

    private struct MiniStat: View {
        let value: String
        let label: String

        var body: some View {
            VStack(spacing: 3) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .textCase(.uppercase)
                    .kerning(0.8)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - History chart

private struct HistoryChart: View {
    let unlocks: [UnlockEvent]

    private var history: [MonthlyUnlocks] {
        HistoryEngine.monthlyUnlocks(dates: unlocks.map(\.unlockedAt))
    }

    var body: some View {
        Chart(history) { month in
            BarMark(
                x: .value("Month", month.month, unit: .month),
                y: .value("Unlocks", month.count),
                width: .ratio(0.55)
            )
            .foregroundStyle(Theme.accentDuotone)
            .cornerRadius(5)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month, count: 3)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated))
                    .font(.caption2)
            }
        }
        .chartYAxis(.hidden)
        .frame(height: 130)
    }
}

// MARK: - Rarity gems

/// One circle per rarity tier, sized by how many the player holds.
private struct RarityGems: View {
    let unlocks: [UnlockEvent]

    private var counts: [(rarity: Rarity, count: Int)] {
        let grouped = Dictionary(grouping: unlocks.compactMap(\.achievement.rarity)) { $0 }
        return Rarity.allCases.reversed().compactMap { rarity in
            guard let count = grouped[rarity]?.count, count > 0 else { return nil }
            return (rarity, count)
        }
    }

    var body: some View {
        let maxCount = Double(counts.map(\.count).max() ?? 1)
        HStack(alignment: .bottom, spacing: 18) {
            ForEach(counts, id: \.rarity) { entry in
                let scale = (Double(entry.count) / maxCount).squareRoot()
                VStack(spacing: 8) {
                    Text("\(entry.count)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(
                            width: 34 + 30 * scale,
                            height: 34 + 30 * scale
                        )
                        .background(
                            Circle()
                                .fill(Theme.color(for: entry.rarity).gradient)
                                .shadow(
                                    color: Theme.color(for: entry.rarity).opacity(0.55),
                                    radius: 9, y: 3
                                )
                        )
                    Text(entry.rarity.displayName)
                        .font(.system(size: 9, weight: .semibold))
                        .textCase(.uppercase)
                        .kerning(0.6)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
