import SwiftUI
import AchievementCore

// MARK: - Atmosphere

/// The cover art, blurred into a full-screen atmosphere with a scrim that
/// keeps text legible in both color schemes.
///
/// Layout discipline: the art only ever lives inside an `.overlay` of a
/// size-neutral view — remote images carry native ideal sizes in the
/// thousands of points and must never participate in layout.
struct BackdropArt: View {
    let game: Game
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            AuroraBackground()

            Color.clear
                .overlay {
                    RemoteArtView.wide(for: game)
                        .blur(radius: 42, opaque: true)
                }
                .clipped()
                .opacity(scheme == .dark ? 0.55 : 0.4)
                .overlay {
                    LinearGradient(
                        colors: scheme == .dark
                            ? [.black.opacity(0.25), .black.opacity(0.6)]
                            : [.white.opacity(0.35), .white.opacity(0.7)],
                        startPoint: .top, endPoint: .bottom
                    )
                }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Recent unlocks strip

struct RecentUnlockStrip: View {
    let achievements: [Achievement]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(achievements) { achievement in
                    VStack(spacing: 7) {
                        AchievementIcon(achievement: achievement, size: Tokens.IconSize.l)
                            .shadow(
                                color: (achievement.rarity.map(Theme.color(for:))
                                    ?? Theme.accent).opacity(0.4),
                                radius: 9
                            )
                        Text(achievement.displayName)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(2, reservesSpace: true)
                            .multilineTextAlignment(.center)
                        if let date = achievement.unlockedAt {
                            Text(Format.relative(date))
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(width: 78)
                }
            }
            .padding(.horizontal, Tokens.screenMargin)
            .padding(.vertical, 10)
        }
        .scrollClipDisabled()
        .padding(.horizontal, -Tokens.screenMargin)
    }
}

// MARK: - Roadmap

/// The path to perfection: remaining achievements as a connected timeline,
/// most attainable first. Shows the next few waypoints, then a quiet count.
struct RoadmapView: View {
    /// Locked achievements, easiest (highest global %) first.
    let remaining: [Achievement]

    private var waypoints: [Achievement] { Array(remaining.prefix(5)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(waypoints.enumerated()), id: \.element.id) { index, achievement in
                HStack(alignment: .top, spacing: 14) {
                    // Dot + connecting line.
                    VStack(spacing: 0) {
                        Circle()
                            .fill(index == 0
                                  ? AnyShapeStyle(Theme.accentDuotone)
                                  : AnyShapeStyle(Color.primary.opacity(0.25)))
                            .frame(width: index == 0 ? 12 : 9, height: index == 0 ? 12 : 9)
                            .shadow(color: Theme.accent.opacity(index == 0 ? 0.7 : 0), radius: 5)
                            .padding(.top, 16)
                        if index < waypoints.count - 1 || remaining.count > waypoints.count {
                            Rectangle()
                                .fill(.primary.opacity(0.14))
                                .frame(width: 1.5)
                                .frame(maxHeight: .infinity)
                        }
                    }
                    .frame(width: 14)

                    RoadmapRow(achievement: achievement, isNext: index == 0)
                        .padding(.bottom, 10)
                }
                .fixedSize(horizontal: false, vertical: true)
            }

            if remaining.count > waypoints.count {
                HStack(spacing: 14) {
                    Image(systemName: "ellipsis")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(width: 14)
                    Text("\(remaining.count - waypoints.count) more beyond — full list below")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 2)
            }
        }
    }
}

private struct RoadmapRow: View {
    let achievement: Achievement
    let isNext: Bool

    private var isMystery: Bool { achievement.isHidden }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AchievementIcon(achievement: achievement, size: 40)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(isMystery ? "Hidden achievement" : achievement.displayName)
                        .font(.subheadline.weight(isNext ? .bold : .semibold))
                        .lineLimit(1)
                    if isNext {
                        Text("Next")
                            .font(.system(size: 9, weight: .bold))
                            .textCase(.uppercase)
                            .kerning(0.8)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Theme.accentDuotone))
                    }
                }
                if let detail = isMystery ? "Keep playing to reveal this one." : achievement.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 8) {
                    if let rarity = achievement.rarity {
                        RarityChip(rarity: rarity)
                    }
                    if let percent = achievement.globalPercent {
                        Text(Format.globalPercent(percent))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Insights

/// Real numbers from the player's own record — never fabricated guides.
struct InsightLines: View {
    let game: Game
    let insights: GameInsights

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            if let rarest = insights.rarestEarned, let percent = rarest.globalPercent {
                line(
                    symbol: "sparkles",
                    text: "Your rarest here: \(rarest.displayName) — only \(Format.globalPercent(percent))"
                )
            }
            if let pace = insights.unlockPace {
                line(
                    symbol: "speedometer",
                    text: paceText(pace)
                )
            }
            if let first = insights.firstUnlock, let latest = insights.latestUnlock,
               first != latest {
                line(
                    symbol: "point.topleft.down.curvedto.point.bottomright.up",
                    text: "Hunting here since \(first.formatted(.dateTime.month(.abbreviated).year())) — latest \(Format.relative(latest))"
                )
            }
        }
    }

    private func paceText(_ pace: Double) -> String {
        if pace >= 1 {
            return "You average \((pace * 10).rounded() / 10) unlocks per hour"
        }
        let hoursPer = (1 / pace * 10).rounded() / 10
        return "You average one unlock every \(hoursPer) hrs"
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

// MARK: - Friends who own it

struct FriendOwnersRow: View {
    let owners: [PlayerProfile]

    var body: some View {
        NavigationLink(value: owners[0]) {
            HStack(spacing: 12) {
                HStack(spacing: -12) {
                    ForEach(owners.prefix(4)) { friend in
                        AvatarView(profile: friend, size: 40)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(ownerLine)
                        .font(.footnote.weight(.semibold))
                    Text("Tap to compare progress")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassChip(.blob(Tokens.Radius.blob))
        }
        .buttonStyle(.pressableCard)
    }

    private var ownerLine: String {
        let names = owners.prefix(2).map(\.personaName).joined(separator: ", ")
        let extra = owners.count - min(owners.count, 2)
        return extra > 0
            ? "\(names) and \(extra) more own this"
            : "\(names) own\(owners.count == 1 ? "s" : "") this"
    }
}

// MARK: - Notes

/// Local, private per-game notes — boss orders, build ideas, whatever
/// future-you needs. Never leaves the device.
enum NotesStore {
    static func note(for appID: Int) -> String {
        UserDefaults.standard.string(forKey: "note-\(appID)") ?? ""
    }

    static func save(_ text: String, for appID: Int) {
        let key = "note-\(appID)"
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set(text, forKey: key)
        }
    }
}

struct NotesCard: View {
    let appID: Int

    @State private var note = ""
    @State private var editing = false

    var body: some View {
        Button {
            editing = true
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: note.isEmpty ? "square.and.pencil" : "note.text")
                    .font(.footnote)
                    .foregroundStyle(Theme.accentDuotone)
                    .frame(width: 22)
                    .padding(.top, 1)

                Text(note.isEmpty
                     ? "Add strategies, boss orders, or anything future-you will thank you for."
                     : note)
                    .font(.subheadline)
                    .foregroundStyle(note.isEmpty ? .secondary : .primary.opacity(0.85))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .glassChip(.blob(Tokens.Radius.blob))
        }
        .buttonStyle(.pressableCard)
        .accessibilityIdentifier("detail.notes")
        .onAppear { note = NotesStore.note(for: appID) }
        .sheet(isPresented: $editing) {
            NotesEditor(appID: appID, note: $note)
        }
    }
}

private struct NotesEditor: View {
    let appID: Int
    @Binding var note: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TextEditor(text: $note)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(Tokens.screenMargin)
                .background(AuroraBackground())
                .navigationTitle("Notes")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
                .onChange(of: note) { _, newValue in
                    NotesStore.save(newValue, for: appID) // autosave
                }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.thinMaterial)
    }
}

// MARK: - Similar games

struct SimilarGamesRail: View {
    let games: [Game]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: Tokens.itemGap) {
                ForEach(games) { game in
                    NavigationLink(value: game) {
                        VStack(alignment: .leading, spacing: 6) {
                            Color.clear
                                .frame(width: 96, height: 144)
                                .overlay { RemoteArtView.portrait(for: game) }
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                                )
                                .shadow(color: .black.opacity(0.3), radius: 10, y: 6)
                            Text(game.name)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .frame(width: 96, alignment: .leading)
                        }
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.horizontal, Tokens.screenMargin)
            .padding(.vertical, 10)
        }
        .scrollClipDisabled()
        .padding(.horizontal, -Tokens.screenMargin)
    }
}

// MARK: - Achievement list

struct AchievementList: View {
    let achievements: [Achievement]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(achievements.enumerated()), id: \.element.id) { position, achievement in
                AchievementRow(achievement: achievement)
                if position < achievements.count - 1 {
                    Rectangle()
                        .fill(.primary.opacity(0.07))
                        .frame(height: 0.5)
                        .padding(.leading, 62)
                }
            }
        }
    }
}

private struct AchievementRow: View {
    let achievement: Achievement

    private var isMystery: Bool { achievement.isHidden && !achievement.isUnlocked }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            AchievementIcon(achievement: achievement, size: Tokens.IconSize.m)

            VStack(alignment: .leading, spacing: 4) {
                Text(isMystery ? "Hidden achievement" : achievement.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(achievement.isUnlocked ? .primary : .secondary)

                if let detail = detailText {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    if let rarity = achievement.rarity {
                        RarityChip(rarity: rarity)
                    }
                    if let percent = achievement.globalPercent {
                        Text(Format.globalPercent(percent))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 0)
                    if let unlockedAt = achievement.unlockedAt {
                        Text(Format.relative(unlockedAt))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.top, 2)
            }

            if achievement.isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(Color(red: 0.18, green: 0.8, blue: 0.56))
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 13)
        .opacity(achievement.isUnlocked ? 1 : 0.8)
    }

    private var detailText: String? {
        if isMystery { return "Keep playing to reveal this one." }
        return achievement.detail
    }
}

struct RarityChip: View {
    let rarity: Rarity

    var body: some View {
        Text(rarity.displayName)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.color(for: rarity))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Theme.color(for: rarity).opacity(0.14)))
    }
}
