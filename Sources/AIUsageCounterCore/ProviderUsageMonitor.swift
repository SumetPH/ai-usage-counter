import Combine
import Foundation

public protocol ProviderUsageProviding: Sendable {
    var providerID: UsageProviderID { get }
    func fetchSnapshot() async throws -> ProviderSnapshot
    func shutdown() async
}

public protocol ProviderUsageCaching: Sendable {
    func load() -> ProviderSnapshot?
    func save(_ snapshot: ProviderSnapshot)
    func clear()
}

public final class UserDefaultsProviderUsageCache: ProviderUsageCaching, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String
    private let lock = NSLock()

    public init(providerID: UsageProviderID, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.key = "providerUsageSnapshot.\(providerID.rawValue)"
    }

    public func load() -> ProviderSnapshot? {
        lock.withLock {
            guard let data = defaults.data(forKey: key) else { return nil }
            guard let value = try? JSONDecoder().decode(ProviderSnapshot.self, from: data) else {
                defaults.removeObject(forKey: key)
                return nil
            }
            return value
        }
    }

    public func save(_ snapshot: ProviderSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        lock.withLock { defaults.set(data, forKey: key) }
    }

    public func clear() { lock.withLock { defaults.removeObject(forKey: key) } }
}

public final class MemoryProviderUsageCache: ProviderUsageCaching, @unchecked Sendable {
    private let lock = NSLock()
    private var value: ProviderSnapshot?
    public init(snapshot: ProviderSnapshot? = nil) { value = snapshot }
    public func load() -> ProviderSnapshot? { lock.withLock { value } }
    public func save(_ snapshot: ProviderSnapshot) { lock.withLock { value = snapshot } }
    public func clear() { lock.withLock { value = nil } }
}

public actor CodexProviderAdapter: ProviderUsageProviding {
    public nonisolated let providerID: UsageProviderID = .codex
    private let provider: any UsageProviding

    public init(provider: any UsageProviding = CodexAppServerProvider()) { self.provider = provider }

    public func fetchSnapshot() async throws -> ProviderSnapshot {
        let value = try await provider.fetchSnapshot()
        return ProviderSnapshot(providerID: .codex, quotas: [
            UsageQuota(id: "hourly", name: "Hourly", remainingPercent: value.hourly.remainingPercent, resetsAt: value.hourly.resetsAt),
            UsageQuota(id: "weekly", name: "Weekly", remainingPercent: value.weekly.remainingPercent, resetsAt: value.weekly.resetsAt),
        ], fetchedAt: value.fetchedAt)
    }

    public func shutdown() async { await provider.shutdown() }
}

@MainActor
public final class ProviderUsageMonitor: ObservableObject, Identifiable {
    public nonisolated let id: UsageProviderID
    @Published public private(set) var snapshot: ProviderSnapshot?
    @Published public private(set) var connectionState: UsageConnectionState = .connecting
    @Published public private(set) var refreshState: UsageRefreshState = .idle
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var now: Date
    @Published public private(set) var isEnabled = false

    private let provider: any ProviderUsageProviding
    private let cache: any ProviderUsageCaching
    private let clock: any UsageClock
    private let schedulingEnabled: Bool
    private var refreshTask: Task<Void, Never>?
    private var scheduledTask: Task<Void, Never>?
    private var tickerTask: Task<Void, Never>?
    private var restoredFromCache = false
    private var popupIsOpen = false

    public init(provider: any ProviderUsageProviding, cache: any ProviderUsageCaching, clock: any UsageClock = SystemUsageClock(), schedulingEnabled: Bool = true) {
        self.id = provider.providerID
        self.provider = provider
        self.cache = cache
        self.clock = clock
        self.schedulingEnabled = schedulingEnabled
        self.now = clock.now()
    }

    public var isStale: Bool {
        guard let snapshot else { return false }
        return restoredFromCache || now.timeIntervalSince(snapshot.fetchedAt) > 600
    }

    public var statusTitle: String {
        switch connectionState {
        case .connecting: "Connecting"
        case .connected: "Connected"
        case .disconnected: "Sign in required"
        case .codexUnavailable: "Unavailable"
        case .failed: "Update failed"
        }
    }

    public var lastUpdatedText: String {
        guard let snapshot else { return errorMessage ?? "Waiting for \(id.displayName)" }
        let seconds = max(0, Int(now.timeIntervalSince(snapshot.fetchedAt)))
        if seconds < 10 { return "Updated just now" }
        if seconds < 60 { return "Updated \(seconds)s ago" }
        if seconds < 3_600 { return "Updated \(seconds / 60)m ago" }
        return "Updated \(seconds / 3_600)h ago"
    }

    public func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        if enabled {
            if let cached = cache.load() { snapshot = cached; restoredFromCache = true }
            startTicker()
            triggerRefresh(.startup)
        } else {
            refreshTask?.cancel(); refreshTask = nil
            scheduledTask?.cancel(); scheduledTask = nil
            tickerTask?.cancel(); tickerTask = nil
        }
    }

    public func setPopupOpen(_ open: Bool) {
        popupIsOpen = open
        guard isEnabled else { return }
        if open { triggerRefresh(.popupOpened) }
        scheduleNext()
    }

    public func triggerRefresh(_ reason: RefreshReason) {
        guard isEnabled || !schedulingEnabled else { return }
        Task { [weak self] in await self?.refreshAndWait(reason) }
    }

    public func refreshAndWait(_ reason: RefreshReason) async {
        if let refreshTask { await refreshTask.value; return }
        scheduledTask?.cancel(); scheduledTask = nil
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performRefresh()
        }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    public func quota(_ id: String) -> UsageQuota? { snapshot?.quotas.first { $0.id == id } }

    public func menuBarText(preferredQuotaID: String?) -> String {
        guard let quotas = snapshot?.quotas, !quotas.isEmpty else { return "—" }
        if id == .codex {
            let hourly = quotas.first { $0.id == "hourly" }?.remainingPercent
            let weekly = quotas.first { $0.id == "weekly" }?.remainingPercent
            return "\(hourly.map { "\($0)%" } ?? "—") | \(weekly.map { "\($0)%" } ?? "—")"
        }
        guard let selected = preferredQuotaID.flatMap({ quota($0) }) else { return "—" }
        return "\(selected.remainingPercent)%"
    }

    public func resetText(for quota: UsageQuota) -> String {
        guard let reset = quota.resetsAt else { return "Reset unavailable" }
        return reset > now ? "Resets in \(UsageMonitor.formatCountdown(reset.timeIntervalSince(now)))" : "Reset check unavailable"
    }

    public func tick() { now = clock.now() }

    public func shutdown() async {
        refreshTask?.cancel()
        scheduledTask?.cancel()
        tickerTask?.cancel()
        await provider.shutdown()
    }

    private func performRefresh() async {
        refreshState = .refreshing
        errorMessage = nil
        do {
            let value = try await provider.fetchSnapshot()
            snapshot = value
            now = clock.now()
            restoredFromCache = false
            connectionState = .connected
            refreshState = .idle
            cache.save(value)
            scheduleNext()
        } catch {
            refreshState = .failed
            errorMessage = (error as? UsageProviderError)?.errorDescription ?? error.localizedDescription
            switch error as? UsageProviderError {
            case .notAuthenticated: connectionState = .disconnected
            case .executableNotFound: connectionState = .codexUnavailable
            default: connectionState = .failed
            }
            schedule(after: 60)
        }
    }

    private func scheduleNext() { schedule(after: popupIsOpen ? 60 : 300) }

    private func schedule(after seconds: TimeInterval) {
        guard schedulingEnabled, isEnabled else { return }
        scheduledTask?.cancel()
        scheduledTask = Task { [weak self, clock] in
            do { try await clock.sleep(for: seconds) } catch { return }
            guard !Task.isCancelled else { return }
            await self?.refreshAndWait(.backgroundTimer)
        }
    }

    private func startTicker() {
        guard schedulingEnabled, tickerTask == nil else { return }
        tickerTask = Task { [weak self, clock] in
            while !Task.isCancelled {
                guard let self else { return }
                do { try await clock.sleep(for: self.popupIsOpen ? 1 : 60) } catch { return }
                guard !Task.isCancelled else { return }
                self.tick()
            }
        }
    }
}
