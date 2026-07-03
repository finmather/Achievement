import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Store-page facts about a game — the companion-guide header material.
public struct GameMeta: Hashable, Sendable, Codable {
    public let developers: [String]
    public let publishers: [String]
    /// Steam's display string, e.g. "17 Sep, 2020".
    public let releaseDate: String?
    public let genres: [String]
    public let shortDescription: String?

    public init(
        developers: [String] = [],
        publishers: [String] = [],
        releaseDate: String? = nil,
        genres: [String] = [],
        shortDescription: String? = nil
    ) {
        self.developers = developers
        self.publishers = publishers
        self.releaseDate = releaseDate
        self.genres = genres
        self.shortDescription = shortDescription
    }

    public var isEmpty: Bool {
        developers.isEmpty && publishers.isEmpty && releaseDate == nil
            && genres.isEmpty && shortDescription == nil
    }

    /// "FromSoftware · Bandai Namco · 2022" — the byline under a title.
    public var byline: String? {
        var parts: [String] = []
        if let developer = developers.first { parts.append(developer) }
        if let publisher = publishers.first, publisher != developers.first {
            parts.append(publisher)
        }
        if let releaseDate, let year = releaseDate.split(separator: " ").last {
            parts.append(String(year))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// Fetches store-page metadata from Steam's unauthenticated storefront API.
/// Metadata is immutable in practice, so callers cache results permanently.
public struct StoreClient: Sendable {
    private let httpClient: any HTTPClient
    private static let base = "https://store.steampowered.com/api/appdetails"

    public init(httpClient: any HTTPClient = URLSessionHTTPClient()) {
        self.httpClient = httpClient
    }

    /// `nil` data inside a success envelope (delisted apps) yields an empty
    /// `GameMeta` — a valid, cacheable "nothing to show" answer.
    public func meta(appID: Int) async throws -> GameMeta {
        var components = URLComponents(string: Self.base)!
        components.queryItems = [
            URLQueryItem(name: "appids", value: String(appID)),
            URLQueryItem(name: "l", value: "english"),
        ]
        let (data, response) = try await httpClient.data(for: URLRequest(url: components.url!))
        switch response.statusCode {
        case 200:
            guard let payload = try? JSONDecoder().decode(
                [String: StoreAppDetailsEnvelope].self, from: data
            ), let envelope = payload[String(appID)] else {
                throw SteamWebAPIError.invalidResponse
            }
            guard envelope.success, let details = envelope.data else {
                return GameMeta()
            }
            return GameMeta(
                developers: details.developers ?? [],
                publishers: details.publishers ?? [],
                releaseDate: details.releaseDate?.date,
                genres: (details.genres ?? []).map(\.description),
                shortDescription: details.shortDescription
            )
        case 429:
            throw SteamWebAPIError.rateLimited
        default:
            throw SteamWebAPIError.httpStatus(response.statusCode)
        }
    }
}

// MARK: - Wire format

struct StoreAppDetailsEnvelope: Decodable {
    let success: Bool
    let data: StoreAppDetailsData?
}

struct StoreAppDetailsData: Decodable {
    let developers: [String]?
    let publishers: [String]?
    let genres: [StoreGenreDTO]?
    let releaseDate: StoreReleaseDateDTO?
    let shortDescription: String?

    enum CodingKeys: String, CodingKey {
        case developers, publishers, genres
        case releaseDate = "release_date"
        case shortDescription = "short_description"
    }
}

struct StoreGenreDTO: Decodable {
    let description: String
}

struct StoreReleaseDateDTO: Decodable {
    let date: String?
}
