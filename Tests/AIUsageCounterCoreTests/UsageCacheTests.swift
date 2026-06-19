import XCTest
@testable import AIUsageCounterCore

final class UsageCacheTests: XCTestCase {
    func testRoundTripsOnlyNormalizedSnapshot() throws {
        let suite = "UsageCacheTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let cache = UserDefaultsUsageCache(defaults: defaults)
        let snapshot = UsageSnapshot(
            hourly: QuotaWindow(remainingPercent: 40, resetsAt: Date(timeIntervalSince1970: 2_000), durationMinutes: 300),
            weekly: QuotaWindow(remainingPercent: 70, resetsAt: Date(timeIntervalSince1970: 3_000), durationMinutes: 10_080),
            fetchedAt: Date(timeIntervalSince1970: 1_000)
        )

        cache.save(snapshot)

        XCTAssertEqual(cache.load(), snapshot)
        let data = try XCTUnwrap(defaults.data(forKey: "normalizedUsageSnapshot"))
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(text.localizedCaseInsensitiveContains("token"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("account"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("credential"))
    }

    func testCorruptCacheIsIgnoredAndRemoved() throws {
        let suite = "UsageCacheTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("not-json".utf8), forKey: "normalizedUsageSnapshot")
        let cache = UserDefaultsUsageCache(defaults: defaults)

        XCTAssertNil(cache.load())
        XCTAssertNil(defaults.data(forKey: "normalizedUsageSnapshot"))
    }
}
