import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Minimal transport abstraction so the Steam client can be exercised in
/// tests without touching the network.
public protocol HTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SteamWebAPIError.invalidResponse
        }
        return (data, http)
    }
}
