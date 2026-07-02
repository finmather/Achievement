import SwiftUI
import Charts
import AchievementCore

struct ProfileView: View {
    @Environment(AppModel.self) private var appModel
    let home: HomeModel

    @State private var confirmingSignOut = false

    private var library: LibraryStore { home.library }

    var body: some View {
        ZStack {
            ScreenBackground()

            ScrollView {
                VStack(spacing: 20) {
                    IdentityCard(profile: home.profile, isDemo: home.isDemo)

                    statsGrid

                    if !library.unlocks.isEmpty {
                        UnlockHistoryCard(unlocks: library.unlocks)
                        RarityCollectionCard(unlocks: library.unlocks)
                    }

                    signOutButton

                    Text("Game data provided by Steam. Not affiliated with Valve.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Profile")
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

    private var statsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
            ],
            spacing: 12
        ) {
            StatTile(
                value: Int(library.stats.totalHours.rounded()).formatted(),
                label: "Hours played",
                symbol: "clock.fill",
                tint: Theme.accent
            )
            StatTile(
                value: Format.percent(library.stats.averageCompletion),
                label: "Avg completion",
                symbol: "circle.dashed",
                tint: Color(red: 0.22, green: 0.72, blue: 0.93)
            )
            StatTile(
                value: "\(library.stats.perfectGames)",
                label: "Perfect games",
                symbol: "crown.fill",
                tint: Theme.gold
            )
            StatTile(
                value: library.stats.unlockedAchievements.formatted(),
                label: "Achievements",
                symbol: "trophy.fill",
                tint: Color(red: 0.16, green: 0.78, blue: 0.57)
            )
        }
    }

    private var signOutButton: some View {
        Button(role: .destructive) {
            confirmingSignOut = true
        } label: {
            Text(home.isDemo ? "Leave Demo" : "Sign Out")
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .cardSurface(cornerRadius: 16)
        }
        .buttonStyle(.pressable)
        .padding(.top, 8)
    }
}

// MARK: - Identity

private struct IdentityCard: View {
    let profile: PlayerProfile?
    let isDemo: Bool

    var body: some View {
        VStack(spacing: 12) {
            if let profile {
                AvatarView(profile: profile, size: 76)

                VStack(spacing: 3) {
                    Text(profile.personaName)
                        .font(.title2.weight(.bold))
                    Text(subtitle(for: profile))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Circle().fill(.quaternary).frame(width: 76, height: 76).shimmering()
                RoundedRectangle(cornerRadius: 6)
                    .fill(.quaternary)
                    .frame(width: 120, height: 20)
                    .shimmering()
            }

            if isDemo {
                Text("DEMO")
                    .font(.caption2.weight(.bold))
                    .kerning(1)
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Theme.accent.opacity(0.12)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .cardSurface()
    }

    private func subtitle(for profile: PlayerProfile) -> String {
        var parts: [String] = []
        if let created = profile.accountCreatedAt {
            parts.append("On Steam since \(created.formatted(.dateTime.year()))")
        }
        if let country = profile.countryCode {
            parts.append(flag(for: country))
        }
        return parts.joined(separator: "  ")
    }

    private func flag(for countryCode: String) -> String {
        countryCode.uppercased().unicodeScalars.reduce(into: "") { result, scalar in
            if let flagScalar = UnicodeScalar(127_397 + scalar.value) {
                result.unicodeScalars.append(flagScalar)
            }
        }
    }
}

private struct StatTile: View {
    let value: String
    let label: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.subheadline)
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(Circle().fill(tint.opacity(0.12)))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.statNumber)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(label).statLabelStyle()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardSurface(cornerRadius: 20)
    }
}

// MARK: - Charts

private struct UnlockHistoryCard: View {
    let unlocks: [UnlockEvent]

    private var history: [MonthlyUnlocks] {
        HistoryEngine.monthlyUnlocks(dates: unlocks.map(\.unlockedAt))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Unlock History")
                    .font(.headline)
                Text("Achievements per month, last 12 months")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Chart(history) { month in
                BarMark(
                    x: .value("Month", month.month, unit: .month),
                    y: .value("Unlocks", month.count)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.accent, Color(red: 0.22, green: 0.72, blue: 0.93)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .cornerRadius(3)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month, count: 3)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                        .font(.caption2)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine().foregroundStyle(.quaternary)
                    AxisValueLabel().font(.caption2)
                }
            }
            .frame(height: 150)
        }
        .padding(20)
        .cardSurface()
    }
}

private struct RarityCollectionCard: View {
    let unlocks: [UnlockEvent]

    private var counts: [(rarity: Rarity, count: Int)] {
        let grouped = Dictionary(grouping: unlocks.compactMap(\.achievement.rarity)) { $0 }
        return Rarity.allCases.reversed().compactMap { rarity in
            guard let count = grouped[rarity]?.count, count > 0 else { return nil }
            return (rarity, count)
        }
    }

    private var maxCount: Int { counts.map(\.count).max() ?? 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Rarity Collection")
                    .font(.headline)
                Text("Your unlocks, rarest first")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                ForEach(counts, id: \.rarity) { entry in
                    HStack(spacing: 10) {
                        RarityChip(rarity: entry.rarity)
                            .frame(width: 86, alignment: .leading)

                        GeometryReader { proxy in
                            Capsule()
                                .fill(Theme.color(for: entry.rarity).opacity(0.75))
                                .frame(
                                    width: max(
                                        8,
                                        proxy.size.width
                                            * Double(entry.count) / Double(maxCount)
                                    )
                                )
                                .frame(maxHeight: .infinity, alignment: .center)
                        }
                        .frame(height: 8)

                        Text("\(entry.count)")
                            .font(.miniNumber)
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }
        }
        .padding(20)
        .cardSurface()
    }
}
