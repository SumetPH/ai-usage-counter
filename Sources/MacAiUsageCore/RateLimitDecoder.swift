import Foundation

public enum RateLimitDecoder {
    public static func decodeResponse(_ data: Data, now: Date = Date()) throws -> UsageSnapshot {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw UsageProviderError.malformedResponse("invalid JSON")
        }

        guard let envelope = object as? [String: Any] else {
            throw UsageProviderError.malformedResponse("response is not an object")
        }
        if let error = envelope["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "unknown error"
            if message.localizedCaseInsensitiveContains("login") ||
                message.localizedCaseInsensitiveContains("auth") ||
                message.localizedCaseInsensitiveContains("unauthorized") {
                throw UsageProviderError.notAuthenticated
            }
            throw UsageProviderError.server(message)
        }
        guard let result = envelope["result"] as? [String: Any] else {
            throw UsageProviderError.malformedResponse("missing result")
        }
        return try decodeResult(result, now: now)
    }

    public static func decodeResult(_ result: [String: Any], now: Date = Date()) throws -> UsageSnapshot {
        let bucket: [String: Any]?
        if let buckets = result["rateLimitsByLimitId"] as? [String: Any],
           let codex = buckets["codex"] as? [String: Any] {
            bucket = codex
        } else {
            bucket = result["rateLimits"] as? [String: Any]
        }

        guard let bucket else {
            throw UsageProviderError.malformedResponse("missing Codex rate-limit bucket")
        }

        let windows = [bucket["primary"], bucket["secondary"]]
            .compactMap { $0 as? [String: Any] }
            .compactMap(parseWindow)
            .sorted { lhs, rhs in
                (lhs.durationMinutes ?? Int.max) < (rhs.durationMinutes ?? Int.max)
            }

        guard windows.count >= 2, let hourly = windows.first, let weekly = windows.last else {
            throw UsageProviderError.missingRateLimitWindows
        }
        guard hourly.durationMinutes != weekly.durationMinutes else {
            throw UsageProviderError.malformedResponse("rate-limit durations are ambiguous")
        }

        return UsageSnapshot(hourly: hourly, weekly: weekly, fetchedAt: now)
    }

    public static func decodeUpdate(_ data: Data, now: Date = Date()) throws -> UsageSnapshot {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let envelope = object as? [String: Any],
              let params = envelope["params"] as? [String: Any],
              let snapshot = params["rateLimits"] as? [String: Any] else {
            throw UsageProviderError.malformedResponse("invalid rolling update")
        }
        return try decodeResult(["rateLimits": snapshot], now: now)
    }

    private static func parseWindow(_ object: [String: Any]) -> QuotaWindow? {
        guard let used = integer(object["usedPercent"]) else { return nil }
        let reset = integer(object["resetsAt"]).map { Date(timeIntervalSince1970: TimeInterval($0)) }
        let duration = integer(object["windowDurationMins"])
        return QuotaWindow(
            remainingPercent: 100 - min(100, max(0, used)),
            resetsAt: reset,
            durationMinutes: duration
        )
    }

    private static func integer(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else {
            return nil
        }
        return number.intValue
    }
}
