import SwiftUI
import AchievementCore

/// Remote image with a graceful lifecycle: shimmer while loading, fade-in on
/// arrival, and a URL fallback chain (older Steam titles lack portrait
/// capsules, so cards fall back to the landscape header, then a placeholder).
struct RemoteArtView: View {
    let urls: [URL]
    var contentMode: ContentMode = .fill

    @State private var urlIndex = 0

    var body: some View {
        AsyncImage(
            url: urls.indices.contains(urlIndex) ? urls[urlIndex] : nil,
            transaction: Transaction(animation: .easeOut(duration: 0.35))
        ) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            case .failure:
                placeholder
                    .onAppear {
                        if urlIndex < urls.count - 1 { urlIndex += 1 }
                    }
            case .empty:
                placeholder.breathing()
            @unknown default:
                placeholder
            }
        }
    }

    private var placeholder: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                Image(systemName: "gamecontroller")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
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
