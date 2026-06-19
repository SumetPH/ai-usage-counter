import Foundation

public protocol UsageCaching: Sendable {
    func load() -> UsageSnapshot?
    func save(_ snapshot: UsageSnapshot)
    func clear()
}

public final class UserDefaultsUsageCache: UsageCaching, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard, key: String = "normalizedUsageSnapshot") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> UsageSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        guard let data = defaults.data(forKey: key) else { return nil }
        guard let snapshot = try? JSONDecoder().decode(UsageSnapshot.self, from: data) else {
            defaults.removeObject(forKey: key)
            return nil
        }
        return snapshot
    }

    public func save(_ snapshot: UsageSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        lock.lock()
        defer { lock.unlock() }
        defaults.set(data, forKey: key)
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        defaults.removeObject(forKey: key)
    }
}

public final class MemoryUsageCache: UsageCaching, @unchecked Sendable {
    private let lock = NSLock()
    private var snapshot: UsageSnapshot?

    public init(snapshot: UsageSnapshot? = nil) {
        self.snapshot = snapshot
    }

    public func load() -> UsageSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        return snapshot
    }

    public func save(_ snapshot: UsageSnapshot) {
        lock.lock()
        defer { lock.unlock() }
        self.snapshot = snapshot
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        snapshot = nil
    }
}
