import XCTest
@testable import AIUsageCounterCore

@MainActor
final class ProviderUsageMonitorTests: XCTestCase {
    func testRefreshPublishesDynamicSnapshotAndPreservesItAfterFailure() async {
        let now = Date(timeIntervalSince1970: 1_000)
        let snapshot = ProviderSnapshot(
            providerID: .antigravity,
            quotas: [UsageQuota(id: "gemini", name: "Gemini", remainingPercent: 40, resetsAt: nil)],
            fetchedAt: now
        )
        let provider = FakeDynamicProvider(results: [.success(snapshot), .failure(UsageProviderError.timedOut)])
        let monitor = ProviderUsageMonitor(
            provider: provider,
            cache: MemoryProviderUsageCache(),
            clock: FixedUsageClock(now: now),
            schedulingEnabled: false
        )

        await monitor.refreshAndWait(.manual)
        XCTAssertEqual(monitor.snapshot, snapshot)
        XCTAssertEqual(monitor.connectionState, .connected)
        XCTAssertEqual(monitor.menuBarText(preferredQuotaID: "gemini"), "40%")

        await monitor.refreshAndWait(.manual)
        XCTAssertEqual(monitor.snapshot, snapshot)
        XCTAssertEqual(monitor.connectionState, .failed)
    }
}

private actor FakeDynamicProvider: ProviderUsageProviding {
    let providerID: UsageProviderID = .antigravity
    var results: [Result<ProviderSnapshot, Error>]
    init(results: [Result<ProviderSnapshot, Error>]) { self.results = results }
    func fetchSnapshot() async throws -> ProviderSnapshot { try results.removeFirst().get() }
    func shutdown() async {}
}

private struct FixedUsageClock: UsageClock {
    let value: Date
    init(now: Date) { value = now }
    func now() -> Date { value }
    func sleep(for seconds: TimeInterval) async throws { try await Task.sleep(for: .seconds(seconds)) }
}
