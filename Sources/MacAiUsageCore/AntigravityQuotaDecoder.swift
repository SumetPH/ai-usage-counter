import Foundation

public enum AntigravityQuotaDecoder {
    public static func decode(_ data: Data, now: Date = Date()) throws -> ProviderSnapshot {
        let response: Response
        do {
            response = try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw UsageProviderError.malformedResponse("invalid Antigravity quota response")
        }

        let modelQuotas = response.models.compactMap { id, model -> (family: Family, percent: Int, reset: Date?)? in
            guard let info = model.quotaInfo else { return nil }
            guard let family = Family(modelID: id, displayName: model.displayName) else { return nil }
            let reset = info.resetTime.flatMap { ISO8601DateFormatter().date(from: $0) }
            return (family, Int(((info.remainingFraction ?? 0) * 100).rounded()), reset)
        }

        let quotas = Family.allCases.compactMap { family -> UsageQuota? in
            let candidates = modelQuotas.filter { $0.family == family }
            guard let minimum = candidates.map(\.percent).min() else { return nil }
            let reset = candidates
                .filter { $0.percent == minimum }
                .compactMap(\.reset)
                .min()
            return UsageQuota(id: family.rawValue, name: family.displayName, remainingPercent: minimum, resetsAt: reset)
        }

        guard !quotas.isEmpty else { throw UsageProviderError.missingRateLimitWindows }
        return ProviderSnapshot(providerID: .antigravity, quotas: quotas, fetchedAt: now)
    }
}

private enum Family: String, CaseIterable {
    case gemini
    case claude

    var displayName: String { rawValue.capitalized }

    init?(modelID: String, displayName: String?) {
        let searchable = "\(modelID) \(displayName ?? "")".lowercased()
        if searchable.contains("claude") { self = .claude }
        else if searchable.contains("gemini") { self = .gemini }
        else { return nil }
    }
}

private struct Response: Decodable {
    let models: [String: Model]
}

private struct Model: Decodable {
    let displayName: String?
    let quotaInfo: QuotaInfo?
}

private struct QuotaInfo: Decodable {
    let remainingFraction: Double?
    let resetTime: String?
}
