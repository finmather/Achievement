import XCTest
@testable import AchievementCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// Canned Steam responses. Kept as raw fixtures so decoding is tested against
// the wire shape, quirks included (IDs as strings, percent as string).
private enum Fixture {
    static let ownedGames = """
    {"response":{"game_count":2,"games":[
      {"appid":620,"name":"Portal 2","playtime_forever":1338,"img_icon_url":"abc123","rtime_last_played":1700000000},
      {"appid":105600,"name":"Terraria","playtime_forever":0}
    ]}}
    """

    static let playerSummaries = """
    {"response":{"players":[{
      "steamid":"76561197984231774","personaname":"Fin",
      "profileurl":"https://steamcommunity.com/id/fin/",
      "avatarmedium":"https://avatars.example/m.jpg",
      "avatarfull":"https://avatars.example/f.jpg",
      "communityvisibilitystate":3,"timecreated":1357000000,"loccountrycode":"AU"
    }]}}
    """

    static let schema = """
    {"game":{"gameName":"Portal 2","availableGameStats":{"achievements":[
      {"name":"ACH_ONE","defaultvalue":0,"displayName":"First Steps","hidden":0,
       "description":"Do the first thing.","icon":"https://cdn.example/a.jpg","icongray":"https://cdn.example/a_gray.jpg"},
      {"name":"ACH_TWO","displayName":"Hidden Depths","hidden":1,
       "icon":"https://cdn.example/b.jpg","icongray":"https://cdn.example/b_gray.jpg"}
    ]}}}
    """

    static let playerAchievements = """
    {"playerstats":{"steamID":"76561197984231774","gameName":"Portal 2","success":true,
     "achievements":[
      {"apiname":"ACH_ONE","achieved":1,"unlocktime":1600000000},
      {"apiname":"ACH_TWO","achieved":0,"unlocktime":0}
    ]}}
    """

    static let globalPercentages = """
    {"achievementpercentages":{"achievements":[
      {"name":"ACH_ONE","percent":62.5},
      {"name":"ACH_TWO","percent":"3.4"}
    ]}}
    """

    static let privateProfile = """
    {"playerstats":{"error":"Profile is not public","success":false}}
    """

    static let noStats = """
    {"playerstats":{"error":"Requested app has no stats","success":false}}
    """

    static let friendList = """
    {"friendslist":{"friends":[
      {"steamid":"76561197984231775","relationship":"friend","friend_since":1400000000},
      {"steamid":"76561197984231776","relationship":"friend","friend_since":1500000000}
    ]}}
    """
}

private let player = SteamID(rawValue: 76_561_197_984_231_774)!

/// Standard happy-path router keyed on the API method in the URL path.
private func routedClient(
    playerAchievements: (String, Int) = (Fixture.playerAchievements, 200)
) -> SteamWebAPIClient {
    let http = MockHTTPClient { request in
        let path = request.url!.path
        if path.contains("GetOwnedGames") { return (Data(Fixture.ownedGames.utf8), 200) }
        if path.contains("GetPlayerSummaries") { return (Data(Fixture.playerSummaries.utf8), 200) }
        if path.contains("GetSchemaForGame") { return (Data(Fixture.schema.utf8), 200) }
        if path.contains("GetPlayerAchievements") {
            return (Data(playerAchievements.0.utf8), playerAchievements.1)
        }
        if path.contains("GetGlobalAchievementPercentagesForApp") {
            return (Data(Fixture.globalPercentages.utf8), 200)
        }
        if path.contains("GetFriendList") { return (Data(Fixture.friendList.utf8), 200) }
        return (Data(), 404)
    }
    return SteamWebAPIClient(apiKey: "TESTKEY", httpClient: http)
}

final class SteamWebAPIClientTests: XCTestCase {
    func testOwnedGamesMapsWireFieldsToDomain() async throws {
        let games = try await routedClient().ownedGames(of: player)

        XCTAssertEqual(games.count, 2)
        XCTAssertEqual(games[0].appID, 620)
        XCTAssertEqual(games[0].name, "Portal 2")
        XCTAssertEqual(games[0].playtimeMinutes, 1338)
        XCTAssertEqual(games[0].iconHash, "abc123")
        XCTAssertEqual(games[0].lastPlayed, Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertNil(games[0].achievements, "progress arrives via hydration, not GetOwnedGames")
        XCTAssertNil(games[1].lastPlayed)
    }

    func testProfileMapsSummaryFields() async throws {
        let profile = try await routedClient().profile(for: player)

        XCTAssertEqual(profile.id, player)
        XCTAssertEqual(profile.personaName, "Fin")
        XCTAssertEqual(profile.countryCode, "AU")
        XCTAssertTrue(profile.isPublic)
        XCTAssertEqual(profile.avatarFullURL?.absoluteString, "https://avatars.example/f.jpg")
    }

    func testFriendIDsParse() async throws {
        let ids = try await routedClient().friendIDs(of: player)
        XCTAssertEqual(ids.map(\.rawValue), [76_561_197_984_231_775, 76_561_197_984_231_776])
    }

    func testAchievementsMergeSchemaPlayerStateAndRarity() async throws {
        let achievements = try await routedClient().achievements(appID: 620, player: player)

        XCTAssertEqual(achievements.count, 2)

        let first = achievements[0]
        XCTAssertEqual(first.id, "ACH_ONE")
        XCTAssertEqual(first.displayName, "First Steps")
        XCTAssertTrue(first.isUnlocked)
        XCTAssertEqual(first.unlockedAt, Date(timeIntervalSince1970: 1_600_000_000))
        XCTAssertEqual(first.globalPercent, 62.5)
        XCTAssertEqual(first.rarity, .common)
        XCTAssertFalse(first.isHidden)

        let second = achievements[1]
        XCTAssertFalse(second.isUnlocked)
        XCTAssertNil(second.unlockedAt, "unlocktime 0 must not become a 1970 date")
        XCTAssertTrue(second.isHidden)
        XCTAssertEqual(second.globalPercent, 3.4, "string percents must decode")
        XCTAssertEqual(second.rarity, .veryRare)
    }

    func testPrivateProfileSurfacesAsTypedError() async {
        let client = routedClient(playerAchievements: (Fixture.privateProfile, 403))
        do {
            _ = try await client.achievements(appID: 620, player: player)
            XCTFail("expected profilePrivate")
        } catch {
            XCTAssertEqual(error as? SteamWebAPIError, .profilePrivate)
        }
    }

    func testAppWithoutStatsSurfacesAsNoAchievements() async {
        // Schema comes back empty for stats-less apps.
        let http = MockHTTPClient { request in
            let path = request.url!.path
            if path.contains("GetSchemaForGame") { return (Data("{\"game\":{}}".utf8), 200) }
            if path.contains("GetPlayerAchievements") { return (Data(Fixture.noStats.utf8), 400) }
            return (Data("{\"achievementpercentages\":{\"achievements\":[]}}".utf8), 200)
        }
        let client = SteamWebAPIClient(apiKey: "TESTKEY", httpClient: http)
        do {
            _ = try await client.achievements(appID: 999, player: player)
            XCTFail("expected noAchievements")
        } catch {
            XCTAssertEqual(error as? SteamWebAPIError, .noAchievements)
        }
    }

    func testMissingAPIKeyFailsFastWithoutNetworkCall() async {
        let http = MockHTTPClient { _ in
            XCTFail("no request should be issued without a key")
            return (Data(), 500)
        }
        let client = SteamWebAPIClient(apiKey: "  ", httpClient: http)
        do {
            _ = try await client.ownedGames(of: player)
            XCTFail("expected missingAPIKey")
        } catch {
            XCTAssertEqual(error as? SteamWebAPIError, .missingAPIKey)
        }
    }

    func testRateLimitMapsToTypedError() async {
        let http = MockHTTPClient { _ in (Data(), 429) }
        let client = SteamWebAPIClient(apiKey: "TESTKEY", httpClient: http)
        do {
            _ = try await client.ownedGames(of: player)
            XCTFail("expected rateLimited")
        } catch {
            XCTAssertEqual(error as? SteamWebAPIError, .rateLimited)
        }
    }

    func testGlobalPercentagesEndpointOmitsAPIKey() async throws {
        let http = MockHTTPClient { request in
            XCTAssertNil(
                queryItems(of: request)["key"],
                "global percentages is a public endpoint; never leak the key"
            )
            return (Data(Fixture.globalPercentages.utf8), 200)
        }
        let client = SteamWebAPIClient(apiKey: "TESTKEY", httpClient: http)
        _ = try await client.globalPercentages(appID: 620)
    }
}
