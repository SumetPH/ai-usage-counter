import XCTest
@testable import MacAiUsageCore

final class LiveAntigravityIntegrationTests: XCTestCase {
    func testLiveAntigravityReturnsModelQuotasWhenOptedIn() async throws {
        guard ProcessInfo.processInfo.environment["MAC_AI_USAGE_ANTIGRAVITY_LIVE_TEST"] == "1" else {
            throw XCTSkip("Set MAC_AI_USAGE_ANTIGRAVITY_LIVE_TEST=1 to query the connected Antigravity account.")
        }

        let snapshot = try await AntigravityProvider().fetchSnapshot()

        XCTAssertEqual(snapshot.providerID, .antigravity)
        XCTAssertFalse(snapshot.quotas.isEmpty)
        XCTAssertTrue(snapshot.quotas.allSatisfy { ["claude", "gemini"].contains($0.id) })
    }
}
