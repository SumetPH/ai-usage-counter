import Foundation

public enum UsageProviderID: String, Codable, CaseIterable, Identifiable, Sendable {
    case codex
    case antigravity

    public var id: String { rawValue }
    public var displayName: String { self == .codex ? "Codex" : "Antigravity" }
}

public struct UsageQuota: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let remainingPercent: Int
    public let resetsAt: Date?

    public init(id: String, name: String, remainingPercent: Int, resetsAt: Date?) {
        self.id = id
        self.name = name
        self.remainingPercent = min(100, max(0, remainingPercent))
        self.resetsAt = resetsAt
    }
}

public struct ProviderSnapshot: Codable, Equatable, Sendable {
    public let providerID: UsageProviderID
    public let quotas: [UsageQuota]
    public let fetchedAt: Date

    public init(providerID: UsageProviderID, quotas: [UsageQuota], fetchedAt: Date) {
        self.providerID = providerID
        self.quotas = quotas
        self.fetchedAt = fetchedAt
    }
}

public struct QuotaWindow: Codable, Equatable, Sendable {
    public let remainingPercent: Int
    public let resetsAt: Date?
    public let durationMinutes: Int?

    public init(remainingPercent: Int, resetsAt: Date?, durationMinutes: Int?) {
        self.remainingPercent = min(100, max(0, remainingPercent))
        self.resetsAt = resetsAt
        self.durationMinutes = durationMinutes
    }
}

public struct UsageSnapshot: Codable, Equatable, Sendable {
    public let hourly: QuotaWindow
    public let weekly: QuotaWindow
    public let fetchedAt: Date

    public init(hourly: QuotaWindow, weekly: QuotaWindow, fetchedAt: Date) {
        self.hourly = hourly
        self.weekly = weekly
        self.fetchedAt = fetchedAt
    }
}

public enum UsageConnectionState: Equatable, Sendable {
    case connecting
    case connected
    case disconnected
    case codexUnavailable
    case failed
}

public enum UsageRefreshState: Equatable, Sendable {
    case idle
    case refreshing
    case failed
}

public enum RefreshReason: String, Sendable {
    case startup
    case popupOpened
    case foregroundTimer
    case backgroundTimer
    case manual
    case wake
    case networkRestored
    case resetBoundary
    case providerUpdate
    case retry
}

public enum UsageProviderError: LocalizedError, Equatable, Sendable {
    case executableNotFound
    case notAuthenticated
    case launchFailed(String)
    case timedOut
    case server(String)
    case transportClosed
    case malformedResponse(String)
    case missingRateLimitWindows

    public var errorDescription: String? {
        switch self {
        case .executableNotFound:
            return "Codex CLI was not found. Install Codex or make it available in your PATH."
        case .notAuthenticated:
            return "Codex not connected. Sign in with Codex CLI, then retry."
        case .launchFailed(let message):
            return "Could not launch Codex: \(message)"
        case .timedOut:
            return "Codex did not respond in time."
        case .server(let message):
            return "Codex app-server error: \(message)"
        case .transportClosed:
            return "The Codex app-server connection closed."
        case .malformedResponse(let message):
            return "Codex returned an unsupported usage response: \(message)"
        case .missingRateLimitWindows:
            return "Codex did not return both Hourly and Weekly limits."
        }
    }
}

public protocol UsageProviding: Sendable {
    func fetchSnapshot() async throws -> UsageSnapshot
    func updates() async -> AsyncStream<UsageSnapshot>
    func shutdown() async
}
