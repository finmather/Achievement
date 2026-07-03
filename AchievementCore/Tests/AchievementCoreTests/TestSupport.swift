import Foundation
import XCTest
@testable import AchievementCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// UTC gregorian calendar so date math is deterministic on any machine.
let utcCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
    utcCalendar.date(
        from: DateComponents(year: year, month: month, day: day, hour: hour)
    )!
}

func makeGame(
    id: Int = 1,
    name: String = "Game",
    unlocked: Int? = nil,
    total: Int? = nil,
    minutes: Int = 0,
    lastPlayed: Date? = nil
) -> Game {
    Game(
        appID: id,
        name: name,
        playtimeMinutes: minutes,
        lastPlayed: lastPlayed,
        achievements: total.map { AchievementProgress(unlocked: unlocked ?? 0, total: $0) }
    )
}

/// Routes requests to canned responses; records what was requested.
final class MockHTTPClient: HTTPClient, @unchecked Sendable {
    private let lock = NSLock()
    private var _requests: [URLRequest] = []
    let handler: @Sendable (URLRequest) throws -> (Data, Int)

    init(handler: @escaping @Sendable (URLRequest) throws -> (Data, Int)) {
        self.handler = handler
    }

    var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return _requests
    }

    // Kept synchronous: NSLock must not be held across suspension points,
    // and Swift flags direct lock()/unlock() inside async functions.
    private func record(_ request: URLRequest) {
        lock.lock()
        defer { lock.unlock() }
        _requests.append(request)
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        record(request)
        let (data, status) = try handler(request)
        let response = HTTPURLResponse(
            url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil
        )!
        return (data, response)
    }
}

func queryItems(of request: URLRequest) -> [String: String] {
    guard let url = request.url,
          let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
    else { return [:] }
    return Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { a, _ in a })
}

func uniqueTempDirectory() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("AchievementCoreTests-\(UUID().uuidString)")
}
