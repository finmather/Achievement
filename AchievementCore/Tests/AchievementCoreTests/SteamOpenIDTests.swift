import XCTest
@testable import AchievementCore

final class SteamOpenIDTests: XCTestCase {
    private let returnTo = URL(string: "https://achievement.app/auth/steam")!
    private let realm = URL(string: "https://achievement.app")!

    private func callbackURL(
        claimedID: String = "https://steamcommunity.com/openid/id/76561197984231774",
        includeSig: Bool = true
    ) -> URL {
        var components = URLComponents(url: returnTo, resolvingAgainstBaseURL: false)!
        var items = [
            URLQueryItem(name: "openid.ns", value: "http://specs.openid.net/auth/2.0"),
            URLQueryItem(name: "openid.mode", value: "id_res"),
            URLQueryItem(name: "openid.op_endpoint", value: "https://steamcommunity.com/openid/login"),
            URLQueryItem(name: "openid.claimed_id", value: claimedID),
            URLQueryItem(name: "openid.identity", value: claimedID),
            URLQueryItem(name: "openid.return_to", value: returnTo.absoluteString),
            URLQueryItem(name: "openid.response_nonce", value: "2026-07-03T10:00:00Zunique"),
            URLQueryItem(name: "openid.assoc_handle", value: "1234567890"),
            URLQueryItem(name: "openid.signed", value: "signed,op_endpoint,claimed_id,identity,return_to,response_nonce,assoc_handle"),
            URLQueryItem(name: "irrelevant", value: "dropme"),
        ]
        if includeSig {
            items.append(URLQueryItem(name: "openid.sig", value: "W0e6EO39QBHmb2GiZzw1mVOqcVo="))
        }
        components.queryItems = items
        return components.url!
    }

    func testAuthenticationURLCarriesRequiredOpenIDParameters() {
        let url = SteamOpenID.authenticationURL(returnTo: returnTo, realm: realm)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            .queryItems!
            .reduce(into: [String: String]()) { $0[$1.name] = $1.value }

        XCTAssertEqual(url.host, "steamcommunity.com")
        XCTAssertEqual(url.path, "/openid/login")
        XCTAssertEqual(items["openid.mode"], "checkid_setup")
        XCTAssertEqual(items["openid.return_to"], returnTo.absoluteString)
        XCTAssertEqual(items["openid.realm"], realm.absoluteString)
        XCTAssertEqual(items["openid.claimed_id"], "http://specs.openid.net/auth/2.0/identifier_select")
    }

    func testCallbackDetectionMatchesSchemeHostAndPath() {
        XCTAssertTrue(SteamOpenID.isCallback(callbackURL(), returnTo: returnTo))
        XCTAssertFalse(SteamOpenID.isCallback(
            URL(string: "https://steamcommunity.com/openid/login?x=1")!,
            returnTo: returnTo
        ))
    }

    func testSteamIDExtractedFromClaimedID() {
        XCTAssertEqual(
            SteamOpenID.steamID(fromCallback: callbackURL())?.rawValue,
            76_561_197_984_231_774
        )
    }

    func testSpoofedClaimedIDHostsAreRejected() {
        for hostile in [
            "https://steamcommunity.com.evil.com/openid/id/76561197984231774",
            "https://evilsteamcommunity.com/openid/id/76561197984231774",
            "https://steamcommunity.com/other/id/76561197984231774",
        ] {
            XCTAssertNil(
                SteamOpenID.steamID(fromCallback: callbackURL(claimedID: hostile)),
                "should reject \(hostile)"
            )
        }
    }

    func testVerificationRequestSwapsModeAndKeepsOnlyOpenIDParams() throws {
        let request = try XCTUnwrap(SteamOpenID.verificationRequest(fromCallback: callbackURL()))
        let body = String(data: try XCTUnwrap(request.httpBody), encoding: .utf8)!

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url, SteamOpenID.endpoint)
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Content-Type"),
            "application/x-www-form-urlencoded"
        )
        XCTAssertTrue(body.contains("openid.mode=check_authentication"))
        XCTAssertFalse(body.contains("id_res"))
        XCTAssertTrue(body.contains("openid.sig=W0e6EO39QBHmb2GiZzw1mVOqcVo%3D"))
        XCTAssertFalse(body.contains("irrelevant"))
    }

    func testVerificationRequestRequiresSignature() {
        XCTAssertNil(SteamOpenID.verificationRequest(fromCallback: callbackURL(includeSig: false)))
    }

    func testPositiveVerificationParsing() {
        XCTAssertTrue(SteamOpenID.isPositiveVerification(
            "ns:http://specs.openid.net/auth/2.0\nis_valid:true\n"
        ))
        XCTAssertFalse(SteamOpenID.isPositiveVerification(
            "ns:http://specs.openid.net/auth/2.0\nis_valid:false\n"
        ))
        XCTAssertFalse(SteamOpenID.isPositiveVerification("garbage"))
    }

    func testFormEncodingEscapesReservedCharacters() {
        let encoded = SteamOpenID.formEncoded([
            URLQueryItem(name: "a b", value: "c+d=e&f"),
        ])
        XCTAssertEqual(encoded, "a%20b=c%2Bd%3De%26f")
    }

    func testAuthenticatorAcceptsValidAssertion() async throws {
        let http = MockHTTPClient { _ in
            (Data("ns:http://specs.openid.net/auth/2.0\nis_valid:true\n".utf8), 200)
        }
        let id = try await SteamAuthenticator(httpClient: http)
            .validateCallback(callbackURL())
        XCTAssertEqual(id.rawValue, 76_561_197_984_231_774)
    }

    func testAuthenticatorRejectsNegativeAssertion() async {
        let http = MockHTTPClient { _ in (Data("is_valid:false\n".utf8), 200) }
        do {
            _ = try await SteamAuthenticator(httpClient: http).validateCallback(callbackURL())
            XCTFail("expected verificationFailed")
        } catch {
            XCTAssertEqual(error as? SteamAuthError, .verificationFailed)
        }
    }
}
