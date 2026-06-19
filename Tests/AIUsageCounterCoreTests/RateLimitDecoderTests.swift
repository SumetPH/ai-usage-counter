import XCTest
@testable import AIUsageCounterCore

final class RateLimitDecoderTests: XCTestCase {
    func testDecodesAndOrdersWindowsByDuration() throws {
        let data = Data(#"{"id":2,"result":{"rateLimits":{"primary":{"usedPercent":28,"windowDurationMins":10080,"resetsAt":2000000000},"secondary":{"usedPercent":36,"windowDurationMins":300,"resetsAt":1900000000},"futureField":"ignored"}}}"#.utf8)

        let snapshot = try RateLimitDecoder.decodeResponse(data, now: Date(timeIntervalSince1970: 1_800_000_000))

        XCTAssertEqual(snapshot.hourly.remainingPercent, 64)
        XCTAssertEqual(snapshot.hourly.durationMinutes, 300)
        XCTAssertEqual(snapshot.weekly.remainingPercent, 72)
        XCTAssertEqual(snapshot.weekly.durationMinutes, 10_080)
    }

    func testPrefersCodexNamedBucketAndClampsUsage() throws {
        let data = Data(#"{"id":2,"result":{"rateLimits":{"primary":null,"secondary":null},"rateLimitsByLimitId":{"other":{"primary":null},"codex":{"primary":{"usedPercent":-10,"windowDurationMins":300,"resetsAt":null},"secondary":{"usedPercent":140,"windowDurationMins":10080,"resetsAt":null}}}}}"#.utf8)

        let snapshot = try RateLimitDecoder.decodeResponse(data)

        XCTAssertEqual(snapshot.hourly.remainingPercent, 100)
        XCTAssertEqual(snapshot.weekly.remainingPercent, 0)
        XCTAssertNil(snapshot.hourly.resetsAt)
    }

    func testRejectsMissingWindowWithoutInventingValues() {
        let data = Data(#"{"id":2,"result":{"rateLimits":{"primary":{"usedPercent":20,"windowDurationMins":300}}}}"#.utf8)

        XCTAssertThrowsError(try RateLimitDecoder.decodeResponse(data)) { error in
            XCTAssertEqual(error as? UsageProviderError, .missingRateLimitWindows)
        }
    }

    func testMapsAuthenticationErrors() {
        let data = Data(#"{"id":2,"error":{"code":401,"message":"Not authenticated; login required"}}"#.utf8)

        XCTAssertThrowsError(try RateLimitDecoder.decodeResponse(data)) { error in
            XCTAssertEqual(error as? UsageProviderError, .notAuthenticated)
        }
    }

    func testDecodesRollingUpdate() throws {
        let data = Data(#"{"method":"account/rateLimits/updated","params":{"rateLimits":{"primary":{"usedPercent":5,"windowDurationMins":300,"resetsAt":2000000000},"secondary":{"usedPercent":15,"windowDurationMins":10080,"resetsAt":2100000000}}}}"#.utf8)

        let snapshot = try RateLimitDecoder.decodeUpdate(data)

        XCTAssertEqual(snapshot.hourly.remainingPercent, 95)
        XCTAssertEqual(snapshot.weekly.remainingPercent, 85)
    }
}
