import Foundation

// Wire formats for api.steampowered.com. Internal — the client maps these to
// domain models immediately. Steam's JSON is inconsistent (IDs as strings,
// numbers that are sometimes strings), so decoding stays deliberately lenient.

// MARK: - GetOwnedGames (IPlayerService, v1)

struct OwnedGamesEnvelope: Decodable {
    let response: OwnedGamesResponse
}

struct OwnedGamesResponse: Decodable {
    let gameCount: Int?
    let games: [OwnedGameDTO]?

    enum CodingKeys: String, CodingKey {
        case gameCount = "game_count"
        case games
    }
}

struct OwnedGameDTO: Decodable {
    let appid: Int
    let name: String?
    let playtimeForever: Int?
    let imgIconUrl: String?
    let rtimeLastPlayed: Int?

    enum CodingKeys: String, CodingKey {
        case appid, name
        case playtimeForever = "playtime_forever"
        case imgIconUrl = "img_icon_url"
        case rtimeLastPlayed = "rtime_last_played"
    }

    var asGame: Game {
        Game(
            appID: appid,
            name: name ?? "App \(appid)",
            playtimeMinutes: playtimeForever ?? 0,
            lastPlayed: (rtimeLastPlayed).flatMap { $0 > 0 ? Date(timeIntervalSince1970: TimeInterval($0)) : nil },
            iconHash: imgIconUrl
        )
    }
}

// MARK: - GetPlayerSummaries (ISteamUser, v2)

struct PlayerSummariesEnvelope: Decodable {
    let response: PlayerSummariesResponse
}

struct PlayerSummariesResponse: Decodable {
    let players: [PlayerSummaryDTO]
}

struct PlayerSummaryDTO: Decodable {
    let steamid: SteamID
    let personaname: String?
    let realname: String?
    let profileurl: String?
    let avatarmedium: String?
    let avatarfull: String?
    let communityvisibilitystate: Int?
    let timecreated: Int?
    let loccountrycode: String?

    var asProfile: PlayerProfile {
        PlayerProfile(
            id: steamid,
            personaName: personaname ?? "Player",
            realName: realname,
            avatarSmallURL: avatarmedium.flatMap(URL.init(string:)),
            avatarFullURL: avatarfull.flatMap(URL.init(string:)),
            profileURL: profileurl.flatMap(URL.init(string:)),
            countryCode: loccountrycode,
            accountCreatedAt: timecreated.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            isPublic: communityvisibilitystate == 3
        )
    }
}

// MARK: - GetFriendList (ISteamUser, v1)

struct FriendListEnvelope: Decodable {
    let friendslist: FriendListDTO?
}

struct FriendListDTO: Decodable {
    let friends: [FriendDTO]
}

struct FriendDTO: Decodable {
    let steamid: SteamID
    let friendSince: Int?

    enum CodingKeys: String, CodingKey {
        case steamid
        case friendSince = "friend_since"
    }
}

// MARK: - GetPlayerAchievements (ISteamUserStats, v1)

struct PlayerAchievementsEnvelope: Decodable {
    let playerstats: PlayerStatsDTO
}

struct PlayerStatsDTO: Decodable {
    let success: Bool?
    let error: String?
    let gameName: String?
    let achievements: [PlayerAchievementDTO]?
}

struct PlayerAchievementDTO: Decodable {
    let apiname: String
    let achieved: Int
    let unlocktime: Int?
    let name: String?
    let description: String?
}

// MARK: - GetSchemaForGame (ISteamUserStats, v2)

struct GameSchemaEnvelope: Decodable {
    let game: GameSchemaDTO?
}

struct GameSchemaDTO: Decodable {
    let gameName: String?
    let availableGameStats: AvailableGameStatsDTO?
}

struct AvailableGameStatsDTO: Decodable {
    let achievements: [SchemaAchievementDTO]?
}

struct SchemaAchievementDTO: Decodable {
    let name: String
    let displayName: String?
    let description: String?
    let hidden: Int?
    let icon: String?
    let icongray: String?
}

// MARK: - GetGlobalAchievementPercentagesForApp (ISteamUserStats, v2)

struct GlobalPercentagesEnvelope: Decodable {
    let achievementpercentages: GlobalPercentagesDTO?
}

struct GlobalPercentagesDTO: Decodable {
    let achievements: [GlobalPercentDTO]
}

struct GlobalPercentDTO: Decodable {
    let name: String
    let percent: Double

    enum CodingKeys: String, CodingKey {
        case name, percent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        // Steam has historically served this as both a number and a string.
        if let value = try? container.decode(Double.self, forKey: .percent) {
            percent = value
        } else {
            let string = try container.decode(String.self, forKey: .percent)
            percent = Double(string) ?? 0
        }
    }
}
