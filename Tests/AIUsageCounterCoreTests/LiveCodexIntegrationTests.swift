import XCTest
@testable import AIUsageCounterCore

final class LiveCodexIntegrationTests: XCTestCase {
    func testLiveCodexReturnsTwoNormalizedWindowsWhenOptedIn() async throws {
        guard ProcessInfo.processInfo.environment["AI_USAGE_COUNTER_LIVE_TEST"] == "1" else {
            throw XCTSkip("Set AI_USAGE_COUNTER_LIVE_TEST=1 to query the locally authenticated Codex session.")
        }

        let provider = CodexAppServerProvider()
        defer { Task { await provider.shutdown() } }
        let snapshot = try await provider.fetchSnapshot()

        XCTAssertLessThan(snapshot.hourly.durationMinutes ?? .max, snapshot.weekly.durationMinutes ?? .min)
        XCTAssertTrue((0...100).contains(snapshot.hourly.remainingPercent))
        XCTAssertTrue((0...100).contains(snapshot.weekly.remainingPercent))
    }
}
