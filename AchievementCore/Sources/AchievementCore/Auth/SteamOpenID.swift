import Foundation

/// Pure helpers for Steam's OpenID 2.0 sign-in flow — URL construction,
/// callback parsing, and building the `check_authentication` verification
/// round-trip. Nothing here touches the network; see `SteamAuthenticator`.
public enum SteamOpenID {
    public static let endpoint = URL(string: "https://steamcommunity.com/openid/login")!
    private static let ns = "http://specs.openid.net/auth/2.0"
    private static let identifierSelect = "http://specs.openid.net/auth/2.0/identifier_select"

    /// The URL to load in the sign-in web view.
    ///
    /// `returnTo` doesn't need to resolve — the web view intercepts the
    /// redirect before it loads (see `SteamSignInView` in the app target).
    public static func authenticationURL(returnTo: URL, realm: URL) -> URL {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "openid.ns", value: ns),
            URLQueryItem(name: "openid.mode", value: "checkid_setup"),
            URLQueryItem(name: "openid.claimed_id", value: identifierSelect),
            URLQueryItem(name: "openid.identity", value: identifierSelect),
            URLQueryItem(name: "openid.return_to", value: returnTo.absoluteString),
            URLQueryItem(name: "openid.realm", value: realm.absoluteString),
        ]
        return components.url!
    }

    /// Whether a navigation target is the `return_to` redirect.
    public static func isCallback(_ url: URL, returnTo: URL) -> Bool {
        url.scheme?.lowercased() == returnTo.scheme?.lowercased()
            && url.host?.lowercased() == returnTo.host?.lowercased()
            && url.path == returnTo.path
    }

    /// Extracts the SteamID from a positive-assertion callback. This alone is
    /// **not** proof of identity — always follow with `verificationRequest`.
    public static func steamID(fromCallback url: URL) -> SteamID? {
        guard
            let claimed = queryValue("openid.claimed_id", in: url),
            let claimedURL = URL(string: claimed),
            let host = claimedURL.host?.lowercased(),
            host == "steamcommunity.com" || host.hasSuffix(".steamcommunity.com"),
            claimedURL.path.hasPrefix("/openid/id/")
        else { return nil }
        return SteamID(string: claimedURL.lastPathComponent)
    }

    /// Builds the `check_authentication` POST that asks Steam to confirm the
    /// assertion's signature. Returns `nil` for callbacks that can't possibly
    /// verify (missing signature or mode).
    public static func verificationRequest(fromCallback url: URL) -> URLRequest? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems else { return nil }

        var params = items.filter { $0.name.hasPrefix("openid.") }
        guard params.contains(where: { $0.name == "openid.sig" }),
              params.contains(where: { $0.name == "openid.mode" }) else { return nil }
        params = params.map {
            $0.name == "openid.mode"
                ? URLQueryItem(name: "openid.mode", value: "check_authentication")
                : $0
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(
            "application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type"
        )
        request.httpBody = formEncoded(params).data(using: .utf8)
        return request
    }

    /// Parses Steam's key-value verification response for `is_valid:true`.
    public static func isPositiveVerification(_ responseBody: String) -> Bool {
        responseBody.split(whereSeparator: \.isNewline).contains { line in
            let parts = line.split(separator: ":", maxSplits: 1)
            return parts.count == 2
                && parts[0].trimmingCharacters(in: .whitespaces) == "is_valid"
                && parts[1].trimmingCharacters(in: .whitespaces) == "true"
        }
    }

    // MARK: - Internals

    private static func queryValue(_ name: String, in url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == name }?
            .value
    }

    static func formEncoded(_ items: [URLQueryItem]) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return items
            .map { item in
                let name = item.name.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
                let value = (item.value ?? "")
                    .addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
                return "\(name)=\(value)"
            }
            .joined(separator: "&")
    }
}

public enum SteamAuthError: Error, Equatable, Sendable {
    case malformedCallback
    case verificationFailed
}

extension SteamAuthError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .malformedCallback: "Steam returned an unexpected sign-in response."
        case .verificationFailed: "Steam couldn't verify the sign-in. Please try again."
        }
    }
}

/// Completes the OpenID flow over the network: extract the SteamID from the
/// callback, then have Steam confirm the assertion is genuine.
public struct SteamAuthenticator: Sendable {
    private let httpClient: any HTTPClient

    public init(httpClient: any HTTPClient = URLSessionHTTPClient()) {
        self.httpClient = httpClient
    }

    public func validateCallback(_ url: URL) async throws -> SteamID {
        guard let steamID = SteamOpenID.steamID(fromCallback: url),
              let request = SteamOpenID.verificationRequest(fromCallback: url) else {
            throw SteamAuthError.malformedCallback
        }
        let (data, response) = try await httpClient.data(for: request)
        guard response.statusCode == 200,
              let body = String(data: data, encoding: .utf8),
              SteamOpenID.isPositiveVerification(body) else {
            throw SteamAuthError.verificationFailed
        }
        return steamID
    }
}
