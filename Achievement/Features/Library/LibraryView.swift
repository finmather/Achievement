import SwiftUI
import AchievementCore

/// Browsing a premium collection: a featured hero cover, then a staggered
/// two-column wall of large portrait art. Covers zoom into the detail page.
struct LibraryView: View {
    let home: HomeModel

    @State private var searchText = ""
    @State private var sort: LibrarySort = .recentlyPlayed
    @State private var scrollOffset: CGFloat = 0
    @Namespace private var zoom

    private var library: LibraryStore { home.library }

    private var filtered: [Game] {
        LibraryFilter.apply(library.games, search: searchText, sort: sort)
    }

    /// The hero only leads when browsing the default recency view.
    private var featured: Game? {
        guard searchText.isEmpty, sort == .recentlyPlayed else { return nil }
        return filtered.first { $0.lastPlayed != nil }
    }

    var body: some View {
        ZStack {
            AuroraBackground(scrollOffset: scrollOffset)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Library")
                        .font(.editorialTitle)
                        .padding(.top, 16)
                        .entrance(0)

                    SearchField(text: $searchText)
                        .entrance(1)

                    SortChips(sort: $sort)
                        .entrance(2)

                    content
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .trackScrollOffset(into: $scrollOffset)
            .refreshable { await library.refresh() }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: Game.self) { game in
            GameDetailView(game: game, home: home)
                .navigationTransition(.zoom(sourceID: game.appID, in: zoom))
        }
    }

    @ViewBuilder
    private var content: some View {
        if !library.hasContent, library.phase == .loadingLibrary {
            loadingGrid
        } else if filtered.isEmpty, !searchText.isEmpty {
            EmptyStateView(
                motif: .telescope,
                title: "Nothing out here",
                message: "No games match “\(searchText)”. The library searches as you type — try fewer letters.",
                actionTitle: "Clear search",
                action: { searchText = "" }
            )
        } else if library.games.isEmpty {
            EmptyStateView(
                motif: .controller,
                title: "Your shelf is waiting",
                message: "Games appear here as soon as your Steam library syncs."
            )
        } else {
            summaryLine.entrance(3)

            if let featured {
                FeaturedCover(game: featured)
                    .matchedTransitionSource(id: featured.appID, in: zoom)
                    .accessibilityIdentifier("library.cover")
                    .entrance(4)
            }

            StaggeredCoverGrid(
                games: featured.map { hero in filtered.filter { $0.appID != hero.appID } }
                    ?? filtered,
                namespace: zoom
            )
            .animation(.spring(duration: 0.35), value: filtered.map(\.appID))
        }
    }

    private var summaryLine: some View {
        let stats = library.stats
        var parts = ["\(stats.totalGames) games"]
        if stats.perfectGames > 0 { parts.append("\(stats.perfectGames) perfect") }
        return Text(parts.joined(separator: " · ")).capsLabel()
    }

    private var loadingGrid: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 16) {
                BreathingPlaceholder(shape: .blob(28)).frame(height: 240)
                BreathingPlaceholder(shape: .blob(28)).frame(height: 240)
            }
            VStack(spacing: 16) {
                BreathingPlaceholder(shape: .blob(28)).frame(height: 240)
                BreathingPlaceholder(shape: .blob(28)).frame(height: 240)
            }
            .padding(.top, 44)
        }
        .accessibilityLabel("Loading your library")
    }
}

// MARK: - Search & sort

private struct SearchField: View {
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField("Search your games", text: $text)
                .focused($focused)
                .autocorrectionDisabled()
                .accessibilityIdentifier("library.search")
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassChip()
    }
}

private struct SortChips: View {
    @Binding var sort: LibrarySort

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LibrarySort.allCases) { option in
                    Button {
                        withAnimation(.spring(duration: 0.35)) { sort = option }
                    } label: {
                        Text(option.displayName)
                            .font(.footnote.weight(sort == option ? .semibold : .regular))
                            .foregroundStyle(sort == option ? .white : .secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background {
                                if sort == option {
                                    Capsule().fill(Theme.accentDuotone)
                                } else {
                                    Capsule().fill(.ultraThinMaterial)
                                }
                            }
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.horizontal, -24)
    }
}

// MARK: - Featured hero

private struct FeaturedCover: View {
    let game: Game

    var body: some View {
        NavigationLink(value: game) {
            ZStack(alignment: .bottomLeading) {
                RemoteArtView.wide(for: game)
                    .aspectRatio(21 / 10, contentMode: .fit)
                    .clipped()
                    .overlay {
                        LinearGradient(
                            colors: [.clear, .clear, .black.opacity(0.65)],
                            startPoint: .top, endPoint: .bottom
                        )
                    }

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Continue").capsLabel()
                            .foregroundStyle(.white.opacity(0.75))
                        Text(game.name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    Spacer()
                    if let progress = game.achievements {
                        CompletionRing(
                            fraction: progress.fraction,
                            isPerfect: progress.isPerfect,
                            lineWidth: 5,
                            animatesOnAppear: false
                        ) {
                            Text(Format.percent(progress.fraction))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 46, height: 46)
                    }
                }
                .padding(18)
            }
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 22, y: 12)
        }
        .buttonStyle(.pressableCard)
    }
}

// MARK: - Staggered grid

/// Two columns, the right one dropped 44pt — the wall reads as a curated
/// collage instead of a spreadsheet of thumbnails.
private struct StaggeredCoverGrid: View {
    let games: [Game]
    let namespace: Namespace.ID

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            column(games.enumerated().filter { $0.offset.isMultiple(of: 2) }.map(\.element))
            column(games.enumerated().filter { !$0.offset.isMultiple(of: 2) }.map(\.element))
                .padding(.top, 44)
        }
    }

    private func column(_ games: [Game]) -> some View {
        LazyVStack(spacing: 16) {
            ForEach(games) { game in
                CoverCard(game: game)
                    .matchedTransitionSource(id: game.appID, in: namespace)
                    .accessibilityIdentifier("library.cover")
                    .scrollTransition(.animated(.spring(duration: 0.4))) { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0.7)
                            .scaleEffect(phase.isIdentity ? 1 : 0.95)
                    }
            }
        }
    }
}

private struct CoverCard: View {
    let game: Game

    private var progress: AchievementProgress? { game.achievements }
    private var isPerfect: Bool { game.isPerfect }

    var body: some View {
        NavigationLink(value: game) {
            VStack(alignment: .leading, spacing: 0) {
                RemoteArtView.portrait(for: game)
                    .aspectRatio(2 / 3, contentMode: .fit)
                    .clipped()
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .background {
                if isPerfect {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Theme.gold.opacity(0.55))
                        .blur(radius: 18)
                        .padding(6)
                }
            }
            .overlay(alignment: .bottomLeading) {
                badge.offset(x: -6, y: 14)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(
                        isPerfect
                            ? AnyShapeStyle(Theme.goldGradient)
                            : AnyShapeStyle(Color.white.opacity(0.12)),
                        lineWidth: isPerfect ? 1.6 : 0.8
                    )
            )
            .padding(.bottom, 18)
            .shadow(color: .black.opacity(0.28), radius: 14, y: 8)
            .accessibilityLabel(accessibilitySummary)
        }
        .buttonStyle(.pressableCard)
    }

    /// The ring badge overlaps the cover's corner — art stays the hero, the
    /// number floats on top of the world instead of living in a caption bar.
    @ViewBuilder
    private var badge: some View {
        if let progress, progress.total > 0 {
            CompletionRing(
                fraction: progress.fraction,
                isPerfect: isPerfect,
                lineWidth: 4,
                animatesOnAppear: false
            ) {
                Group {
                    if isPerfect {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.goldGradient)
                    } else {
                        Text(Format.percent(progress.fraction))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                }
            }
            .frame(width: 44, height: 44)
            .padding(5)
            .glassChip(.circle)
        }
    }

    private var accessibilitySummary: String {
        if let progress, progress.total > 0 {
            return "\(game.name), \(Format.percent(progress.fraction)) complete"
        }
        return game.name
    }
}
