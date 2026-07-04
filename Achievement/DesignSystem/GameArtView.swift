import SwiftUI
import AchievementCore

/// Remote game art on the cached pipeline: instant re-display from memory,
/// disk persistence via URLCache, a breathing placeholder while loading,
/// and a URL fallback chain (older Steam titles lack portrait capsules, so
/// cards fall back to the landscape header, then a styled placeholder).
struct RemoteArtView: View {
    let urls: [URL]
    var contentMode: ContentMode = .fill

    @State private var urlIndex = 0

    var body: some View {
        CachedImage(
            url: urls.indices.contains(urlIndex) ? urls[urlIndex] : nil,
            contentMode: contentMode,
            onFailure: {
                if urlIndex < urls.count - 1 { urlIndex += 1 }
            }
        ) { isLoading in
            placeholder(breathes: isLoading)
        }
    }

    @ViewBuilder
    private func placeholder(breathes: Bool) -> some View {
        let base = Rectangle()
            .fill(.quaternary)
            .overlay {
                Image(systemName: "gamecontroller")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
            }
        if breathes {
            base.breathing()
        } else {
            base
        }
    }
}

extension RemoteArtView {
    /// Portrait card art for the library grid.
    static func portrait(for game: Game) -> RemoteArtView {
        RemoteArtView(urls: [game.artwork.portrait, game.artwork.header])
    }

    /// Wide art for detail headers and landscape rows.
    static func wide(for game: Game) -> RemoteArtView {
        RemoteArtView(urls: [game.artwork.hero, game.artwork.header])
    }

    /// Small square icon for compact rows.
    static func icon(for game: Game) -> RemoteArtView {
        RemoteArtView(urls: [game.artwork.icon, game.artwork.header].compactMap { $0 })
    }
}
