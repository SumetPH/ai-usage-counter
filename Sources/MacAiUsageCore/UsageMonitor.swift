import Combine
import Foundation

public enum QuotaKind: Sendable {
    case hourly
    case weekly
}

@MainActor
public final class UsageMonitor: ObservableObject {
    @Published public private(set) var snapshot: UsageSnapshot?
    @Published public private(set) var connectionState: UsageConnectionState = .connecting
    @Published public private(set) var refreshState: UsageRefreshState = .idle
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var now: Date
    @Published public private(set) var popupIsOpen = false

    private let provider: any UsageProviding
    private let cache: any UsageCaching
    private let clock: any UsageClock
    private let schedulingEnabled: Bool
    private var refreshTask: Task<Void, Never>?
    private var scheduledRefreshTask: Task<Void, Never>?
    private var tickerTask: Task<Void, Never>?
    private var updatesTask: Task<Void, Never>?
    private var backoffIndex = 0
    private var restoredFromCache = false
    private var lastRefreshFailed = false
    private var attemptedReset: [QuotaKind: Date] = [:]
    private let retryDelays: [TimeInterval] = [60, 120, 300, 600, 900]

    public init(
        provider: any UsageProviding,
        cache: any UsageCaching = UserDefaultsUsageCache(),
        clock: any UsageClock = SystemUsageClock(),
        schedulingEnabled: Bool = true
    ) {
        self.provider = provider
        self.cache = cache
        self.clock = clock
        self.schedulingEnabled = schedulingEnabled
        self.now = clock.now()
    }

    public var isStale: Bool {
        guard let snapshot else { return false }
        return restoredFromCache || now.timeIntervalSince(snapshot.fetchedAt) > 10 * 60
    }

    public var statusTitle: String {
        switch connectionState {
        case .connecting: return "Connecting"
        case .connected: return "Connected"
        case .disconnected: return "Offline"
        case .codexUnavailable: return "Unavailable"
        case .failed: return "Update failed"
        }
    }

    public var lastUpdatedText: String {
        guard let snapshot else { return errorMessage ?? "Waiting for Codex" }
        let seconds = max(0, Int(now.timeIntervalSince(snapshot.fetchedAt)))
        if seconds < 10 { return "Updated just now" }
        if seconds < 60 { return "Updated \(seconds)s ago" }
        if seconds < 3_600 { return "Updated \(seconds / 60)m ago" }
        return "Updated \(seconds / 3_600)h ago"
    }

    public var menuBarText: String {
        guard snapshot != nil else { return "— | —" }
        return "\(displayValue(for: .hourly)) | \(displayValue(for: .weekly))"
    }

    public var menuBarTooltip: String {
        guard let snapshot else { return "Codex — usage unavailable" }
        return "Codex — Hourly \(snapshot.hourly.remainingPercent)%, Weekly \(snapshot.weekly.remainingPercent)% remaining"
    }

    public func quota(for kind: QuotaKind) -> QuotaWindow? {
        switch kind {
        case .hourly: return snapshot?.hourly
        case .weekly: return snapshot?.weekly
        }
    }

    public func displayValue(for kind: QuotaKind) -> String {
        guard let quota = quota(for: kind) else { return "—" }
        if quota.remainingPercent > 0 { return "\(quota.remainingPercent)%" }
        guard let resetsAt = quota.resetsAt else { return "—" }
        let interval = resetsAt.timeIntervalSince(now)
        if interval > 0 { return Self.formatCountdown(interval) }
        if refreshState == .refreshing { return "…" }
        return "—"
    }

    public func resetText(for kind: QuotaKind) -> String {
        guard let reset = quota(for: kind)?.resetsAt else { return "Reset unavailable" }
        let interval = reset.timeIntervalSince(now)
        if interval > 0 { return "Resets in \(Self.formatCountdown(interval))" }
        if refreshState == .refreshing { return "Checking reset…" }
        return "Reset check unavailable"
    }

    public func start() {
        guard tickerTask == nil else { return }
        now = clock.now()
        if let cached = cache.load() {
            snapshot = cached
            restoredFromCache = true
        }
        startTicker()
        updatesTask = Task { [weak self] in
            guard let self else { return }
            let stream = await self.provider.updates()
            for await update in stream {
                guard !Task.isCancelled else { return }
                self.accept(update, reason: .providerUpdate)
            }
        }
        triggerRefresh(.startup)
    }

    public func stop() async {
        refreshTask?.cancel()
        scheduledRefreshTask?.cancel()
        tickerTask?.cancel()
        updatesTask?.cancel()
        refreshTask = nil
        scheduledRefreshTask = nil
        tickerTask = nil
        updatesTask = nil
        await provider.shutdown()
    }

    public func setPopupOpen(_ isOpen: Bool) {
        guard popupIsOpen != isOpen else { return }
        popupIsOpen = isOpen
        if isOpen { triggerRefresh(.popupOpened) }
        scheduleNormalRefresh()
    }

    public func manualRefresh() { triggerRefresh(.manual) }
    public func handleWake() { triggerRefresh(.wake) }
    public func handleNetworkRestored() { triggerRefresh(.networkRestored) }

    public func triggerRefresh(_ reason: RefreshReason) {
        Task { [weak self] in await self?.refreshAndWait(reason) }
    }

    public func refreshAndWait(_ reason: RefreshReason) async {
        if let existing = refreshTask {
            await existing.value
            return
        }
        scheduledRefreshTask?.cancel()
        scheduledRefreshTask = nil
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performRefresh(reason)
        }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    public func tick() {
        now = clock.now()
        checkResetBoundary(.hourly)
        checkResetBoundary(.weekly)
    }

    public static func formatCountdown(_ interval: TimeInterval) -> String {
        let totalMinutes = max(1, Int(ceil(interval / 60)))
        let days = totalMinutes / 1_440
        let hours = (totalMinutes % 1_440) / 60
        let minutes = totalMinutes % 60
        if days > 0 { return hours > 0 ? "\(days)d \(hours)h" : "\(days)d" }
        if hours > 0 { return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h" }
        return "\(minutes)m"
    }

    private func performRefresh(_ reason: RefreshReason) async {
        refreshState = .refreshing
        errorMessage = nil
        if snapshot == nil { connectionState = .connecting }

        do {
            let fresh = try await provider.fetchSnapshot()
            accept(fresh, reason: reason)
        } catch {
            handleFailure(error, reason: reason)
        }
    }

    private func accept(_ fresh: UsageSnapshot, reason: RefreshReason) {
        snapshot = fresh
        now = clock.now()
        restoredFromCache = false
        lastRefreshFailed = false
        connectionState = .connected
        refreshState = .idle
        errorMessage = nil
        backoffIndex = 0
        attemptedReset = attemptedReset.filter { _, date in
            fresh.hourly.resetsAt == date || fresh.weekly.resetsAt == date
        }
        cache.save(fresh)
        scheduleNormalRefresh()
    }

    private func handleFailure(_ error: Error, reason: RefreshReason) {
        refreshState = .failed
        lastRefreshFailed = true
        let providerError = error as? UsageProviderError
        errorMessage = providerError?.errorDescription ?? error.localizedDescription
        switch providerError {
        case .executableNotFound: connectionState = .codexUnavailable
        case .notAuthenticated: connectionState = .disconnected
        default: connectionState = .failed
        }
        scheduleRetry()
    }

    private func scheduleNormalRefresh() {
        guard schedulingEnabled, !lastRefreshFailed else { return }
        scheduleRefresh(after: popupIsOpen ? 60 : 300, reason: popupIsOpen ? .foregroundTimer : .backgroundTimer)
    }

    private func scheduleRetry() {
        guard schedulingEnabled else { return }
        let index = min(backoffIndex, retryDelays.count - 1)
        let delay = retryDelays[index]
        backoffIndex = min(backoffIndex + 1, retryDelays.count - 1)
        scheduleRefresh(after: delay, reason: .retry)
    }

    private func scheduleRefresh(after delay: TimeInterval, reason: RefreshReason) {
        scheduledRefreshTask?.cancel()
        scheduledRefreshTask = Task { [weak self, clock] in
            do { try await clock.sleep(for: delay) } catch { return }
            guard !Task.isCancelled else { return }
            await self?.refreshAndWait(reason)
        }
    }

    private func startTicker() {
        guard schedulingEnabled else { return }
        tickerTask = Task { [weak self, clock] in
            while !Task.isCancelled {
                guard let self else { return }
                let interval = self.popupIsOpen ? 1.0 : 60.0
                do { try await clock.sleep(for: interval) } catch { return }
                guard !Task.isCancelled else { return }
                self.tick()
            }
        }
    }

    private func checkResetBoundary(_ kind: QuotaKind) {
        guard let quota = quota(for: kind), quota.remainingPercent == 0,
              let reset = quota.resetsAt, reset <= now else { return }
        guard attemptedReset[kind] != reset else { return }
        attemptedReset[kind] = reset
        triggerRefresh(.resetBoundary)
    }
}
