import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Typed client for the Steam Web API (api.steampowered.com).
///
/// Every method maps wire DTOs into domain models before returning. Steam has
/// no bulk "achievement progress for the whole library" endpoint, so
/// `achievements(appID:player:)` is called per game by `LibrarySyncService`.
public struct SteamWebAPIClient: Sendable {
    private let apiKey: String
    private let httpClient: any HTTPClient
    private static let base = "https://api.steampowered.com"

    public init(apiKey: String, httpClient: any HTTPClient = URLSessionHTTPClient()) {
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.httpClient = httpClient
    }

    // MARK: - Profiles & friends

    public func playerSummaries(for ids: [SteamID]) async throws -> [PlayerProfile] {
        guard !ids.isEmpty else { return [] }
        var profiles: [PlayerProfile] = []
        // The endpoint accepts at most 100 IDs per call.
        for batch in ids.chunked(into: 100) {
            let envelope: PlayerSummariesEnvelope = try await get(
                "ISteamUser", "GetPlayerSummaries", "v2",
                query: ["steamids": batch.map(\.description).joined(separator: ",")],
                requiresKey: true
            )
            profiles += envelope.response.players.map(\.asProfile)
        }
        // Steam returns summaries in arbitrary order; restore the caller's.
        let byID = Dictionary(profiles.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return ids.compactMap { byID[$0] }
    }

    public func profile(for id: SteamID) async throws -> PlayerProfile {
        guard let profile = try await playerSummaries(for: [id]).first else {
            throw SteamWebAPIError.invalidResponse
        }
        return profile
    }

    /// Friend list is only available when the profile's friends list is public;
    /// Steam responds 401 in that case, which surfaces as `.profilePrivate`.
    public func friendIDs(of id: SteamID) async throws -> [SteamID] {
        let envelope: FriendListEnvelope = try await get(
            "ISteamUser", "GetFriendList", "v1",
            query: ["steamid": id.description, "relationship": "friend"],
            requiresKey: true
        )
        return envelope.friendslist?.friends.map(\.steamid) ?? []
    }

    // MARK: - Library

    public func ownedGames(of id: SteamID) async throws -> [Game] {
        let envelope: OwnedGamesEnvelope = try await get(
            "IPlayerService", "GetOwnedGames", "v1",
            query: [
                "steamid": id.description,
                "include_appinfo": "1",
                "include_played_free_games": "1",
            ],
            requiresKey: true
        )
        // A missing games array with a public profile means an empty library;
        // for private profiles Steam returns an empty response object too, so
        // callers should check profile visibility for a better error message.
        return envelope.response.games?.map(\.asGame) ?? []
    }

    // MARK: - Achievements

    /// Full merged achievement list for one game: schema (names, icons,
    /// hidden flags) + the player's unlock state + global rarity.
    ///
    /// Throws `.noAchievements` when the app exposes no stats, and
    /// `.profilePrivate` when the player's game details are hidden.
    public func achievements(appID: Int, player: SteamID) async throws -> [Achievement] {
        async let schemaTask = achievementSchema(appID: appID)
        async let playerTask = playerAchievements(appID: appID, player: player)
        async let globalTask = globalPercentages(appID: appID)

        let schema = try await schemaTask
        guard !schema.isEmpty else { throw SteamWebAPIError.noAchievements }
        let player = try await playerTask
        // Rarity is decoration — don't fail the merge if it's unavailable.
        let global = (try? await globalTask) ?? [:]

        let playerByID = Dictionary(
            player.map { ($0.apiname, $0) },
            uniquingKeysWith: { a, _ in a }
        )

        return schema.map { item in
            let state = playerByID[item.name]
            let unlockTime = state?.unlocktime ?? 0
            return Achievement(
                id: item.name,
                displayName: item.displayName ?? state?.name ?? item.name,
                detail: item.description ?? state?.description,
                isHidden: (item.hidden ?? 0) == 1,
                iconURL: item.icon.flatMap(URL.init(string:)),
                lockedIconURL: item.icongray.flatMap(URL.init(string:)),
                isUnlocked: (state?.achieved ?? 0) == 1,
                unlockedAt: unlockTime > 0
                    ? Date(timeIntervalSince1970: TimeInterval(unlockTime)) : nil,
                globalPercent: global[item.name]
            )
        }
    }

    func achievementSchema(appID: Int) async throws -> [SchemaAchievementDTO] {
        let envelope: GameSchemaEnvelope = try await get(
            "ISteamUserStats", "GetSchemaForGame", "v2",
            query: ["appid": String(appID), "l": "english"],
            requiresKey: true
        )
        return envelope.game?.availableGameStats?.achievements ?? []
    }

    func playerAchievements(appID: Int, player: SteamID) async throws -> [PlayerAchievementDTO] {
        do {
            let envelope: PlayerAchievementsEnvelope = try await get(
                "ISteamUserStats", "GetPlayerAchievements", "v1",
                query: [
                    "appid": String(appID),
                    "steamid": player.description,
                    "l": "english",
                ],
                requiresKey: true
            )
            guard envelope.playerstats.success ?? false else {
                throw classify(steamError: envelope.playerstats.error)
            }
            return envelope.playerstats.achievements ?? []
        } catch let error as StatusWithBody {
            // Steam signals domain errors through 400/403 plus a JSON body.
            if let envelope = try? JSONDecoder().decode(
                PlayerAchievementsEnvelope.self, from: error.body
            ) {
                throw classify(steamError: envelope.playerstats.error)
            }
            throw SteamWebAPIError.httpStatus(error.status)
        }
    }

    public func globalPercentages(appID: Int) async throws -> [String: Double] {
        let envelope: GlobalPercentagesEnvelope = try await get(
            "ISteamUserStats", "GetGlobalAchievementPercentagesForApp", "v2",
            query: ["gameid": String(appID)],
            requiresKey: false
        )
        let entries = envelope.achievementpercentages?.achievements ?? []
        return Dictionary(
            entries.map { ($0.name, $0.percent) },
            uniquingKeysWith: { a, _ in a }
        )
    }

    private func classify(steamError message: String?) -> SteamWebAPIError {
        let lowered = (message ?? "").lowercased()
        if lowered.contains("no stats") { return .noAchievements }
        if lowered.contains("not public") || lowered.contains("private") {
            return .profilePrivate
        }
        return .invalidResponse
    }

    // MARK: - Transport

    private struct StatusWithBody: Error {
        let status: Int
        let body: Data
    }

    private func get<T: Decodable>(
        _ interface: String,
        _ method: String,
        _ version: String,
        query: [String: String],
        requiresKey: Bool
    ) async throws -> T {
        if requiresKey && apiKey.isEmpty { throw SteamWebAPIError.missingAPIKey }

        var components = URLComponents(string: "\(Self.base)/\(interface)/\(method)/\(version)/")!
        var items = query.map { URLQueryItem(name: $0.key, value: $0.value) }
            .sorted { $0.name < $1.name }
        if requiresKey {
            items.insert(URLQueryItem(name: "key", value: apiKey), at: 0)
        }
        components.queryItems = items

        let (data, response) = try await httpClient.data(for: URLRequest(url: components.url!))
        switch response.statusCode {
        case 200:
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw SteamWebAPIError.invalidResponse
            }
        case 429:
            throw SteamWebAPIError.rateLimited
        case 401 where interface == "ISteamUser" && method == "GetFriendList":
            throw SteamWebAPIError.profilePrivate
        case 400, 403:
            throw StatusWithBody(status: response.statusCode, body: data)
        default:
            throw SteamWebAPIError.httpStatus(response.statusCode)
        }
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
