import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Fetches community tags from SteamSpy — Steam's own store genres are too
/// coarse for the radar chart (no Roguelike/FPS/Platformer). Tags never
/// meaningfully change, so callers cache results permanently.
public struct SteamSpyClient: Sendable {
    private let httpClient: any HTTPClient
    private static let base = "https://steamspy.com/api.php"

    public init(httpClient: any HTTPClient = URLSessionHTTPClient()) {
        self.httpClient = httpClient
    }

    /// Community tags for one app, strongest first. Empty when SteamSpy has
    /// no tag data — a valid, cacheable answer.
    public func tags(appID: Int) async throws -> [String] {
        var components = URLComponents(string: Self.base)!
        components.queryItems = [
            URLQueryItem(name: "request", value: "appdetails"),
            URLQueryItem(name: "appid", value: String(appID)),
        ]
        let (data, response) = try await httpClient.data(for: URLRequest(url: components.url!))
        switch response.statusCode {
        case 200:
            guard let details = try? JSONDecoder().decode(SteamSpyAppDetails.self, from: data) else {
                throw SteamWebAPIError.invalidResponse
            }
            return details.tags
                .sorted { ($0.value, $1.key) > ($1.value, $0.key) }
                .map(\.key)
        case 429:
            throw SteamWebAPIError.rateLimited
        default:
            throw SteamWebAPIError.httpStatus(response.statusCode)
        }
    }
}

struct SteamSpyAppDetails: Decodable {
    /// Tag name → community votes. SteamSpy sends `[]` instead of `{}` when
    /// an app has no tags, so decode leniently.
    let tags: [String: Int]

    enum CodingKeys: String, CodingKey {
        case tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tags = (try? container.decode([String: Int].self, forKey: .tags)) ?? [:]
    }
}
