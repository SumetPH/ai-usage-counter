import XCTest
@testable import MacAiUsageCore

final class AntigravityOAuthTests: XCTestCase {
    func testAuthorizationURLUsesPKCEAndOfflineConsent() throws {
        let url = AntigravityOAuth.authorizationURL(redirectURI: "http://127.0.0.1:51121/oauth-callback", state: "state", verifier: "verifier")
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let values = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value) })

        XCTAssertEqual(values["state"], "state")
        XCTAssertEqual(values["code_challenge_method"], "S256")
        XCTAssertEqual(values["access_type"], "offline")
        XCTAssertEqual(values["prompt"], "consent")
        XCTAssertNotEqual(values["code_challenge"], "verifier")
    }
}
