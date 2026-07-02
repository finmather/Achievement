import Foundation

/// Builds CDN URLs for a game's official artwork. These assets are served
/// unauthenticated from Steam's CDN and exist for virtually every store app.
public struct SteamArtwork: Hashable, Sendable {
    public let appID: Int
    public let iconHash: String?

    private static let cdnBase = "https://cdn.cloudflare.steamstatic.com/steam/apps"
    private static let communityBase = "https://media.steampowered.com/steamcommunity/public/images/apps"

    public init(appID: Int, iconHash: String? = nil) {
        self.appID = appID
        self.iconHash = iconHash
    }

    /// Portrait 600×900 capsule — the library card asset.
    public var portrait: URL {
        URL(string: "\(Self.cdnBase)/\(appID)/library_600x900_2x.jpg")!
    }

    /// Landscape 460×215 header — reliable fallback, exists for older titles
    /// that predate portrait capsules.
    public var header: URL {
        URL(string: "\(Self.cdnBase)/\(appID)/header.jpg")!
    }

    /// Wide hero banner used behind game detail headers.
    public var hero: URL {
        URL(string: "\(Self.cdnBase)/\(appID)/library_hero.jpg")!
    }

    /// Small square community icon (requires the hash from `GetOwnedGames`).
    public var icon: URL? {
        guard let iconHash, !iconHash.isEmpty else { return nil }
        return URL(string: "\(Self.communityBase)/\(appID)/\(iconHash).jpg")
    }
}
