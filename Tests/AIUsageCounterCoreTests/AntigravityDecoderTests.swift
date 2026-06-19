import XCTest
@testable import AIUsageCounterCore

final class AntigravityDecoderTests: XCTestCase {
    func testGroupsModelsByFamilyUsingTheLowestRemainingQuota() throws {
        let data = Data(#"""
        {
          "models": {
            "gemini-3-pro-high": {
              "displayName": "Gemini 3 Pro (High)",
              "quotaInfo": {"remainingFraction": 0.42, "resetTime": "2026-06-20T03:30:00Z"}
            },
            "gemini-3-flash": {
              "displayName": "Gemini 3 Flash",
              "quotaInfo": {"remainingFraction": 0.75, "resetTime": "2026-06-20T04:30:00Z"}
            },
            "claude-sonnet": {
              "displayName": "Claude Sonnet",
              "quotaInfo": {"remainingFraction": 1}
            },
            "claude-opus": {
              "displayName": "Claude Opus",
              "quotaInfo": {"remainingFraction": 0.60}
            }
          }
        }
        """#.utf8)

        let snapshot = try AntigravityQuotaDecoder.decode(data, now: Date(timeIntervalSince1970: 1_000))

        XCTAssertEqual(snapshot.providerID, .antigravity)
        XCTAssertEqual(snapshot.quotas.map(\.name), ["Gemini", "Claude"])
        XCTAssertEqual(snapshot.quotas.first?.remainingPercent, 42)
        XCTAssertEqual(snapshot.quotas.last?.remainingPercent, 60)
        XCTAssertEqual(snapshot.quotas.first?.resetsAt, ISO8601DateFormatter().date(from: "2026-06-20T03:30:00Z"))
    }
}
