import XCTest
@testable import AIUsageCounterCore

final class LiveAntigravityIntegrationTests: XCTestCase {
    func testLiveAntigravityReturnsModelQuotasWhenOptedIn() async throws {
        guard ProcessInfo.processInfo.environment["AI_USAGE_COUNTER_ANTIGRAVITY_LIVE_TEST"] == "1" else {
            throw XCTSkip("Set AI_USAGE_COUNTER_ANTIGRAVITY_LIVE_TEST=1 to query the connected Antigravity account.")
        }

        let snapshot = try await AntigravityProvider().fetchSnapshot()

        XCTAssertEqual(snapshot.providerID, .antigravity)
        XCTAssertFalse(snapshot.quotas.isEmpty)
        XCTAssertTrue(snapshot.quotas.allSatisfy { ["claude", "gemini"].contains($0.id) })
    }
}
