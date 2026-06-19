import XCTest
@testable import AIUsageCounterCore

@MainActor
final class UsageMonitorTests: XCTestCase {
    func testSuccessfulRefreshPublishesMenuAndCachesSnapshot() async {
        let clock = TestClock(now: Date(timeIntervalSince1970: 1_000))
        let expected = makeSnapshot(now: clock.now())
        let provider = FakeProvider(results: [.success(expected)])
        let cache = MemoryUsageCache()
        let monitor = UsageMonitor(provider: provider, cache: cache, clock: clock, schedulingEnabled: false)

        await monitor.refreshAndWait(.manual)

        XCTAssertEqual(monitor.connectionState, .connected)
        XCTAssertEqual(monitor.menuBarText, "64% | 72%")
        XCTAssertEqual(cache.load(), expected)
        XCTAssertFalse(monitor.isStale)
    }

    func testFailurePreservesLastSnapshotAndReportsUnavailableCodex() async {
        let clock = TestClock(now: Date(timeIntervalSince1970: 1_000))
        let cached = makeSnapshot(now: clock.now())
        let provider = FakeProvider(results: [.failure(UsageProviderError.executableNotFound)])
        let monitor = UsageMonitor(provider: provider, cache: MemoryUsageCache(snapshot: cached), clock: clock, schedulingEnabled: false)
        monitor.start()
        await provider.waitForFetch()
        await Task.yield()

        XCTAssertEqual(monitor.snapshot, cached)
        XCTAssertEqual(monitor.connectionState, .codexUnavailable)
        XCTAssertTrue(monitor.isStale)
    }

    func testExhaustedWindowTransitionsFromCountdownToCheckingToUnavailable() async {
        let base = Date(timeIntervalSince1970: 1_000)
        let clock = TestClock(now: base)
        let exhausted = UsageSnapshot(
            hourly: QuotaWindow(remainingPercent: 0, resetsAt: base.addingTimeInterval(90), durationMinutes: 300),
            weekly: QuotaWindow(remainingPercent: 72, resetsAt: base.addingTimeInterval(500_000), durationMinutes: 10_080),
            fetchedAt: base
        )
        let provider = FakeProvider(results: [.success(exhausted), .failure(UsageProviderError.timedOut)])
        let monitor = UsageMonitor(provider: provider, cache: MemoryUsageCache(), clock: clock, schedulingEnabled: false)

        await monitor.refreshAndWait(.manual)
        XCTAssertEqual(monitor.displayValue(for: .hourly), "2m")

        clock.advance(91)
        monitor.tick()
        await provider.waitForFetch(count: 2)
        await Task.yield()

        XCTAssertEqual(monitor.displayValue(for: .hourly), "—")
        XCTAssertEqual(monitor.displayValue(for: .weekly), "72%")
        XCTAssertEqual(monitor.refreshState, .failed)
    }

    func testRefreshesCoalesce() async {
        let clock = TestClock(now: Date())
        let gate = AsyncGate()
        let provider = FakeProvider(results: [.success(makeSnapshot(now: clock.now()))], gate: gate)
        let monitor = UsageMonitor(provider: provider, cache: MemoryUsageCache(), clock: clock, schedulingEnabled: false)

        async let first: Void = monitor.refreshAndWait(.manual)
        async let second: Void = monitor.refreshAndWait(.popupOpened)
        await Task.yield()
        await gate.open()
        _ = await (first, second)

        let fetchCount = await provider.currentFetchCount()
        XCTAssertEqual(fetchCount, 1)
    }

    func testCountdownFormatting() {
        XCTAssertEqual(UsageMonitor.formatCountdown(30), "1m")
        XCTAssertEqual(UsageMonitor.formatCountdown(5_040), "1h 24m")
        XCTAssertEqual(UsageMonitor.formatCountdown(190_800), "2d 5h")
    }
}

private func makeSnapshot(now: Date) -> UsageSnapshot {
    UsageSnapshot(
        hourly: QuotaWindow(remainingPercent: 64, resetsAt: now.addingTimeInterval(6_000), durationMinutes: 300),
        weekly: QuotaWindow(remainingPercent: 72, resetsAt: now.addingTimeInterval(500_000), durationMinutes: 10_080),
        fetchedAt: now
    )
}

private actor FakeProvider: UsageProviding {
    private var results: [Result<UsageSnapshot, Error>]
    private let gate: AsyncGate?
    private(set) var fetchCount = 0

    init(results: [Result<UsageSnapshot, Error>], gate: AsyncGate? = nil) {
        self.results = results
        self.gate = gate
    }

    func fetchSnapshot() async throws -> UsageSnapshot {
        fetchCount += 1
        if let gate { await gate.wait() }
        guard !results.isEmpty else { throw UsageProviderError.transportClosed }
        return try results.removeFirst().get()
    }

    func updates() async -> AsyncStream<UsageSnapshot> {
        AsyncStream { _ in }
    }

    func shutdown() async {}

    func waitForFetch(count: Int = 1) async {
        while fetchCount < count { await Task.yield() }
    }

    func currentFetchCount() -> Int { fetchCount }
}

private actor AsyncGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }
}

private final class TestClock: UsageClock, @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date

    init(now: Date) { value = now }

    func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func sleep(for seconds: TimeInterval) async throws {
        try await Task.sleep(for: .seconds(seconds))
    }

    func advance(_ seconds: TimeInterval) {
        lock.lock()
        value = value.addingTimeInterval(seconds)
        lock.unlock()
    }
}
