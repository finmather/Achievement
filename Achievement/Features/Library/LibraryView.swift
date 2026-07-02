import SwiftUI
import AchievementCore

struct LibraryView: View {
    let home: HomeModel

    @State private var searchText = ""
    @State private var sort: LibrarySort = .recentlyPlayed

    private var library: LibraryStore { home.library }

    private var filtered: [Game] {
        LibraryFilter.apply(library.games, search: searchText, sort: sort)
    }

    var body: some View {
        ZStack {
            ScreenBackground()

            Group {
                if !library.hasContent, library.phase == .loadingLibrary {
                    LibrarySkeleton()
                } else if filtered.isEmpty, !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else if library.games.isEmpty {
                    ContentUnavailableView(
                        "No Games Yet",
                        systemImage: "square.stack",
                        description: Text("Games appear here once your Steam library syncs.")
                    )
                } else {
                    grid
                }
            }
        }
        .navigationTitle("Library")
        .searchable(text: $searchText, prompt: "Search your games")
        .toolbar { sortMenu }
        .refreshable { await library.refresh() }
    }

    private var grid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 14),
                        GridItem(.flexible(), spacing: 14),
                    ],
                    spacing: 14
                ) {
                    ForEach(filtered) { game in
                        NavigationLink(value: game) {
                            GameCard(game: game)
                        }
                        .buttonStyle(.pressableCard)
                        .scrollTransition(.animated(.spring(duration: 0.4))) { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1 : 0.75)
                                .scaleEffect(phase.isIdentity ? 1 : 0.96)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .animation(.spring(duration: 0.35), value: filtered.map(\.appID))
    }

    private var summary: String {
        let stats = library.stats
        var parts = ["\(stats.totalGames) games"]
        if stats.perfectGames > 0 { parts.append("\(stats.perfectGames) perfect") }
        return parts.joined(separator: " · ")
    }

    private var sortMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Sort", selection: $sort.animation(.spring(duration: 0.35))) {
                    ForEach(LibrarySort.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
        }
    }
}

// MARK: - Card

private struct GameCard: View {
    let game: Game

    private var progress: AchievementProgress? { game.achievements }
    private var isPerfect: Bool { game.isPerfect }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RemoteArtView.portrait(for: game)
                .aspectRatio(2 / 3, contentMode: .fit)
                .overlay(alignment: .topTrailing) {
                    if isPerfect { PerfectSeal() }
                }

            VStack(alignment: .leading, spacing: 8) {
                Text(game.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let progress, progress.total > 0 {
                        CompletionRing(
                            fraction: progress.fraction,
                            isPerfect: isPerfect,
                            lineWidth: 3.5,
                            animatesOnAppear: false
                        )
                        .frame(width: 22, height: 22)

                        Text("\(progress.unlocked)/\(progress.total)")
                            .font(.miniNumber)
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "circle.dashed")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 4)
                    Text(Format.hours(game.playtimeMinutes))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(12)
        }
        .cardSurface(cornerRadius: 20)
        .overlay {
            if isPerfect {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Theme.gold.opacity(0.8), Theme.goldDeep.opacity(0.5)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 1.5
                    )
            }
        }
    }
}

/// Small gold badge on perfect games' artwork.
private struct PerfectSeal: View {
    var body: some View {
        Image(systemName: "crown.fill")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(7)
            .background(
                Circle().fill(
                    LinearGradient(
                        colors: [Theme.gold, Theme.goldDeep],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            )
            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
            .padding(8)
            .accessibilityLabel("Perfect game")
    }
}

private struct LibrarySkeleton: View {
    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14),
                ],
                spacing: 14
            ) {
                ForEach(0..<6, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.quaternary)
                        .aspectRatio(2 / 3.6, contentMode: .fit)
                }
            }
            .padding(20)
        }
        .shimmering()
        .scrollDisabled(true)
        .accessibilityLabel("Loading your library")
    }
}
