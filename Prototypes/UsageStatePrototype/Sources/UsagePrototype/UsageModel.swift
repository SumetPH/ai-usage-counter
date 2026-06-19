import Foundation

// PROTOTYPE — This reducer exists to validate quota semantics and reset transitions.

struct QuotaWindow: Equatable {
    var remainingPercent: Int
    var resetsAt: Date?
    var durationMinutes: Int?

    init(remainingPercent: Int, resetsAt: Date?, durationMinutes: Int?) {
        self.remainingPercent = min(100, max(0, remainingPercent))
        self.resetsAt = resetsAt
        self.durationMinutes = durationMinutes
    }
}

struct UsageSnapshot: Equatable {
    var hourly: QuotaWindow
    var weekly: QuotaWindow
    var fetchedAt: Date
    var source: String
}

enum ConnectionState: String {
    case connected
    case disconnected
}

enum RefreshState: String {
    case idle
    case checking
    case failed
}

struct UsageState {
    var now: Date
    var connection: ConnectionState
    var refresh: RefreshState
    var snapshot: UsageSnapshot?
    var lastError: String?

    var isStale: Bool {
        guard let snapshot else { return false }
        return now.timeIntervalSince(snapshot.fetchedAt) > 10 * 60
    }

    var menuBarText: String {
        guard connection == .connected, let snapshot else { return "— | —" }
        return "\(displayValue(snapshot.hourly)) | \(displayValue(snapshot.weekly))"
    }

    func displayValue(_ window: QuotaWindow) -> String {
        if window.remainingPercent > 0 {
            return "\(window.remainingPercent)%"
        }

        guard let reset = window.resetsAt else { return "—" }
        let seconds = reset.timeIntervalSince(now)
        if seconds > 0 { return Self.countdown(seconds) }
        if refresh == .checking { return "…" }
        return "—"
    }

    static func countdown(_ interval: TimeInterval) -> String {
        let totalMinutes = max(1, Int(ceil(interval / 60)))
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let minutes = totalMinutes % 60

        if days > 0 { return hours > 0 ? "\(days)d \(hours)h" : "\(days)d" }
        if hours > 0 { return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h" }
        return "\(minutes)m"
    }
}

enum UsageAction {
    case loadFixture(Fixture)
    case tick(seconds: TimeInterval)
    case refreshStarted
    case refreshSucceeded(UsageSnapshot)
    case refreshFailed(String)
}

enum Fixture: String, CaseIterable {
    case normal
    case hourlyExhausted
    case weeklyExhausted
    case bothExhausted
    case stale
    case disconnected
    case resetRefreshFailure

    func state(now: Date) -> UsageState {
        let hourReset = now.addingTimeInterval(84 * 60)
        let weekReset = now.addingTimeInterval((4 * 24 + 7) * 60 * 60)

        func snapshot(hourly: Int, weekly: Int, fetchedAt: Date? = nil) -> UsageSnapshot {
            UsageSnapshot(
                hourly: QuotaWindow(remainingPercent: hourly, resetsAt: hourReset, durationMinutes: 300),
                weekly: QuotaWindow(remainingPercent: weekly, resetsAt: weekReset, durationMinutes: 10_080),
                fetchedAt: fetchedAt ?? now,
                source: "fixture"
            )
        }

        switch self {
        case .normal:
            return UsageState(now: now, connection: .connected, refresh: .idle, snapshot: snapshot(hourly: 50, weekly: 80), lastError: nil)
        case .hourlyExhausted:
            return UsageState(now: now, connection: .connected, refresh: .idle, snapshot: snapshot(hourly: 0, weekly: 80), lastError: nil)
        case .weeklyExhausted:
            return UsageState(now: now, connection: .connected, refresh: .idle, snapshot: snapshot(hourly: 50, weekly: 0), lastError: nil)
        case .bothExhausted:
            return UsageState(now: now, connection: .connected, refresh: .idle, snapshot: snapshot(hourly: 0, weekly: 0), lastError: nil)
        case .stale:
            return UsageState(now: now, connection: .connected, refresh: .failed, snapshot: snapshot(hourly: 41, weekly: 73, fetchedAt: now.addingTimeInterval(-11 * 60)), lastError: "Refresh failed; preserving last good values")
        case .disconnected:
            return UsageState(now: now, connection: .disconnected, refresh: .idle, snapshot: nil, lastError: "Codex not connected")
        case .resetRefreshFailure:
            let expired = now.addingTimeInterval(-1)
            let value = UsageSnapshot(
                hourly: QuotaWindow(remainingPercent: 0, resetsAt: expired, durationMinutes: 300),
                weekly: QuotaWindow(remainingPercent: 80, resetsAt: weekReset, durationMinutes: 10_080),
                fetchedAt: now.addingTimeInterval(-6 * 60),
                source: "fixture"
            )
            return UsageState(now: now, connection: .connected, refresh: .failed, snapshot: value, lastError: "Reset refresh failed")
        }
    }
}

func reduce(_ state: UsageState, _ action: UsageAction) -> UsageState {
    var next = state
    switch action {
    case .loadFixture(let fixture):
        return fixture.state(now: state.now)
    case .tick(let seconds):
        next.now = next.now.addingTimeInterval(seconds)
    case .refreshStarted:
        next.refresh = .checking
        next.lastError = nil
    case .refreshSucceeded(let snapshot):
        next.connection = .connected
        next.refresh = .idle
        next.snapshot = snapshot
        next.now = snapshot.fetchedAt
        next.lastError = nil
    case .refreshFailed(let message):
        next.refresh = .failed
        next.lastError = message
    }
    return next
}
