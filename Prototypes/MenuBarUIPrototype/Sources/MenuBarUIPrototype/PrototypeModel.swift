import Foundation
import SwiftUI

// PROTOTYPE — fixture-only state for comparing popup information hierarchies.

enum PopupVariant: String, CaseIterable, Identifiable {
    case operational = "A — Operational bars"
    case gauges = "B — Dual gauges"
    case timeline = "C — Reset timeline"

    var id: String { rawValue }

    mutating func move(_ offset: Int) {
        let values = Self.allCases
        let index = values.firstIndex(of: self) ?? 0
        self = values[(index + offset + values.count) % values.count]
    }
}

enum FixtureState: String, CaseIterable, Identifiable {
    case normal = "Normal"
    case hourlyExhausted = "Hourly exhausted"
    case weeklyExhausted = "Weekly exhausted"
    case bothExhausted = "Both exhausted"
    case stale = "Stale"
    case disconnected = "Disconnected"
    case resetFailure = "Reset refresh failed"

    var id: String { rawValue }
}

struct QuotaViewData {
    let name: String
    let remaining: Int
    let resetInterval: TimeInterval?
    let resetExpired: Bool

    func displayValue(refreshFailed: Bool = false) -> String {
        if remaining > 0 { return "\(remaining)%" }
        if resetExpired { return refreshFailed ? "—" : "…" }
        guard let resetInterval else { return "—" }
        return Self.duration(resetInterval)
    }

    var resetText: String {
        guard let resetInterval else { return "Reset unavailable" }
        return resetExpired ? "Reset check pending" : "Resets in \(Self.duration(resetInterval))"
    }

    var tint: Color {
        if remaining <= 5 { return .red }
        if remaining <= 20 { return .orange }
        return .green
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = max(1, Int(ceil(seconds / 60)))
        let days = minutes / 1_440
        let hours = (minutes % 1_440) / 60
        let mins = minutes % 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(mins)m" }
        return "\(mins)m"
    }
}

struct UsageViewData {
    let hourly: QuotaViewData?
    let weekly: QuotaViewData?
    let stale: Bool
    let refreshFailed: Bool
    let updatedText: String

    var connected: Bool { hourly != nil && weekly != nil }
}

@MainActor
final class PrototypeStore: ObservableObject {
    @Published var variant: PopupVariant = .operational
    @Published var fixture: FixtureState = .normal
    @Published var launchAtLogin = false
    @Published var isRefreshing = false

    var data: UsageViewData {
        let hour = { (remaining: Int, interval: TimeInterval?, expired: Bool) in
            QuotaViewData(name: "Hourly", remaining: remaining, resetInterval: interval, resetExpired: expired)
        }
        let week = { (remaining: Int, interval: TimeInterval?, expired: Bool) in
            QuotaViewData(name: "Weekly", remaining: remaining, resetInterval: interval, resetExpired: expired)
        }

        switch fixture {
        case .normal:
            return UsageViewData(hourly: hour(64, 107 * 60, false), weekly: week(72, (5 * 24 + 19) * 3_600, false), stale: false, refreshFailed: false, updatedText: "Updated just now")
        case .hourlyExhausted:
            return UsageViewData(hourly: hour(0, 84 * 60, false), weekly: week(72, (5 * 24 + 19) * 3_600, false), stale: false, refreshFailed: false, updatedText: "Updated just now")
        case .weeklyExhausted:
            return UsageViewData(hourly: hour(64, 107 * 60, false), weekly: week(0, (2 * 24 + 5) * 3_600, false), stale: false, refreshFailed: false, updatedText: "Updated just now")
        case .bothExhausted:
            return UsageViewData(hourly: hour(0, 84 * 60, false), weekly: week(0, (2 * 24 + 5) * 3_600, false), stale: false, refreshFailed: false, updatedText: "Updated just now")
        case .stale:
            return UsageViewData(hourly: hour(41, 61 * 60, false), weekly: week(68, (4 * 24 + 7) * 3_600, false), stale: true, refreshFailed: true, updatedText: "Updated 11 min ago")
        case .disconnected:
            return UsageViewData(hourly: nil, weekly: nil, stale: false, refreshFailed: false, updatedText: "Sign in with Codex CLI, then retry")
        case .resetFailure:
            return UsageViewData(hourly: hour(0, -1, true), weekly: week(72, (5 * 24 + 19) * 3_600, false), stale: true, refreshFailed: true, updatedText: "Reset refresh failed")
        }
    }

    var menuBarText: String {
        guard let hourly = data.hourly, let weekly = data.weekly else { return "— | —" }
        return "\(hourly.displayValue(refreshFailed: data.refreshFailed)) | \(weekly.displayValue(refreshFailed: data.refreshFailed))"
    }

    func refresh() {
        isRefreshing = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(550))
            isRefreshing = false
        }
    }
}
