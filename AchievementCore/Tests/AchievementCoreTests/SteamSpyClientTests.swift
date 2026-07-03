import XCTest
@testable import AchievementCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class SteamSpyClientTests: XCTestCase {
    func testTagsSortedByVotesThenName() async throws {
        let body = """
        {"appid":1145360,"name":"Hades","tags":{"Roguelike":500,"Action":900,"Indie":500}}
        """
        let http = MockHTTPClient { request in
            let query = queryItems(of: request)
            XCTAssertEqual(request.url?.host, "steamspy.com")
            XCTAssertEqual(query["request"], "appdetails")
            XCTAssertEqual(query["appid"], "1145360")
            return (Data(body.utf8), 200)
        }
        let tags = try await SteamSpyClient(httpClient: http).tags(appID: 1145360)
        XCTAssertEqual(tags, ["Action", "Indie", "Roguelike"])
    }

    func testEmptyArrayTagsDecodeAsNoTags() async throws {
        // SteamSpy sends [] instead of {} for apps without tag data.
        let http = MockHTTPClient { _ in
            (Data("{\"appid\":999,\"name\":\"Untagged\",\"tags\":[]}".utf8), 200)
        }
        let tags = try await SteamSpyClient(httpClient: http).tags(appID: 999)
        XCTAssertEqual(tags, [])
    }

    func testRateLimitAndServerErrorsAreTyped() async {
        let rateLimited = SteamSpyClient(httpClient: MockHTTPClient { _ in (Data(), 429) })
        do {
            _ = try await rateLimited.tags(appID: 1)
            XCTFail("expected rateLimited")
        } catch {
            XCTAssertEqual(error as? SteamWebAPIError, .rateLimited)
        }

        let broken = SteamSpyClient(httpClient: MockHTTPClient { _ in (Data(), 500) })
        do {
            _ = try await broken.tags(appID: 1)
            XCTFail("expected httpStatus")
        } catch {
            XCTAssertEqual(error as? SteamWebAPIError, .httpStatus(500))
        }
    }

    func testGenreTagsCacheRoundTrip() async {
        let directory = uniqueTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = LibraryCache(directory: directory)

        let before = await cache.genreTags()
        XCTAssertNil(before)

        await cache.storeGenreTags([620: ["Puzzle", "FPS"], 1145360: []])
        let loaded = await cache.genreTags()
        XCTAssertEqual(loaded?[620], ["Puzzle", "FPS"])
        XCTAssertEqual(loaded?[1145360], [], "fetched-but-empty must persist to avoid refetching")
    }
}
