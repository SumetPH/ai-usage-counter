import Foundation

enum ProbeError: LocalizedError {
    case launch(String)
    case timedOut
    case server(String)
    case malformedResponse
    case missingWindows

    var errorDescription: String? {
        switch self {
        case .launch(let message): return "Could not launch Codex app-server: \(message)"
    case .timedOut: return "Codex app-server did not answer within 30 seconds"
        case .server(let message): return "Codex app-server error: \(message)"
        case .malformedResponse: return "Codex returned an unexpected response shape"
        case .missingWindows: return "Codex returned no primary/secondary rate-limit windows"
        }
    }
}

/// Opt-in live adapter. It delegates authentication to `codex app-server` and never reads auth files.
enum CodexRateLimitProbe {
    static func fetch() throws -> UsageSnapshot {
        let process = Process()
        let input = Pipe()
        let output = Pipe()
        let errors = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["codex", "app-server", "--listen", "stdio://"]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errors

        do { try process.run() } catch { throw ProbeError.launch(error.localizedDescription) }
        defer {
            input.fileHandleForWriting.closeFile()
            if process.isRunning { process.terminate() }
        }

        let messages: [[String: Any]] = [
            [
                "method": "initialize",
                "id": 1,
                "params": [
                    "clientInfo": [
                        "name": "ai_usage_counter_prototype",
                        "title": "AI Usage Counter Prototype",
                        "version": "0.0.1"
                    ]
                ]
            ],
            ["method": "initialized", "params": [:]],
            ["method": "account/rateLimits/read", "id": 2, "params": NSNull()]
        ]

        for message in messages {
            let data = try JSONSerialization.data(withJSONObject: message)
            input.fileHandleForWriting.write(data)
            input.fileHandleForWriting.write(Data([0x0A]))
        }

        let collector = LineCollector(handle: output.fileHandleForReading)
        guard let response = collector.firstResponse(withID: 2, timeout: 30) else {
            throw ProbeError.timedOut
        }
        if let error = response["error"] as? [String: Any] {
            throw ProbeError.server(error["message"] as? String ?? "unknown error")
        }
        guard let result = response["result"] as? [String: Any] else {
            throw ProbeError.malformedResponse
        }
        return try normalize(result: result, now: Date())
    }

    private static func normalize(result: [String: Any], now: Date) throws -> UsageSnapshot {
        let bucket: [String: Any]?
        if let buckets = result["rateLimitsByLimitId"] as? [String: Any],
           let codex = buckets["codex"] as? [String: Any] {
            bucket = codex
        } else {
            bucket = result["rateLimits"] as? [String: Any]
        }

        guard let bucket else { throw ProbeError.malformedResponse }
        let windows = [bucket["primary"], bucket["secondary"]]
            .compactMap { $0 as? [String: Any] }
            .compactMap(parseWindow)
            .sorted { ($0.durationMinutes ?? .max) < ($1.durationMinutes ?? .max) }

        guard let hourly = windows.first, let weekly = windows.last, windows.count >= 2 else {
            throw ProbeError.missingWindows
        }

        return UsageSnapshot(hourly: hourly, weekly: weekly, fetchedAt: now, source: "codex app-server")
    }

    private static func parseWindow(_ object: [String: Any]) -> QuotaWindow? {
        guard let used = object["usedPercent"] as? Int else { return nil }
        let reset: Date?
        if let epoch = object["resetsAt"] as? Int {
            reset = Date(timeIntervalSince1970: TimeInterval(epoch))
        } else {
            reset = nil
        }
        return QuotaWindow(
            remainingPercent: 100 - used,
            resetsAt: reset,
            durationMinutes: object["windowDurationMins"] as? Int
        )
    }
}

private final class LineCollector {
    private let handle: FileHandle
    private let queue = DispatchQueue(label: "prototype.codex-output")
    private var buffer = Data()
    private var responses: [[String: Any]] = []

    init(handle: FileHandle) {
        self.handle = handle
        handle.readabilityHandler = { [weak self] readable in
            let data = readable.availableData
            guard !data.isEmpty else { return }
            self?.queue.async { self?.append(data) }
        }
    }

    deinit { handle.readabilityHandler = nil }

    func firstResponse(withID id: Int, timeout: TimeInterval) -> [String: Any]? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let match = queue.sync(execute: { responses.first(where: { $0["id"] as? Int == id }) }) {
                return match
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return nil
    }

    private func append(_ data: Data) {
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer[..<newline]
            buffer.removeSubrange(...newline)
            if let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any] {
                responses.append(object)
            }
        }
    }
}
